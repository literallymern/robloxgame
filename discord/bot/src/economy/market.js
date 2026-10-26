// Commodity market: world prices, partner prices, exchange rate and consumer prices.
import {
  COMMODITIES, PARTNERS, PARTNER_KEYS, BASE_FX_KGD_PER_EUR, IMPORT_TRANSPORT_RATE, MAX_DAILY_PRICE_MOVE,
  PRICE_FLOOR_FACTOR, PRICE_CEILING_FACTOR, EXPORT_PRICE_IMPACT, EXCHANGE_RATE_RULES, NEUTRAL_POLICY_RATE_BP,
  CPI_WEIGHTS, POLICY_DEFAULTS,
} from './constants.js';
import { effectsForDay } from './events.js';
import { getPolicy } from './policy.js';

const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

function priceDayFor(eco, day) {
  const row = eco.db.prepare('SELECT MAX(day) AS d FROM market_prices WHERE day <= ?').get(day);
  return row?.d ?? 1;
}

export function pricesForDay(eco, day = eco.currentDay()) {
  const d = priceDayFor(eco, day);
  const rows = eco.db.prepare('SELECT * FROM market_prices WHERE day = ?').all(d);
  return Object.fromEntries(rows.map((r) => [r.commodity, r]));
}

export function marketStateFor(eco, day = eco.currentDay()) {
  const row = eco.db.prepare('SELECT * FROM market_state WHERE day <= ? ORDER BY day DESC LIMIT 1').get(day);
  return { ...row, partnerDemand: JSON.parse(row.partner_demand) };
}

// Price per unit (minor units) that a partner pays for a Kagundi export today.
export function exportQuote(eco, commodity, partner, day = eco.currentDay()) {
  const p = pricesForDay(eco, day)[commodity];
  const state = marketStateFor(eco, day);
  const fx = effectsForDay(eco, day);
  const factor = PARTNERS[partner].exportPriceFactor * (state.partnerDemand[partner] ?? 1) * fx.partnerMultiplier(partner);
  return Math.max(1, Math.round(p.price_kgd * factor));
}

// Landed price per unit (minor units, before import tariff) when importing from a partner today.
export function importQuote(eco, commodity, partner, day = eco.currentDay()) {
  const p = pricesForDay(eco, day)[commodity];
  return Math.max(1, Math.round(p.landed_kgd * PARTNERS[partner].importPriceFactor));
}

// Domestic consumer price incl. the current tariff, used for the CPI.
function consumerPrice(landedKgd, tariffBp) {
  return landedKgd * (1 + tariffBp / 10000);
}

export function baseConsumerPrices() {
  const out = {};
  for (const key of ['food', 'fuel', 'construction']) {
    const kgd = COMMODITIES[key].baseEur * BASE_FX_KGD_PER_EUR * 100 * (1 + IMPORT_TRANSPORT_RATE);
    out[key] = consumerPrice(kgd, POLICY_DEFAULTS.import_tariff_bp[key] ?? 0);
  }
  return out;
}

export function averageRent(eco) {
  return Number(eco.db.prepare('SELECT AVG(daily_rent) AS a FROM properties').get().a ?? 0);
}

// Computes and stores the prices and market state that apply on day + 1.
// inputs: moneyGrowthDaily (average daily growth of the money stock over the last week),
//         netExportsShareDaily (average daily net exports / money stock over the last week),
//         exportVolumes ({commodity: quantity exported on `day`}).
export function computeNextMarket(eco, day, rng, inputs) {
  const fx0 = marketStateFor(eco, day);
  const prices0 = pricesForDay(eco, day);
  const effects = effectsForDay(eco, day);
  const policyRate = getPolicy(eco, 'policy_rate_bp');
  const R = EXCHANGE_RATE_RULES;

  // Exchange rate (KGD per EUR). Faster money growth weakens the dinar, a higher policy rate and
  // a trade surplus strengthen it. Bounded so it can never jump.
  const rateDiffDaily = (policyRate - NEUTRAL_POLICY_RATE_BP) / 10000 / 365;
  let dFx = R.moneyGrowthPassThrough * (inputs.moneyGrowthDaily ?? 0)
    - R.rateSensitivity * rateDiffDaily
    - R.tradeSensitivity * (inputs.netExportsShareDaily ?? 0)
    + R.volatility * rng.normal();
  dFx = clamp(dFx, -R.maxDailyMove, R.maxDailyMove);
  const fx = clamp(fx0.fx * Math.exp(dFx), BASE_FX_KGD_PER_EUR * R.floorFactor, BASE_FX_KGD_PER_EUR * R.ceilingFactor);

  // Partner demand indices: slow random walk around 1.0.
  const demand = {};
  for (const p of PARTNER_KEYS) {
    const idx = fx0.partnerDemand[p] ?? 1;
    demand[p] = clamp(idx + 0.1 * (1 - idx) + 0.01 * rng.normal(), 0.85, 1.15);
  }

  const insert = eco.db.prepare(`INSERT INTO market_prices (day, commodity, world_eur, price_kgd, landed_kgd) VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(day, commodity) DO UPDATE SET world_eur = excluded.world_eur, price_kgd = excluded.price_kgd, landed_kgd = excluded.landed_kgd`);
  const next = {};
  for (const c of Object.values(COMMODITIES)) {
    const p0 = prices0[c.key].world_eur;
    const z = rng.normal();
    let move = c.meanReversion * Math.log(c.baseEur / p0) + c.volatility * z + effects.drift(c.key);
    if (c.tradable === 'export') {
      const volume = inputs.exportVolumes?.[c.key] ?? 0;
      move -= EXPORT_PRICE_IMPACT * Math.max(0, volume / c.baselineDailyExport - 1);
    }
    move = clamp(move, -MAX_DAILY_PRICE_MOVE, MAX_DAILY_PRICE_MOVE);
    const world = clamp(p0 * Math.exp(move), c.baseEur * PRICE_FLOOR_FACTOR, c.baseEur * PRICE_CEILING_FACTOR);
    const kgd = Math.round(world * fx * 100);
    const landed = Math.round(kgd * (1 + IMPORT_TRANSPORT_RATE));
    insert.run(day + 1, c.key, world, kgd, landed);
    next[c.key] = { world_eur: world, price_kgd: kgd, landed_kgd: landed };
  }

  // Consumer price index (100 = launch level).
  const tariffs = getPolicy(eco, 'import_tariff_bp');
  const base = baseConsumerPrices();
  const baseRent = Number(eco.meta('base_average_rent') ?? 0) || averageRent(eco) || 1;
  const rentIndex = averageRent(eco) / baseRent || 1;
  let cpi = 0;
  for (const key of ['food', 'fuel', 'construction']) {
    cpi += CPI_WEIGHTS[key] * (consumerPrice(next[key].landed_kgd, tariffs[key] ?? 0) / base[key]);
  }
  cpi += CPI_WEIGHTS.rent * rentIndex;
  cpi *= 100;

  eco.db.prepare(`INSERT INTO market_state (day, fx, partner_demand, cpi, rent_index) VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(day) DO UPDATE SET fx = excluded.fx, partner_demand = excluded.partner_demand, cpi = excluded.cpi, rent_index = excluded.rent_index`)
    .run(day + 1, fx, JSON.stringify(demand), cpi, rentIndex);
  return { fx, demand, cpi, prices: next };
}
