import { test } from 'node:test';
import assert from 'node:assert/strict';
import { testEconomy } from './helpers.js';
import { runTick, catchUp, lastCompletedDay, unpublishedReports, getReport } from '../src/economy/tick.js';
import { verifyLedger, ledgerSum } from '../src/economy/ledger.js';
import { clockIn } from '../src/economy/employment.js';
import { createClock } from '../src/economy/clock.js';
import { STATE_JOBS, POLICY_DEFAULTS } from '../src/economy/constants.js';
import { applyBp } from '../src/economy/money.js';

const policeWage = STATE_JOBS.find((j) => j.department === 'city_police').wage;

test('economic day changes exactly at 00:00 Europe/Berlin, also across daylight saving time', () => {
  let now = new Date('2026-11-01T10:00:00Z');
  const clock = createClock({ timeZone: 'Europe/Berlin', now: () => now });
  clock.setGenesis(clock.todayDate());
  assert.equal(clock.today(), 1);
  now = new Date('2026-11-01T22:59:59Z'); // 23:59:59 CET
  assert.equal(clock.today(), 1);
  now = new Date('2026-11-01T23:00:00Z'); // 00:00 CET
  assert.equal(clock.today(), 2);
  now = new Date('2027-03-28T21:59:59Z'); // 23:59:59 CEST (summer time started that night)
  const before = clock.today();
  now = new Date('2027-03-28T22:00:00Z'); // 00:00 CEST
  assert.equal(clock.today(), before + 1);
});

test('a day cannot be processed before it ends, and only once', () => {
  const t = testEconomy();
  assert.throws(() => runTick(t.eco, 1), /has not ended/);
  t.advanceDays(1);
  const r1 = runTick(t.eco, 1);
  assert.equal(r1.day, 1);
  const r2 = runTick(t.eco, 1);
  assert.equal(r2.skipped, true);
  assert.equal(lastCompletedDay(t.eco), 1);
  assert.throws(() => runTick(t.eco, 3), /cannot run before/);
});

test('wages are paid exactly once even if the tick runs repeatedly', () => {
  const t = testEconomy();
  t.citizen('cop');
  clockIn(t.eco, { userId: 'cop', roleKeys: ['city_police'] });
  assert.throws(() => clockIn(t.eco, { userId: 'cop', roleKeys: ['city_police'] }), /already registered/);
  t.advanceDays(1);
  catchUp(t.eco);
  catchUp(t.eco);
  runTick(t.eco, 1);
  const net = policeWage - applyBp(policeWage, POLICY_DEFAULTS.income_tax_bp);
  assert.equal(t.bank('cop'), POLICY_DEFAULTS.starting_grant + net);
  assert.ok(verifyLedger(t.eco).ok);
});

test('catch-up after downtime processes every missed day in order, marks them late and publishes only the newest report', () => {
  const t = testEconomy();
  t.advanceDays(4); // bot was offline for days 1-3, today is day 5
  const processed = catchUp(t.eco);
  assert.deepEqual(processed, [1, 2, 3, 4]);
  const late = t.eco.db.prepare('SELECT day, late FROM econ_days ORDER BY day').all().map((r) => [r.day, r.late]);
  assert.deepEqual(late, [[1, 1], [2, 1], [3, 1], [4, 0]]);
  assert.deepEqual(unpublishedReports(t.eco).map((r) => r.day), [4]);
  assert.ok(getReport(t.eco, 2), 'older reports are kept for /economy history');
});

test('a failing day is rolled back completely and succeeds on retry', () => {
  const t = testEconomy();
  t.citizen('cop');
  clockIn(t.eco, { userId: 'cop', roleKeys: ['city_police'] });
  t.advanceDays(1);
  const balanceBefore = t.bank('cop');
  const txBefore = t.eco.db.prepare('SELECT COUNT(*) AS n FROM transactions').get().n;
  // Simulate a crash late in the day's processing (after wages were booked).
  t.eco.db.exec('ALTER TABLE daily_snapshots RENAME TO daily_snapshots_broken');
  assert.throws(() => runTick(t.eco, 1));
  assert.equal(t.bank('cop'), balanceBefore, 'no wage was paid');
  assert.equal(t.eco.db.prepare('SELECT COUNT(*) AS n FROM transactions').get().n, txBefore, 'no transaction was kept');
  assert.equal(lastCompletedDay(t.eco), 0);
  t.eco.db.exec('ALTER TABLE daily_snapshots_broken RENAME TO daily_snapshots');
  runTick(t.eco, 1);
  assert.ok(t.bank('cop') > balanceBefore);
  assert.equal(ledgerSum(t.eco), 0);
});

test('reports are built from recorded data', () => {
  const t = testEconomy();
  t.citizen('cop');
  clockIn(t.eco, { userId: 'cop', roleKeys: ['city_police'] });
  t.advanceDays(1);
  const r = runTick(t.eco, 1);
  const wageCategory = Object.entries(r.snapshot.treasury?.expenditure ?? {}).find(([k]) => k.startsWith('public_wage'));
  assert.ok(r.report.sections.national.length > 0);
  assert.ok(r.report.developments.length > 0);
  assert.ok(wageCategory, 'public wage spending appears in the snapshot');
  assert.equal(wageCategory[1], policeWage);
});
