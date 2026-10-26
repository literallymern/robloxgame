// Shared test helpers: an in-memory economy with a controllable clock.
import { createEconomy } from '../src/economy/index.js';
import { ensureCitizen, personalAccountId } from '../src/economy/citizens.js';
import { getAccount } from '../src/economy/ledger.js';

export function testEconomy({ start = '2026-11-01T10:00:00Z', seed = 'test-seed' } = {}) {
  let now = new Date(start);
  const eco = createEconomy({ now: () => now, seed, logger: { info() {}, warn() {}, error() {} } });
  return {
    eco,
    advanceDays(n = 1) { now = new Date(now.getTime() + n * 86_400_000); },
    setNow(iso) { now = new Date(iso); },
    citizen(id, { grant = true } = {}) { return ensureCitizen(eco, { userId: id, displayName: id, grantEligible: grant }); },
    bank(id) { return getAccount(eco, personalAccountId(eco, id, 'bank')).balance; },
    cash(id) { return getAccount(eco, personalAccountId(eco, id, 'cash')).balance; },
  };
}
