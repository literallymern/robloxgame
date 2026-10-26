// Catalogue of economic events. Events never move money directly; they only change
// simulation variables (prices, production, costs, partner demand) for a bounded time.
//
// Effect types:
//   price_drift      { commodity, perDay }      extra daily change of the world price (log), |perDay| <= 0.03
//   production       { target, multiplier }     target = commodity key, industry key or 'all'; 0.5..1.5
//   production_cost  { target, multiplier }     target = industry key or 'all'; 0.5..1.5
//   partner_demand   { partner, multiplier }    level effect on a partner's export price factor; 0.8..1.2
//
// probability = chance per economic day that the event starts on its own (0 = admin only).
// cooldownDays = minimum days between two random starts of the same event.

export const EVENT_CATALOG = {
  gold_demand_surge: {
    name: 'International gold demand surge',
    description: 'Investors abroad are buying gold. Export prices for gold rise for several days.',
    durationDays: 5, probability: 0.02, cooldownDays: 20,
    effects: [{ type: 'price_drift', commodity: 'gold', perDay: 0.012 }],
  },
  diamond_slump: {
    name: 'Diamond market slump',
    description: 'Weak demand from jewellery buyers pushes diamond prices down.',
    durationDays: 4, probability: 0.02, cooldownDays: 20,
    effects: [{ type: 'price_drift', commodity: 'diamonds', perDay: -0.012 }],
  },
  palladium_industry_demand: {
    name: 'European industrial demand for palladium',
    description: 'European manufacturers order more palladium. Prices and EU demand rise.',
    durationDays: 6, probability: 0.015, cooldownDays: 25,
    effects: [
      { type: 'price_drift', commodity: 'palladium', perDay: 0.008 },
      { type: 'partner_demand', partner: 'eu', multiplier: 1.05 },
    ],
  },
  mine_flooding: {
    name: 'Flooding in the Kagundali mining district',
    description: 'Heavy rain floods several mine shafts. Mining output per shift falls.',
    durationDays: 3, probability: 0.015, cooldownDays: 20,
    effects: [{ type: 'production', target: 'mining', multiplier: 0.6 }],
  },
  bumper_tobacco_harvest: {
    name: 'Bumper tobacco harvest',
    description: 'Excellent weather around Oberdueshuson boosts tobacco output, while prices soften.',
    durationDays: 5, probability: 0.015, cooldownDays: 30,
    effects: [
      { type: 'production', target: 'tobacco', multiplier: 1.3 },
      { type: 'price_drift', commodity: 'tobacco', perDay: -0.005 },
    ],
  },
  drought: {
    name: 'Highland drought',
    description: 'A dry spell reduces tobacco and cattle output and raises food import costs.',
    durationDays: 6, probability: 0.01, cooldownDays: 40,
    effects: [
      { type: 'production', target: 'tobacco', multiplier: 0.75 },
      { type: 'production', target: 'cattle', multiplier: 0.75 },
      { type: 'price_drift', commodity: 'food', perDay: 0.008 },
    ],
  },
  fuel_price_spike: {
    name: 'International fuel price spike',
    description: 'Fuel import prices climb, raising transport and production costs.',
    durationDays: 4, probability: 0.02, cooldownDays: 20,
    effects: [{ type: 'price_drift', commodity: 'fuel', perDay: 0.02 }],
  },
  road_disruption: {
    name: 'Disruption on the Gundiville-Kagundali highway',
    description: 'Landslides block a main freight route. Production costs rise while trucks take detours.',
    durationDays: 3, probability: 0.015, cooldownDays: 20,
    effects: [{ type: 'production_cost', target: 'all', multiplier: 1.15 }],
  },
  mining_accident: {
    name: 'Industrial accident in a mine',
    description: 'Safety inspections after an accident slow mining operations nationwide.',
    durationDays: 2, probability: 0.01, cooldownDays: 30,
    effects: [{ type: 'production', target: 'mining', multiplier: 0.8 }],
  },
  german_trade_mission: {
    name: 'German trade mission visits Gundiville',
    description: 'German buyers sign new purchase agreements. German demand for Kagundi exports rises.',
    durationDays: 7, probability: 0.012, cooldownDays: 40,
    effects: [{ type: 'partner_demand', partner: 'germany', multiplier: 1.06 }],
  },
  china_demand_dip: {
    name: 'Weaker Chinese demand',
    description: 'Chinese importers reduce orders. Prices offered by Chinese buyers fall.',
    durationDays: 5, probability: 0.015, cooldownDays: 30,
    effects: [{ type: 'partner_demand', partner: 'china', multiplier: 0.93 }],
  },
  labour_shortage: {
    name: 'Skilled labour shortage',
    description: 'Shortages of trained workers reduce output per shift in all producing industries.',
    durationDays: 4, probability: 0.01, cooldownDays: 30,
    effects: [{ type: 'production', target: 'all', multiplier: 0.9 }],
  },
  infrastructure_programme: {
    name: 'National infrastructure programme',
    description: 'The government launches road and grid works. Demand for construction materials rises.',
    durationDays: 7, probability: 0, cooldownDays: 0,
    effects: [{ type: 'price_drift', commodity: 'construction', perDay: 0.008 }],
  },
  border_customs_slowdown: {
    name: 'Slowdown at the border crossings',
    description: 'Stricter customs checks delay freight. Production costs rise slightly.',
    durationDays: 3, probability: 0, cooldownDays: 0,
    effects: [{ type: 'production_cost', target: 'all', multiplier: 1.08 }],
  },
};

export const EVENT_KEYS = Object.keys(EVENT_CATALOG);
export const MAX_CONCURRENT_RANDOM_EVENTS = 2;

export function validateEventCatalog(catalog = EVENT_CATALOG) {
  const problems = [];
  for (const [key, ev] of Object.entries(catalog)) {
    if (!(ev.durationDays >= 1 && ev.durationDays <= 30)) problems.push(`${key}: durationDays out of range`);
    if (!(ev.probability >= 0 && ev.probability <= 0.2)) problems.push(`${key}: probability out of range`);
    for (const e of ev.effects) {
      if (e.type === 'price_drift' && !(Math.abs(e.perDay) <= 0.03)) problems.push(`${key}: price drift too large`);
      if ((e.type === 'production' || e.type === 'production_cost') && !(e.multiplier >= 0.5 && e.multiplier <= 1.5)) problems.push(`${key}: multiplier out of range`);
      if (e.type === 'partner_demand' && !(e.multiplier >= 0.8 && e.multiplier <= 1.2)) problems.push(`${key}: partner multiplier out of range`);
    }
  }
  return problems;
}
