// Game parameters for the Kagundi economic simulation.
// Every value here is a fictional gameplay parameter, not a real-world statistic.
// Money is always stored in minor units: 100 = 1.00 KGD.

export const KGD = (amount) => Math.round(amount * 100);

// Exchange rate used to convert world prices (quoted in EUR) into Kagundi Dinar.
export const BASE_FX_KGD_PER_EUR = 10.0;

export const PARTNERS = {
  germany: { key: 'germany', name: 'Germany', exportPriceFactor: 1.0, importPriceFactor: 1.0 },
  eu: { key: 'eu', name: 'European Union', exportPriceFactor: 0.985, importPriceFactor: 1.01 },
  china: { key: 'china', name: 'China', exportPriceFactor: 0.97, importPriceFactor: 0.96 },
};
export const PARTNER_KEYS = Object.keys(PARTNERS);

// world price in EUR per unit. volatility = daily standard deviation of the log price.
// outputPerShift / unitCostEur only apply to commodities produced domestically.
export const COMMODITIES = {
  gold: {
    key: 'gold', name: 'Gold', unit: 'g', baseEur: 14.0, volatility: 0.012, meanReversion: 0.05,
    tradable: 'export', industry: 'mining', outputPerShift: 13, unitCostEur: 2.8, baselineDailyExport: 80,
  },
  diamonds: {
    key: 'diamonds', name: 'Diamonds', unit: 'ct', baseEur: 35.0, volatility: 0.015, meanReversion: 0.05,
    tradable: 'export', industry: 'mining', outputPerShift: 5, unitCostEur: 7.0, baselineDailyExport: 30,
  },
  palladium: {
    key: 'palladium', name: 'Palladium', unit: 'g', baseEur: 7.0, volatility: 0.018, meanReversion: 0.05,
    tradable: 'export', industry: 'mining', outputPerShift: 26, unitCostEur: 1.4, baselineDailyExport: 160,
  },
  timber: {
    key: 'timber', name: 'Timber', unit: 'm³', baseEur: 12.0, volatility: 0.008, meanReversion: 0.06,
    tradable: 'export', industry: 'timber', outputPerShift: 15, unitCostEur: 2.4, baselineDailyExport: 90,
  },
  tobacco: {
    key: 'tobacco', name: 'Tobacco', unit: 'kg', baseEur: 2.8, volatility: 0.01, meanReversion: 0.06,
    tradable: 'export', industry: 'tobacco', outputPerShift: 64, unitCostEur: 0.56, baselineDailyExport: 380,
  },
  beef: {
    key: 'beef', name: 'Beef', unit: 'kg', baseEur: 1.8, volatility: 0.008, meanReversion: 0.06,
    tradable: 'export', industry: 'cattle', outputPerShift: 100, unitCostEur: 0.36, baselineDailyExport: 600,
  },
  fuel: {
    key: 'fuel', name: 'Fuel', unit: 'L', baseEur: 0.9, volatility: 0.012, meanReversion: 0.06,
    tradable: 'import', baselineDailyImport: 2000,
  },
  food: {
    key: 'food', name: 'Food & Essentials', unit: 'crate', baseEur: 4.0, volatility: 0.006, meanReversion: 0.08,
    tradable: 'import', baselineDailyImport: 200,
  },
  construction: {
    key: 'construction', name: 'Construction Materials', unit: 't', baseEur: 60.0, volatility: 0.007, meanReversion: 0.06,
    tradable: 'import', baselineDailyImport: 20,
  },
};
export const COMMODITY_KEYS = Object.keys(COMMODITIES);
export const EXPORT_COMMODITIES = COMMODITY_KEYS.filter((k) => COMMODITIES[k].tradable === 'export');
export const IMPORT_COMMODITIES = COMMODITY_KEYS.filter((k) => COMMODITIES[k].tradable === 'import');

// Share of world price added as domestic transport and handling cost for imports (landlocked country).
export const IMPORT_TRANSPORT_RATE = 0.06;
// Largest allowed daily move of any world price (log terms), so players can plan.
export const MAX_DAILY_PRICE_MOVE = 0.04;
export const PRICE_FLOOR_FACTOR = 0.5;
export const PRICE_CEILING_FACTOR = 2.0;
// How strongly heavy export volume pushes the next day's world price down.
export const EXPORT_PRICE_IMPACT = 0.01;

export const INDUSTRIES = {
  mining: { key: 'mining', name: 'Mining', outputs: ['gold', 'diamonds', 'palladium'], fuelPerShift: 8, licenseFeeDaily: KGD(150) },
  timber: { key: 'timber', name: 'Timber & Forestry', outputs: ['timber'], fuelPerShift: 7, licenseFeeDaily: KGD(100) },
  tobacco: { key: 'tobacco', name: 'Tobacco Farming', outputs: ['tobacco'], fuelPerShift: 4, licenseFeeDaily: KGD(80) },
  cattle: { key: 'cattle', name: 'Cattle & Beef', outputs: ['beef'], fuelPerShift: 4, licenseFeeDaily: KGD(80) },
  transportation: { key: 'transportation', name: 'Transport & Freight', outputs: [], licenseFeeDaily: KGD(60) },
  retail: { key: 'retail', name: 'Retail & Consumer Services', outputs: [], licenseFeeDaily: KGD(50) },
  construction: { key: 'construction', name: 'Construction', outputs: [], licenseFeeDaily: KGD(70) },
  property_management: { key: 'property_management', name: 'Property Management', outputs: [], licenseFeeDaily: KGD(50) },
  financial_services: { key: 'financial_services', name: 'Financial Services', outputs: [], licenseFeeDaily: KGD(120) },
};
export const INDUSTRY_KEYS = Object.keys(INDUSTRIES);

// Maximum paid worker shifts a single business can turn into production per day.
export const MAX_PRODUCTION_SHIFTS_PER_BUSINESS = 8;

// Public-sector jobs. A member holding the Discord role with this key can clock in for this job.
// Wages are paid by the treasury and booked to the given budget category.
export const STATE_JOBS = [
  { department: 'leader', title: 'Leader of the Revolution', wage: KGD(1000), budget: 'administration' },
  { department: 'secretary_general', title: 'Secretary-General of the People\'s Committee', wage: KGD(900), budget: 'administration' },
  { department: 'secretary_internal', title: 'Secretary for Internal Affairs and Infrastructure', wage: KGD(850), budget: 'administration' },
  { department: 'secretary_defence', title: 'Secretary for Defence and Foreign Affairs', wage: KGD(850), budget: 'administration' },
  { department: 'secretary_economy', title: 'Secretary for Economy and Education', wage: KGD(850), budget: 'administration' },
  { department: 'secretary_health', title: 'Secretary for Health and Crisis Management', wage: KGD(850), budget: 'administration' },
  { department: 'secretariat_member', title: 'Secretariat Member', wage: KGD(700), budget: 'administration' },
  { department: 'government_official', title: 'Government Official', wage: KGD(650), budget: 'administration' },
  { department: 'congress_representative', title: 'General People\'s Congress Representative', wage: KGD(450), budget: 'administration' },
  { department: 'council_member', title: 'People\'s Council Member', wage: KGD(350), budget: 'administration' },
  { department: 'judge', title: 'Judge', wage: KGD(700), budget: 'justice' },
  { department: 'justice', title: 'Justice Officer (Lawyer / Prosecutor / Clerk)', wage: KGD(600), budget: 'justice' },
  { department: 'guard_command', title: 'Revolutionary Guard Command', wage: KGD(900), budget: 'defence' },
  { department: 'revolutionary_guard', title: 'Revolutionary Guard', wage: KGD(750), budget: 'defence' },
  { department: 'intelligence', title: 'Intelligence Service Officer', wage: KGD(750), budget: 'defence' },
  { department: 'gendarmerie_command', title: 'Gendarmerie Command', wage: KGD(800), budget: 'security' },
  { department: 'gendarmerie', title: 'Gendarme', wage: KGD(650), budget: 'security' },
  { department: 'armed_forces_command', title: 'Armed Forces Command', wage: KGD(800), budget: 'defence' },
  { department: 'land_forces', title: 'Land Forces Soldier', wage: KGD(550), budget: 'defence' },
  { department: 'air_force', title: 'Air Force Airman', wage: KGD(600), budget: 'defence' },
  { department: 'police_command', title: 'City Police Command', wage: KGD(750), budget: 'security' },
  { department: 'city_police', title: 'City Police Officer', wage: KGD(600), budget: 'security' },
  { department: 'ems_command', title: 'EMS Command', wage: KGD(750), budget: 'healthcare' },
  { department: 'ems', title: 'EMS Paramedic', wage: KGD(600), budget: 'healthcare' },
  { department: 'brandwehr_command', title: 'Brandwehr Command', wage: KGD(750), budget: 'emergency_services' },
  { department: 'brandwehr', title: 'Brandwehr Firefighter', wage: KGD(600), budget: 'emergency_services' },
  { department: 'avk_officer', title: 'AVK Insurance Officer', wage: KGD(600), budget: 'public_services' },
];

// Public expenditure categories (budget lines). Wages are booked to the job's budget line.
export const BUDGET_CATEGORIES = {
  administration: 'Government & Administration',
  security: 'Police & Gendarmerie',
  defence: 'Defence & Revolutionary Guard',
  justice: 'Justice',
  healthcare: 'Healthcare & EMS',
  emergency_services: 'Brandwehr & Civil Protection',
  education: 'Education',
  infrastructure: 'Infrastructure',
  public_services: 'Public Services & AVK',
  procurement: 'Public Procurement',
  other: 'Other Expenditure',
};
export const BUDGET_CATEGORY_KEYS = Object.keys(BUDGET_CATEGORIES);
export const BUDGET_PERIOD_DAYS = 30;

// Policy parameters (stored in the database, changed only through audited commands).
// bp = basis points (100 bp = 1%).
export const POLICY_DEFAULTS = {
  policy_rate_bp: 600,
  income_tax_bp: 1000,
  turnover_tax_bp: 500,
  distribution_tax_bp: 1000,
  property_tax_annual_bp: 150,
  property_transfer_tax_bp: 200,
  registration_fee: KGD(1000),
  min_wage_daily: KGD(150),
  max_private_wage_daily: KGD(2500),
  starting_grant: KGD(2500),
  import_tariff_bp: { fuel: 500, food: 800, construction: 600 },
  export_duty_bp: { gold: 800, diamonds: 1000, palladium: 800, timber: 500, tobacco: 600, beef: 400 },
  export_ban: {},
};

// Allowed ranges for policy changes. A value outside the range is rejected.
export const POLICY_LIMITS = {
  policy_rate_bp: [0, 2500],
  income_tax_bp: [0, 4000],
  turnover_tax_bp: [0, 2000],
  distribution_tax_bp: [0, 3000],
  property_tax_annual_bp: [0, 500],
  property_transfer_tax_bp: [0, 1000],
  registration_fee: [0, KGD(20000)],
  min_wage_daily: [0, KGD(1000)],
  max_private_wage_daily: [KGD(500), KGD(10000)],
  starting_grant: [0, KGD(5000)],
  import_tariff_bp: [0, 5000],
  export_duty_bp: [0, 4000],
};

// Policy rate considered "neutral" when calibrating lending spreads and the exchange rate.
export const NEUTRAL_POLICY_RATE_BP = 600;

// Credit bands. Lending rate = band rate + (policy rate - neutral policy rate), never below 100 bp.
export const CREDIT_BANDS = [
  { min: 300, max: 499, label: 'Very Poor', rateBp: 1800, maxLoan: KGD(0), cardLimit: KGD(0) },
  { min: 500, max: 599, label: 'Poor', rateBp: 1400, maxLoan: KGD(2000), cardLimit: KGD(500) },
  { min: 600, max: 699, label: 'Average', rateBp: 1000, maxLoan: KGD(10000), cardLimit: KGD(2000) },
  { min: 700, max: 799, label: 'Good', rateBp: 700, maxLoan: KGD(25000), cardLimit: KGD(5000) },
  { min: 800, max: 850, label: 'Excellent', rateBp: 500, maxLoan: KGD(50000), cardLimit: KGD(10000) },
];
export const STARTING_CREDIT_SCORE = 600;

export const CREDIT_RULES = {
  maxDebtToIncome: 0.35, // monthly debt obligations / verified monthly net income
  minHistoryDays: 7, // days of recorded income history before credit is offered
  installmentIntervalDays: 7,
  minTermWeeks: 2,
  maxTermWeeks: 12,
  autoApproveLimit: KGD(5000), // larger loans need a human credit officer
  maxActiveLoans: 2,
  lateFeeRate: 0.02,
  lateFeeMin: KGD(10),
  defaultAfterMissed: 4, // consecutive missed installments before a facility is in default
  cardMinPaymentRate: 0.1,
  cardMinPayment: KGD(50),
  cardHeadroomFactor: 0.5, // extra hard ceiling for interest and fees above the approved card limit
  daysPerYear: 365,
};

// AVK - Allgemeine Volksversicherung Kagundi.
// Premiums: either a daily rate of the insured value (pcm = per 100,000) or a flat daily premium.
export const AVK_PRODUCTS = {
  vehicle: { key: 'vehicle', name: 'Vehicle Insurance', dailyRatePcm: 50, deductible: KGD(500), minValue: KGD(1000), maxValue: KGD(250000), needs: null },
  property: { key: 'property', name: 'Property Insurance', dailyRatePcm: 10, deductible: KGD(1000), minValue: KGD(5000), maxValue: KGD(2000000), needs: 'property' },
  business: { key: 'business', name: 'Business Insurance', dailyRatePcm: 20, deductible: KGD(1000), minValue: KGD(5000), maxValue: KGD(1000000), needs: 'business' },
  liability: { key: 'liability', name: 'Liability Coverage', flatDaily: KGD(15), coverage: KGD(50000), deductible: KGD(250), needs: null },
  accident: { key: 'accident', name: 'Accident Insurance', flatDaily: KGD(10), coverage: KGD(20000), deductible: KGD(0), needs: null },
  health_plus: { key: 'health_plus', name: 'Supplementary Health (private treatment only)', flatDaily: KGD(12), coverage: KGD(15000), deductible: KGD(100), needs: null },
};
export const AVK_PRODUCT_KEYS = Object.keys(AVK_PRODUCTS);
export const AVK_RULES = {
  waitingPeriodDays: 2, // a claim needs a policy that was active at least this many days
  lapseAfterUnpaidDays: 3,
};

export const RENT_RULES = { evictAfterMissedDays: 3 };
export const FINE_RULES = { dueAfterDays: 3, maxFine: KGD(50000) };
export const INVOICE_RULES = { expireAfterDays: 7, maxAmount: KGD(1000000) };
export const BUSINESS_RULES = { suspendAfterUnpaidLicenseDays: 7, unpaidShiftRetryDays: 7 };

export const CITIES = ['Gundiville', 'Stokondo', 'Kagundali', 'Oberdueshuson'];
export const PROPERTY_TYPES = ['residential', 'commercial', 'industrial', 'agricultural'];

// State-owned properties that exist at launch. Values and rents are in KGD.
export const GENESIS_PROPERTIES = [
  { name: 'Gundiville Central Apartment 1', city: 'Gundiville', type: 'residential', value: 32000, rent: 160 },
  { name: 'Gundiville Central Apartment 2', city: 'Gundiville', type: 'residential', value: 32000, rent: 160 },
  { name: 'Gundiville Riverside Apartment', city: 'Gundiville', type: 'residential', value: 28000, rent: 140 },
  { name: 'Gundiville Embassy Row House', city: 'Gundiville', type: 'residential', value: 85000, rent: 340, forSale: true },
  { name: 'Gundiville Commercial District Office', city: 'Gundiville', type: 'commercial', value: 60000, rent: 260 },
  { name: 'Gundiville Market Street Retail Unit', city: 'Gundiville', type: 'commercial', value: 50000, rent: 210 },
  { name: 'Stokondo Courthouse Quarter Apartment', city: 'Stokondo', type: 'residential', value: 26000, rent: 130 },
  { name: 'Stokondo Polyclinic Lane Apartment', city: 'Stokondo', type: 'residential', value: 26000, rent: 130 },
  { name: 'Stokondo Legal Chambers Office', city: 'Stokondo', type: 'commercial', value: 45000, rent: 190 },
  { name: 'Kagundali Workers\' Apartment 1', city: 'Kagundali', type: 'residential', value: 22000, rent: 110 },
  { name: 'Kagundali Workers\' Apartment 2', city: 'Kagundali', type: 'residential', value: 22000, rent: 110 },
  { name: 'Kagundali Freight Warehouse', city: 'Kagundali', type: 'industrial', value: 55000, rent: 230 },
  { name: 'Kagundali Ore Yard Industrial Lot', city: 'Kagundali', type: 'industrial', value: 70000, rent: 270, forSale: true },
  { name: 'Oberdueshuson Farmhouse', city: 'Oberdueshuson', type: 'residential', value: 30000, rent: 120, forSale: true },
  { name: 'Oberdueshuson Tobacco Fields', city: 'Oberdueshuson', type: 'agricultural', value: 40000, rent: 150 },
  { name: 'Oberdueshuson Garrison Town Apartment', city: 'Oberdueshuson', type: 'residential', value: 20000, rent: 100 },
];

export const GENESIS_FUNDS = {
  treasury: KGD(1500000),
  avk: KGD(200000),
};

// Weights of the consumer price index basket.
export const CPI_WEIGHTS = { food: 0.5, fuel: 0.25, construction: 0.15, rent: 0.1 };

export const EXCHANGE_RATE_RULES = {
  maxDailyMove: 0.005,
  floorFactor: 0.5,
  ceilingFactor: 3.0,
  moneyGrowthPassThrough: 0.5,
  rateSensitivity: 2.0,
  tradeSensitivity: 0.5,
  volatility: 0.001,
};
