// Economy context: database, clock and shared helpers. Every economy function takes it as `eco`.
import { randomBytes } from 'node:crypto';
import { openDatabase, transaction } from '../db/database.js';
import { createClock } from './clock.js';
import { createAccount, transfer } from './ledger.js';
import { initPolicy } from './policy.js';
import {
  GENESIS_FUNDS, STATE_JOBS, GENESIS_PROPERTIES, COMMODITIES, BASE_FX_KGD_PER_EUR, PARTNER_KEYS,
  IMPORT_TRANSPORT_RATE, KGD,
} from './constants.js';

export function createEconomy({ dbPath = ':memory:', timeZone = 'Europe/Berlin', now, seed, logger = console } = {}) {
  const db = openDatabase(dbPath);
  const clock = createClock({ timeZone, now });
  const eco = {
    db,
    clock,
    log: logger,
    cache: { system: {} },
    tx: (fn) => transaction(db, fn),
    currentDay: () => clock.today(),
    meta(key) {
      const row = db.prepare('SELECT value FROM meta WHERE key = ?').get(key);
      return row ? row.value : null;
    },
    setMeta(key, value) {
      db.prepare('INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value').run(key, String(value));
    },
    get seed() { return eco.meta('world_seed'); },
    close() { db.close(); },
  };
  const genesisDate = eco.meta('genesis_date');
  if (genesisDate) {
    clock.setGenesis(genesisDate);
  } else {
    runGenesis(eco, seed ?? randomBytes(8).toString('hex'));
  }
  return eco;
}

// Creates the initial state of the economy on the very first start.
function runGenesis(eco, seed) {
  eco.tx(() => {
    const date = eco.clock.todayDate();
    eco.clock.setGenesis(date);
    eco.setMeta('genesis_date', date);
    eco.setMeta('world_seed', seed);
    eco.setMeta('time_zone', eco.clock.timeZone);

    createAccount(eco, { kind: 'central_bank', ownerType: 'state', systemKey: 'central_bank', name: 'Central Bank of Kagundi', creditLimit: null, inMoneySupply: false });
    createAccount(eco, { kind: 'rest_of_world', ownerType: 'external', systemKey: 'rest_of_world', name: 'Foreign trade partners', creditLimit: null, inMoneySupply: false });
    const treasury = createAccount(eco, { kind: 'treasury', ownerType: 'state', systemKey: 'treasury', name: 'National Treasury', inMoneySupply: true });
    const avk = createAccount(eco, { kind: 'avk', ownerType: 'state', systemKey: 'avk', name: 'AVK - Allgemeine Volksversicherung Kagundi', inMoneySupply: true });
    const cb = eco.db.prepare("SELECT id FROM accounts WHERE system_key = 'central_bank'").get().id;
    transfer(eco, { from: cb, to: treasury, amount: GENESIS_FUNDS.treasury, category: 'genesis_issuance', memo: 'Initial treasury funds at launch', key: 'genesis:treasury', day: 1 });
    transfer(eco, { from: cb, to: avk, amount: GENESIS_FUNDS.avk, category: 'genesis_issuance', memo: 'Initial AVK capital at launch', key: 'genesis:avk', day: 1 });

    initPolicy(eco);

    const job = eco.db.prepare(`INSERT INTO jobs (employer_type, department, budget, title, daily_wage, slots, status, created_by, created_day)
      VALUES ('state', ?, ?, ?, ?, NULL, 'open', 'genesis', 1)`);
    for (const j of STATE_JOBS) job.run(j.department, j.budget, j.title, j.wage);

    const prop = eco.db.prepare(`INSERT INTO properties (name, city, type, value, daily_rent, owner_type, owner_id, for_sale, sale_price, for_rent, created_by, created_day)
      VALUES (?, ?, ?, ?, ?, 'state', NULL, ?, ?, 1, 'genesis', 1)`);
    for (const p of GENESIS_PROPERTIES) prop.run(p.name, p.city, p.type, KGD(p.value), KGD(p.rent), p.forSale ? 1 : 0, p.forSale ? KGD(p.value) : null);
    eco.setMeta('base_average_rent', eco.db.prepare('SELECT AVG(daily_rent) AS a FROM properties').get().a);

    const price = eco.db.prepare('INSERT INTO market_prices (day, commodity, world_eur, price_kgd, landed_kgd) VALUES (1, ?, ?, ?, ?)');
    for (const c of Object.values(COMMODITIES)) {
      const kgd = Math.round(c.baseEur * BASE_FX_KGD_PER_EUR * 100);
      price.run(c.key, c.baseEur, kgd, Math.round(kgd * (1 + IMPORT_TRANSPORT_RATE)));
    }
    const demand = Object.fromEntries(PARTNER_KEYS.map((k) => [k, 1]));
    eco.db.prepare('INSERT INTO market_state (day, fx, partner_demand, cpi, rent_index) VALUES (1, ?, ?, 100, 1)').run(BASE_FX_KGD_PER_EUR, JSON.stringify(demand));
  });
}
