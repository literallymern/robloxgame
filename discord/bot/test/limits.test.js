// Rules the Roblox integration relies on: they must hold no matter where a request comes from.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { testEconomy } from './helpers.js';
import { clockIn } from '../src/economy/employment.js';
import { registerBusiness } from '../src/economy/businesses.js';
import { UserError } from '../src/economy/errors.js';

test('only one paid shift per economic day (also enforced by the database)', () => {
  const t = testEconomy();
  t.citizen('worker');
  const first = clockIn(t.eco, { userId: 'worker', roleKeys: ['city_police'] });
  assert.ok(first.job);
  assert.throws(() => clockIn(t.eco, { userId: 'worker', roleKeys: ['city_police'] }), (err) => err instanceof UserError && /one paid shift per economic day/.test(err.message));
  const shift = t.eco.db.prepare('SELECT * FROM shifts WHERE user_id = ?').get('worker');
  assert.throws(() => t.eco.db.prepare(`INSERT INTO shifts (econ_day, user_id, job_id, business_id, gross, status, created_at) VALUES (?, ?, ?, NULL, ?, 'pending', ?)`)
    .run(shift.econ_day, 'worker', shift.job_id, shift.gross, t.eco.clock.isoNow()), /UNIQUE/);
  assert.equal(t.eco.db.prepare('SELECT COUNT(*) AS n FROM shifts WHERE user_id = ?').get('worker').n, 1);
  t.advanceDays(1);
  assert.ok(clockIn(t.eco, { userId: 'worker', roleKeys: ['city_police'] }).job, 'a new economic day allows a new shift');
});

test('a citizen can own at most two businesses (pending ones count)', () => {
  const t = testEconomy();
  t.citizen('owner');
  registerBusiness(t.eco, { ownerId: 'owner', name: 'Gundi Timber', industry: 'timber' });
  registerBusiness(t.eco, { ownerId: 'owner', name: 'Stokondo Timber', industry: 'timber' });
  assert.throws(() => registerBusiness(t.eco, { ownerId: 'owner', name: 'Third Timber', industry: 'timber' }), (err) => err instanceof UserError && /at most 2 businesses/.test(err.message));
  assert.equal(t.eco.db.prepare('SELECT COUNT(*) AS n FROM businesses WHERE owner_id = ?').get('owner').n, 2);
});
