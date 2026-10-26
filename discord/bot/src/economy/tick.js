// The daily economic tick. Each economic day is processed exactly once, in order, inside a single
// database transaction: either every effect of the day is saved together with the "completed"
// marker, or nothing is saved and the previous consistent state remains.
import { createRng } from './rng.js';
import { effectsForDay, rollRandomEvents } from './events.js';
import { expireInvoices } from './invoices.js';
import { processFines } from './fines.js';
import { processProduction, processLicenseFees } from './businesses.js';
import { processPayroll } from './employment.js';
import { processRent, processPropertyTax } from './property.js';
import { processPremiums } from './insurance.js';
import { processCredit, updateAllCreditScores } from './credit.js';
import { computeNextMarket } from './market.js';
import { computeSnapshot, marketInputs, getSnapshot } from './indicators.js';
import { buildReport } from './report.js';
import { verifyLedger } from './ledger.js';

export function lastCompletedDay(eco) {
  return Number(eco.db.prepare('SELECT COALESCE(MAX(day), 0) AS d FROM econ_days').get().d);
}

export function isDayCompleted(eco, day) {
  return !!eco.db.prepare('SELECT 1 FROM econ_days WHERE day = ?').get(day);
}

// Processes one economic day. `late` = the day is being processed after a delay (bot downtime);
// late days still collect obligations but skip penalties such as late fees and credit damage.
export function runTick(eco, day, { late = false } = {}) {
  const started = Date.now();
  return eco.tx(() => {
    if (isDayCompleted(eco, day)) return { day, skipped: true };
    const last = lastCompletedDay(eco);
    if (day !== last + 1) throw new Error(`Economic day ${day} cannot run before day ${last + 1}.`);
    if (day >= eco.currentDay()) throw new Error(`Economic day ${day} has not ended yet.`);

    const effects = effectsForDay(eco, day);
    const result = { day, late };

    // 1. Pending transactions and obligations
    result.invoicesExpired = expireInvoices(eco, day);
    result.fines = processFines(eco, day, { late });
    // 2. Production and operating costs (sales, imports and exports happen live during the day)
    result.production = processProduction(eco, day, effects);
    result.license = processLicenseFees(eco, day, { late });
    // 3. Wages, rent, taxes, insurance premiums, loan payments
    result.payroll = processPayroll(eco, day);
    result.rent = processRent(eco, day, { late });
    result.propertyTax = processPropertyTax(eco, day);
    result.premiums = processPremiums(eco, day, { late });
    result.credit = processCredit(eco, day, { late });
    // 4. Prices for the next day: commodities, exchange rate, consumer prices
    result.market = computeNextMarket(eco, day, createRng(eco.seed, 'market', day), marketInputs(eco, day));
    // 5-6. Public finances and indicators; credit scores
    updateAllCreditScores(eco, day);
    // 7. Random economic events (start on the next day)
    result.newEvents = rollRandomEvents(eco, day, createRng(eco.seed, 'events', day));
    // 8. Snapshot and report
    const snapshot = computeSnapshot(eco, day, result);
    eco.db.prepare('INSERT INTO daily_snapshots (day, data) VALUES (?, ?)').run(day, JSON.stringify(snapshot));
    const history = [];
    for (let d = day - 1; d >= Math.max(1, day - 6); d--) {
      const s = getSnapshot(eco, d);
      if (s) history.push(s);
    }
    const report = buildReport(snapshot, history);
    eco.db.prepare('INSERT INTO reports (day, generated_at, content) VALUES (?, ?, ?)').run(day, eco.clock.isoNow(), JSON.stringify(report));

    // Integrity check: if the books do not balance, the whole day is rolled back.
    const check = verifyLedger(eco);
    if (!check.ok) throw new Error(`Ledger integrity check failed on day ${day}: sum ${check.sum}, ${check.mismatches.length} mismatched account(s).`);

    // 9. Mark the day as completed (same transaction).
    eco.db.prepare('INSERT INTO econ_days (day, calendar_date, status, completed_at, late, duration_ms) VALUES (?, ?, ?, ?, ?, ?)')
      .run(day, eco.clock.dateOfDay(day), 'completed', eco.clock.isoNow(), late ? 1 : 0, Date.now() - started);
    return { ...result, snapshot, report };
  });
}

// Processes every economic day that has ended but not been processed yet, oldest first.
// Catch-up policy: if more than one day is processed in one run (after downtime), only the newest
// report is published automatically; the others are kept and can be read with /economy history.
export function catchUp(eco, { maxDays = 60, publishAll = false } = {}) {
  const today = eco.currentDay();
  const processed = [];
  let day = lastCompletedDay(eco) + 1;
  while (day < today && processed.length < maxDays) {
    const late = day < today - 1;
    const r = runTick(eco, day, { late });
    if (!r.skipped) processed.push(day);
    day += 1;
  }
  if (processed.length > 1 && !publishAll) {
    const older = processed.slice(0, -1);
    eco.db.prepare(`UPDATE reports SET suppressed = 1 WHERE day IN (${older.map(() => '?').join(',')}) AND published_at IS NULL`).run(...older);
  }
  return processed;
}

export function recordTickFailure(eco, day, error) {
  eco.db.prepare('INSERT INTO tick_failures (day, failed_at, error) VALUES (?, ?, ?)').run(day, eco.clock.isoNow(), String(error?.stack ?? error).slice(0, 4000));
}

export function unpublishedReports(eco) {
  return eco.db.prepare('SELECT * FROM reports WHERE published_at IS NULL AND suppressed = 0 ORDER BY day').all();
}

export function markReportPublished(eco, day, { channelId, messageId }) {
  eco.db.prepare('UPDATE reports SET published_at = ?, channel_id = ?, message_id = ?, publish_attempts = publish_attempts + 1, last_error = NULL WHERE day = ?')
    .run(eco.clock.isoNow(), channelId, messageId, day);
}

export function markReportFailed(eco, day, error) {
  eco.db.prepare('UPDATE reports SET publish_attempts = publish_attempts + 1, last_error = ? WHERE day = ?').run(String(error).slice(0, 1000), day);
}

export function getReport(eco, day) {
  const row = eco.db.prepare('SELECT * FROM reports WHERE day = ?').get(day);
  return row ? { ...row, content: JSON.parse(row.content) } : null;
}

export function latestReport(eco) {
  const row = eco.db.prepare('SELECT * FROM reports ORDER BY day DESC LIMIT 1').get();
  return row ? { ...row, content: JSON.parse(row.content) } : null;
}
