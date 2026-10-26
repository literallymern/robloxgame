// Economic indicators calculated from the database at the end of an economic day.
// Every figure here is derived from recorded data. Estimates are labelled as such in the report.
import { COMMODITIES, COMMODITY_KEYS, PARTNER_KEYS } from './constants.js';
import { systemAccountId, getAccount } from './ledger.js';
import { pricesForDay, marketStateFor } from './market.js';
import { treasuryFlows } from './treasury.js';
import { creditSummary } from './credit.js';
import { getPolicy, policyChangesOnDay } from './policy.js';
import { eventsActiveOn } from './events.js';

export function moneyStock(eco) {
  const row = eco.db.prepare(`SELECT
      COALESCE(SUM(balance), 0) AS total,
      COALESCE(SUM(CASE WHEN kind IN ('personal_bank','personal_cash','business') THEN balance END), 0) AS private,
      COALESCE(SUM(CASE WHEN kind IN ('treasury','avk') THEN balance END), 0) AS public
    FROM accounts WHERE in_money_supply = 1`).get();
  return { total: Number(row.total), private: Number(row.private), public: Number(row.public) };
}

export function getSnapshot(eco, day) {
  const row = eco.db.prepare('SELECT data FROM daily_snapshots WHERE day = ?').get(day);
  return row ? JSON.parse(row.data) : null;
}

const sumWhere = (eco, sql, ...args) => Number(eco.db.prepare(`SELECT COALESCE(SUM(amount), 0) AS s FROM transactions WHERE ${sql}`).get(...args).s);

// Inputs for the exchange-rate model: average daily money growth and net exports over the last week.
export function marketInputs(eco, day) {
  const stock = moneyStock(eco).total;
  const back = Math.max(1, day - 7);
  const past = getSnapshot(eco, back)?.money?.stock ?? null;
  const k = day - back;
  const moneyGrowthDaily = past && past > 0 && k > 0 ? (stock / past) ** (1 / k) - 1 : 0;
  const exports = sumWhere(eco, "category = 'export_sale' AND econ_day > ? AND econ_day <= ?", day - 7, day);
  const imports = sumWhere(eco, "category = 'import_purchase' AND econ_day > ? AND econ_day <= ?", day - 7, day);
  const netExportsShareDaily = stock > 0 ? (exports - imports) / stock / 7 : 0;
  const exportVolumes = {};
  for (const r of eco.db.prepare("SELECT commodity, SUM(quantity) AS q FROM transactions WHERE category = 'export_sale' AND econ_day = ? GROUP BY commodity").all(day)) {
    exportVolumes[r.commodity] = Number(r.q);
  }
  return { moneyGrowthDaily, netExportsShareDaily, exportVolumes };
}

export function computeSnapshot(eco, day, tick) {
  const prev = getSnapshot(eco, day - 1);
  const date = eco.clock.dateOfDay(day);

  // Money
  const stock = moneyStock(eco);
  const created = sumWhere(eco, "econ_day = ? AND flow = 'creation' AND category <> 'genesis_issuance'", day);
  const removed = sumWhere(eco, "econ_day = ? AND flow = 'removal'", day);
  const genesis = sumWhere(eco, "econ_day = ? AND category = 'genesis_issuance'", day);

  // Prices: today's prices and the prices computed for the next day.
  const today = pricesForDay(eco, day);
  const next = pricesForDay(eco, day + 1);
  const stateToday = marketStateFor(eco, day);
  const stateNext = marketStateFor(eco, day + 1);
  const cpi30Base = marketStateFor(eco, Math.max(1, day + 1 - 30));
  const inflationBasis = day + 1 - 30 >= 1 ? '30-day' : 'since launch';

  // Production and trade
  const production = Object.fromEntries(eco.db.prepare('SELECT commodity, SUM(quantity) AS q FROM production_log WHERE econ_day = ? GROUP BY commodity').all(day).map((r) => [r.commodity, Number(r.q)]));
  const tradeRows = eco.db.prepare(`SELECT category, commodity, partner, SUM(quantity) AS q, SUM(amount) AS v FROM transactions
    WHERE econ_day = ? AND category IN ('export_sale','import_purchase') GROUP BY category, commodity, partner`).all(day);
  const commodities = COMMODITY_KEYS.map((key) => {
    const c = COMMODITIES[key];
    const rows = tradeRows.filter((r) => r.commodity === key);
    const ex = rows.filter((r) => r.category === 'export_sale');
    const im = rows.filter((r) => r.category === 'import_purchase');
    return {
      key, name: c.name, unit: c.unit, tradable: c.tradable,
      price: next[key].price_kgd, landed: next[key].landed_kgd, prevPrice: today[key].price_kgd,
      changePct: today[key].price_kgd ? next[key].price_kgd / today[key].price_kgd - 1 : 0,
      production: production[key] ?? 0,
      exportsQty: ex.reduce((s, r) => s + Number(r.q), 0), exportValue: ex.reduce((s, r) => s + Number(r.v), 0),
      importsQty: im.reduce((s, r) => s + Number(r.q), 0), importValue: im.reduce((s, r) => s + Number(r.v), 0),
    };
  });
  const byPartner = {};
  for (const p of PARTNER_KEYS) {
    byPartner[p] = {
      exports: tradeRows.filter((r) => r.partner === p && r.category === 'export_sale').reduce((s, r) => s + Number(r.v), 0),
      imports: tradeRows.filter((r) => r.partner === p && r.category === 'import_purchase').reduce((s, r) => s + Number(r.v), 0),
      demandIndex: stateNext.partnerDemand[p] ?? 1,
    };
  }
  const exportsTotal = commodities.reduce((s, c) => s + c.exportValue, 0);
  const importsTotal = commodities.reduce((s, c) => s + c.importValue, 0);

  // GDP estimate (simplified output approach from recorded activity)
  const productionValue = commodities.reduce((s, c) => s + c.production * today[c.key].price_kgd, 0);
  const salesToHouseholdsAndState = Number(eco.db.prepare(`SELECT COALESCE(SUM(t.amount), 0) AS s FROM transactions t
    JOIN accounts f ON f.id = t.from_account JOIN accounts d ON d.id = t.to_account
    WHERE t.econ_day = ? AND d.kind = 'business' AND f.kind IN ('personal_bank','personal_cash','credit_card','treasury','avk')
      AND t.category NOT IN ('business_capital','loan_disbursement','admin_correction','insurance_payout')`).get(day).s);
  const publicWages = sumWhere(eco, "econ_day = ? AND category LIKE 'public_wage:%'", day);
  const housing = sumWhere(eco, "econ_day = ? AND category IN ('state_rent','rent_income')", day);
  const gdp = productionValue + salesToHouseholdsAndState + publicWages + housing;
  const gdpHistory = [gdp];
  for (let d = day - 1; d > day - 7 && d >= 1; d--) {
    const s = getSnapshot(eco, d);
    if (s) gdpHistory.push(s.gdp.estimate);
  }

  // Labour
  const activeCitizens = Number(eco.db.prepare('SELECT COUNT(*) AS n FROM citizens WHERE last_active_day > ?').get(day - 7).n);
  const employedActive = Number(eco.db.prepare(`SELECT COUNT(*) AS n FROM citizens c WHERE c.last_active_day > ? AND (
      EXISTS (SELECT 1 FROM shifts s WHERE s.user_id = c.user_id AND s.econ_day > ?)
      OR EXISTS (SELECT 1 FROM employments e WHERE e.user_id = c.user_id AND e.status = 'active'))`).get(day - 7, day - 7).n);
  const shiftRows = eco.db.prepare("SELECT COUNT(*) AS n, AVG(gross) AS avg, SUM(CASE WHEN business_id IS NULL THEN 1 ELSE 0 END) AS pub FROM shifts WHERE econ_day = ? AND status <> 'void'").get(day);
  const prevAvgWage = prev?.labour?.avgWage ?? null;

  // Businesses
  const businesses = {
    active: Number(eco.db.prepare("SELECT COUNT(*) AS n FROM businesses WHERE status = 'active'").get().n),
    suspended: Number(eco.db.prepare("SELECT COUNT(*) AS n FROM businesses WHERE status = 'suspended'").get().n),
    registered: Number(eco.db.prepare("SELECT COUNT(*) AS n FROM businesses WHERE status IN ('active','suspended') AND decided_day = ?").get(day).n),
    closed: Number(eco.db.prepare('SELECT COUNT(*) AS n FROM businesses WHERE closed_day = ?').get(day).n),
    pending: Number(eco.db.prepare("SELECT COUNT(*) AS n FROM businesses WHERE status = 'pending'").get().n),
    licenseFees: sumWhere(eco, "econ_day = ? AND category = 'business_license_fee'", day),
    productionCosts: sumWhere(eco, "econ_day = ? AND category = 'production_cost'", day),
    openJobs: Number(eco.db.prepare("SELECT COUNT(*) AS n FROM jobs j JOIN businesses b ON b.id = j.business_id WHERE j.status = 'open' AND b.status = 'active'").get().n),
  };

  // Treasury and AVK
  const flows = treasuryFlows(eco, day);
  const avk = systemAccountId(eco, 'avk');
  const avkStats = {
    balance: getAccount(eco, avk).balance,
    premiums: sumWhere(eco, "econ_day = ? AND category = 'insurance_premium'", day),
    claimsPaid: sumWhere(eco, "econ_day = ? AND category = 'insurance_payout'", day),
    claimsSubmitted: Number(eco.db.prepare('SELECT COUNT(*) AS n FROM insurance_claims WHERE created_day = ?').get(day).n),
    activePolicies: Number(eco.db.prepare("SELECT COUNT(*) AS n FROM insurance_policies WHERE status = 'active'").get().n),
  };

  const credit = creditSummary(eco, day);
  const events = {
    active: eventsActiveOn(eco, day + 1).map((e) => ({ id: e.id, key: e.event_key, name: e.name, startDay: e.start_day, endDay: e.end_day, effects: e.effects })),
    ended: eco.db.prepare("SELECT id, event_key AS key, name FROM event_instances WHERE end_day = ? AND status <> 'cancelled'").all(day),
    started: eco.db.prepare("SELECT id, event_key AS key, name, start_day AS startDay, end_day AS endDay, source FROM event_instances WHERE start_day = ? AND status <> 'cancelled'").all(day + 1),
  };

  return {
    day, date,
    money: { stock: stock.total, private: stock.private, public: stock.public, created, removed, genesis, prevStock: prev?.money?.stock ?? null },
    gdp: {
      estimate: gdp, productionValue, sales: salesToHouseholdsAndState, publicWages, housing,
      prev: prev?.gdp?.estimate ?? null, avg7: Math.round(gdpHistory.reduce((s, v) => s + v, 0) / gdpHistory.length), daysInAverage: gdpHistory.length,
    },
    prices: {
      cpi: stateNext.cpi, cpiPrev: stateToday.cpi, cpi30Base: cpi30Base.cpi, inflationBasis,
      fx: stateNext.fx, fxPrev: stateToday.fx,
    },
    labour: {
      activeCitizens, employedActive, unemploymentRate: activeCitizens > 0 ? (activeCitizens - employedActive) / activeCitizens : null,
      shifts: Number(shiftRows.n), publicShifts: Number(shiftRows.pub ?? 0), avgWage: shiftRows.avg ? Math.round(Number(shiftRows.avg)) : null, prevAvgWage,
    },
    treasury: { balance: flows.balance, revenue: flows.revenue, expenditure: flows.expenditure, totalRevenue: flows.totalRevenue, totalExpenditure: flows.totalExpenditure,
      prevBalance: prev?.treasury?.balance ?? null },
    trade: { commodities, exportsTotal, importsTotal, byPartner },
    finance: { policyRateBp: getPolicy(eco, 'policy_rate_bp'), ...credit, collected: tick?.credit?.collected ?? 0, missed: tick?.credit?.missed ?? 0, newDefaults: tick?.credit?.defaults?.length ?? 0 },
    avk: { ...avkStats, lapsed: tick?.premiums?.lapsed ?? 0 },
    businesses,
    obligations: {
      rentCollected: tick?.rent?.collected ?? 0, rentMissed: tick?.rent?.missed ?? 0, evictions: tick?.rent?.evictions?.length ?? 0,
      wagesUnpaid: tick?.payroll?.unpaid ?? 0, finesCollected: tick?.fines?.collected ?? 0,
    },
    events,
    policyChanges: policyChangesOnDay(eco, day).map((p) => ({ key: p.target, old: JSON.parse(p.old_value ?? 'null'), value: JSON.parse(p.new_value ?? 'null'), reason: p.reason })),
    late: !!tick?.late,
  };
}
