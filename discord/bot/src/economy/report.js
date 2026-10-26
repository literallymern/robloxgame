// Builds the daily National Economic Report from a snapshot of the simulation state.
// The report is stored once when the day is processed, so republishing never changes its numbers.
import { BUDGET_CATEGORIES, COMMODITIES, PARTNERS, BASE_FX_KGD_PER_EUR } from './constants.js';
import { EVENT_CATALOG } from './event-catalog.js';
import { formatKGD, formatCompact, formatPct, bpToPct } from './money.js';

const REVENUE_LABELS = {
  income_tax: 'Income tax', turnover_tax: 'Turnover tax', export_duty: 'Export duties', import_tariff: 'Import tariffs',
  property_tax: 'Property tax', property_transfer_tax: 'Property transfer tax', distribution_tax: 'Distribution tax',
  state_dividend: 'State dividends', business_registration_fee: 'Registration fees', business_license_fee: 'Licence fees',
  fine: 'Fines', state_rent: 'State rents', property_sale: 'State property sales', central_bank_financing: 'Central Bank financing',
  admin_correction: 'Administrative corrections',
};

const ratio = (a, b) => (b ? a / b - 1 : null);

function revenueLines(snapshot) {
  const entries = Object.entries(snapshot.treasury.revenue).sort((a, b) => b[1] - a[1]);
  if (!entries.length) return 'No revenue recorded.';
  return entries.slice(0, 6).map(([k, v]) => `${REVENUE_LABELS[k] ?? k} ${formatCompact(v)}`).join(' · ');
}

function expenditureLines(snapshot) {
  const byCat = {};
  let wages = 0;
  for (const [k, v] of Object.entries(snapshot.treasury.expenditure)) {
    const [kind, cat] = k.split(':');
    if (kind === 'public_wage') wages += v;
    const label = cat ? BUDGET_CATEGORIES[cat] ?? cat : k;
    byCat[label] = (byCat[label] ?? 0) + v;
  }
  const entries = Object.entries(byCat).sort((a, b) => b[1] - a[1]);
  if (!entries.length) return { wages, text: 'No expenditure recorded.' };
  return { wages, text: entries.slice(0, 6).map(([k, v]) => `${k} ${formatCompact(v)}`).join(' · ') };
}

function commodityTable(snapshot) {
  const rows = snapshot.trade.commodities.map((c) => {
    const name = `${c.name.replace('Food & Essentials', 'Food').replace('Construction Materials', 'Constr. mat.')} (${c.unit})`.padEnd(18);
    const price = (c.price / 100).toFixed(2).padStart(9);
    const chg = formatPct(c.changePct, { digits: 1 }).padStart(7);
    const activity = c.tradable === 'export' ? `out ${c.production}`.padStart(9) : `imp ${c.importsQty}`.padStart(9);
    return `${name}${price}${chg}${activity}`;
  });
  return ['Commodity           KGD/unit    Chg  Activity', ...rows].join('\n');
}

function developments(snapshot) {
  const c = [];
  for (const k of snapshot.trade.commodities) {
    if (Math.abs(k.changePct) >= 0.01) {
      c.push({ score: Math.abs(k.changePct) * 100 * (k.tradable === 'export' ? 1.2 : 1),
        text: `${k.name} ${k.changePct > 0 ? 'rose' : 'fell'} ${formatPct(Math.abs(k.changePct), { sign: false, digits: 1 })} to ${(k.price / 100).toFixed(2)} KGD/${k.unit}.` });
    }
  }
  for (const e of snapshot.events.started) {
    c.push({ score: 50, text: `New economic event: ${e.name} (days ${e.startDay}-${e.endDay}). ${EVENT_CATALOG[e.key]?.description ?? ''}`.trim() });
  }
  for (const e of snapshot.events.ended) c.push({ score: 30, text: `${e.name} has ended.` });
  for (const p of snapshot.policyChanges) {
    c.push({ score: 60, text: `Policy change: ${describePolicyKey(p.key)} changed from ${describePolicyValue(p.key, p.old)} to ${describePolicyValue(p.key, p.value)}.` });
  }
  const t = snapshot.treasury;
  const balance = t.totalRevenue - t.totalExpenditure;
  if (t.totalRevenue || t.totalExpenditure) {
    c.push({ score: 20 + Math.min(20, Math.abs(balance) / 100000), text: `The treasury recorded a ${balance >= 0 ? 'surplus' : 'deficit'} of ${formatKGD(Math.abs(balance))} (revenue ${formatKGD(t.totalRevenue)}, expenditure ${formatKGD(t.totalExpenditure)}).` });
  }
  if (snapshot.businesses.registered) c.push({ score: 25 * snapshot.businesses.registered, text: `${snapshot.businesses.registered} new business${snapshot.businesses.registered > 1 ? 'es were' : ' was'} registered.` });
  if (snapshot.businesses.closed) c.push({ score: 25 * snapshot.businesses.closed, text: `${snapshot.businesses.closed} business${snapshot.businesses.closed > 1 ? 'es' : ''} closed.` });
  if (snapshot.finance.newDefaults) c.push({ score: 35, text: `${snapshot.finance.newDefaults} credit facilit${snapshot.finance.newDefaults > 1 ? 'ies' : 'y'} went into default after repeated missed payments.` });
  if (snapshot.obligations.evictions) c.push({ score: 30, text: `${snapshot.obligations.evictions} tenanc${snapshot.obligations.evictions > 1 ? 'ies were' : 'y was'} ended for unpaid rent.` });
  if (snapshot.obligations.wagesUnpaid) c.push({ score: 30, text: `${snapshot.obligations.wagesUnpaid} wage payment${snapshot.obligations.wagesUnpaid > 1 ? 's' : ''} could not be made because employers lacked funds.` });
  const fxChg = ratio(snapshot.prices.fx, snapshot.prices.fxPrev);
  if (fxChg !== null && Math.abs(fxChg) >= 0.002) c.push({ score: Math.abs(fxChg) * 1000, text: `The dinar ${fxChg > 0 ? 'weakened' : 'strengthened'} by ${formatPct(Math.abs(fxChg), { sign: false })} to ${snapshot.prices.fx.toFixed(3)} KGD per EUR.` });
  if (snapshot.trade.exportsTotal) {
    const top = [...snapshot.trade.commodities].sort((a, b) => b.exportValue - a.exportValue)[0];
    c.push({ score: 15 + Math.min(20, snapshot.trade.exportsTotal / 1000000), text: `Exports totalled ${formatKGD(snapshot.trade.exportsTotal)}, led by ${top.name.toLowerCase()}.` });
  }
  c.sort((a, b) => b.score - a.score);
  const picked = c.slice(0, 3).map((x) => x.text);
  if (picked.length < 3) picked.push('No further significant changes were recorded on this economic day.');
  return picked;
}

function describePolicyKey(key) {
  const names = {
    policy_rate_bp: 'the central bank policy rate', income_tax_bp: 'income tax', turnover_tax_bp: 'turnover tax',
    distribution_tax_bp: 'distribution tax', property_tax_annual_bp: 'annual property tax', property_transfer_tax_bp: 'property transfer tax',
    registration_fee: 'the business registration fee', min_wage_daily: 'the minimum daily wage', max_private_wage_daily: 'the maximum private daily wage',
    starting_grant: 'the citizen starting grant',
  };
  if (names[key]) return names[key];
  const [base, commodity] = String(key).split('.');
  const cname = COMMODITIES[commodity]?.name ?? commodity;
  if (base === 'import_tariff_bp') return `the import tariff on ${cname}`;
  if (base === 'export_duty_bp') return `the export duty on ${cname}`;
  if (base === 'export_ban') return `the export ban on ${cname}`;
  return key;
}

function describePolicyValue(key, value) {
  if (value === null || value === undefined) return 'none';
  if (typeof value === 'boolean') return value ? 'in force' : 'lifted';
  if (String(key).includes('_bp')) return bpToPct(value);
  return formatKGD(value);
}

function risksAndOpportunities(snapshot, history) {
  const risks = [];
  const opps = [];
  // Treasury runway from the average result of the last days.
  const results = [snapshot, ...history].map((s) => s.treasury.totalRevenue - s.treasury.totalExpenditure);
  const avg = results.reduce((s, v) => s + v, 0) / results.length;
  if (avg < 0) {
    const runway = Math.floor(snapshot.treasury.balance / -avg);
    if (runway < 120) risks.push(`At the average deficit of the last ${results.length} day(s), treasury reserves cover about ${runway} days of spending.`);
  }
  for (const e of snapshot.events.active) {
    for (const eff of e.effects) {
      if (eff.type === 'production' && eff.multiplier < 1) risks.push(`${e.name}: output per shift for ${eff.target} is reduced until day ${e.endDay}.`);
      if (eff.type === 'production_cost' && eff.multiplier > 1) risks.push(`${e.name}: production costs are higher until day ${e.endDay}.`);
      if (eff.type === 'price_drift' && eff.perDay < 0) risks.push(`${e.name}: ${COMMODITIES[eff.commodity].name} prices are under pressure until day ${e.endDay}.`);
      if (eff.type === 'price_drift' && eff.perDay > 0) {
        const c = COMMODITIES[eff.commodity];
        if (c.tradable === 'export') opps.push(`${e.name}: ${c.name} export prices are supported until day ${e.endDay}.`);
        else risks.push(`${e.name}: ${c.name} import costs are rising until day ${e.endDay}.`);
      }
      if (eff.type === 'production' && eff.multiplier > 1) opps.push(`${e.name}: output per shift for ${eff.target} is higher until day ${e.endDay}.`);
      if (eff.type === 'partner_demand') (eff.multiplier > 1 ? opps : risks).push(`${e.name}: prices offered by ${PARTNERS[eff.partner]?.name ?? eff.partner} are ${eff.multiplier > 1 ? 'higher' : 'lower'} until day ${e.endDay}.`);
    }
  }
  for (const c of snapshot.trade.commodities) {
    const base = COMMODITIES[c.key].baseEur * BASE_FX_KGD_PER_EUR * 100; // launch price
    const rel = c.price / base - 1;
    if (c.tradable === 'export' && rel >= 0.1) opps.push(`${c.name} trades ${formatPct(rel, { sign: false, digits: 0 })} above its launch price.`);
    if (c.tradable === 'export' && rel <= -0.1) risks.push(`${c.name} trades ${formatPct(-rel, { sign: false, digits: 0 })} below its launch price.`);
  }
  const inflation = ratio(snapshot.prices.cpi, snapshot.prices.cpi30Base);
  if (inflation !== null && inflation > 0.05) risks.push(`Consumer prices are up ${formatPct(inflation, { sign: false })} (${snapshot.prices.inflationBasis}), raising living and import costs.`);
  if (snapshot.finance.defaulted) risks.push(`${snapshot.finance.defaulted} credit facilit${snapshot.finance.defaulted > 1 ? 'ies are' : 'y is'} in default.`);
  if (snapshot.businesses.openJobs) opps.push(`${snapshot.businesses.openJobs} private job posting${snapshot.businesses.openJobs > 1 ? 's are' : ' is'} open (see /jobs list).`);
  if (snapshot.finance.policyRateBp < 600) opps.push(`The policy rate of ${bpToPct(snapshot.finance.policyRateBp)} keeps borrowing costs below normal.`);
  return { risks: risks.slice(0, 4), opportunities: opps.slice(0, 4) };
}

function outlook(snapshot) {
  const parts = [];
  const continuing = snapshot.events.active.filter((e) => e.endDay > snapshot.day);
  if (continuing.length) {
    parts.push(`${continuing.length} economic event${continuing.length > 1 ? 's continue' : ' continues'} into the next day: ${continuing.map((e) => `${e.name} (until day ${e.endDay})`).join('; ')}.`);
  } else {
    parts.push('No economic events are active for the next day.');
  }
  const ups = snapshot.trade.commodities.filter((c) => c.changePct > 0.002).length;
  const downs = snapshot.trade.commodities.filter((c) => c.changePct < -0.002).length;
  parts.push(`Of nine tracked commodities, ${ups} rose and ${downs} fell in the latest price update.`);
  const result = snapshot.treasury.totalRevenue - snapshot.treasury.totalExpenditure;
  parts.push(result >= 0 ? 'Public finances were balanced or in surplus.' : 'Public spending exceeded revenue; the treasury is drawing on reserves.');
  return `${parts.join(' ')} This outlook describes current conditions and recent trends; it is not a guarantee.`;
}

export function buildReport(snapshot, history = []) {
  const s = snapshot;
  const gdpChg = ratio(s.gdp.estimate, s.gdp.prev);
  const inflation = ratio(s.prices.cpi, s.prices.cpi30Base);
  const cpiDaily = ratio(s.prices.cpi, s.prices.cpiPrev);
  const moneyChg = ratio(s.money.stock, s.money.prevStock);
  const treasuryResult = s.treasury.totalRevenue - s.treasury.totalExpenditure;
  const exp = expenditureLines(s);
  const { risks, opportunities } = risksAndOpportunities(s, history);
  const wageChg = s.labour.avgWage && s.labour.prevAvgWage ? ratio(s.labour.avgWage, s.labour.prevAvgWage) : null;

  const national = [
    `Estimated GDP (est.): **${formatKGD(s.gdp.estimate)}**${gdpChg !== null ? ` (${formatPct(gdpChg)} vs previous day)` : ''}`,
    `7-day average GDP (est.): ${formatKGD(s.gdp.avg7)} over ${s.gdp.daysInAverage} day(s)`,
    `Consumer price index: ${s.prices.cpi.toFixed(2)} (launch = 100), ${formatPct(cpiDaily)} today`,
    `Inflation (${s.prices.inflationBasis}): ${formatPct(inflation)}`,
    `Unemployment (est.): ${s.labour.unemploymentRate === null ? 'n/a - no active citizens' : formatPct(s.labour.unemploymentRate, { sign: false, digits: 1 })}`,
    `Exchange rate: ${s.prices.fx.toFixed(3)} KGD per EUR (${formatPct(ratio(s.prices.fx, s.prices.fxPrev))})`,
    `Money stock: ${formatKGD(s.money.stock)} (${formatPct(moneyChg)}); created ${formatCompact(s.money.created)}, removed ${formatCompact(s.money.removed)}`,
  ];
  const publicFinance = [
    `Treasury balance: **${formatKGD(s.treasury.balance)}**`,
    `Revenue: ${formatKGD(s.treasury.totalRevenue)} · Expenditure: ${formatKGD(s.treasury.totalExpenditure)}`,
    `Daily ${treasuryResult >= 0 ? 'surplus' : 'deficit'}: **${formatKGD(Math.abs(treasuryResult))}**`,
    `Revenue by source: ${revenueLines(s)}`,
    `Public-sector wages: ${formatKGD(exp.wages)}`,
    `Spending by area: ${exp.text}`,
  ];
  const partners = Object.entries(s.trade.byPartner).map(([k, v]) => `${PARTNERS[k].name}: exports ${formatCompact(v.exports)}, imports ${formatCompact(v.imports)}, demand ${v.demandIndex.toFixed(2)}`);
  const trade = [
    `Exports ${formatKGD(s.trade.exportsTotal)} · Imports ${formatKGD(s.trade.importsTotal)} · Balance ${formatKGD(s.trade.exportsTotal - s.trade.importsTotal, { sign: true })}`,
    ...partners,
  ];
  const finance = [
    `Central bank policy rate: ${bpToPct(s.finance.policyRateBp)}`,
    `Average lending rate: ${s.finance.avgLendingRateBp === null ? 'n/a - no credit outstanding' : bpToPct(s.finance.avgLendingRateBp)}`,
    `Credit outstanding: ${formatKGD(s.finance.outstanding)} across ${s.finance.activeFacilities} facilit${s.finance.activeFacilities === 1 ? 'y' : 'ies'} (${s.finance.defaulted} in default)`,
    `New loans: ${s.finance.newLoans} (${formatKGD(s.finance.newLoanValue)}) · Scheduled payments collected: ${formatKGD(s.finance.collected)} · missed: ${s.finance.missed}`,
    `AVK: premiums ${formatKGD(s.avk.premiums)}, claims paid ${formatKGD(s.avk.claimsPaid)}, new claims ${s.avk.claimsSubmitted}, active policies ${s.avk.activePolicies}`,
  ];
  const labour = [
    `Registered businesses: ${s.businesses.active} active, ${s.businesses.suspended} suspended (${s.businesses.registered} new, ${s.businesses.closed} closed, ${s.businesses.pending} pending)`,
    `Shifts worked: ${s.labour.shifts} (${s.labour.publicShifts} public sector) · Active citizens (7 days): ${s.labour.activeCitizens}`,
    `Average daily wage: ${s.labour.avgWage === null ? 'n/a' : formatKGD(s.labour.avgWage)}${wageChg !== null ? ` (${formatPct(wageChg)})` : ''}`,
    `Operating costs: licence fees ${formatKGD(s.businesses.licenseFees)}, production costs ${formatKGD(s.businesses.productionCosts)}`,
  ];
  return {
    day: s.day,
    date: s.date,
    late: s.late,
    sections: { national, publicFinance, commodityTable: commodityTable(s), trade, finance, labour },
    developments: developments(s),
    risks,
    opportunities,
    outlook: outlook(s),
  };
}

const clip = (text, max = 1024) => (text.length <= max ? text : `${text.slice(0, max - 2)}…`);

// Plain Discord embed objects (API format). Split into messages that each stay under Discord's
// 6,000 character limit per message.
export function reportToEmbeds(report) {
  const header = {
    title: 'DEMOCRATIC REPUBLIC OF KAGUNDI - NATIONAL ECONOMIC REPORT',
    description: `Economic Day **${report.day}** · ${report.date} · Currency: Kagundi Dinar (KGD)${report.late ? '\n_Processed late after a service interruption._' : ''}`,
    color: 0x1f6f43,
    fields: [
      { name: 'National indicators', value: clip(report.sections.national.join('\n')) },
      { name: 'Public finance', value: clip(report.sections.publicFinance.join('\n')) },
      { name: 'Industry and trade', value: clip(`\`\`\`\n${report.sections.commodityTable}\n\`\`\`\n${report.sections.trade.join('\n')}`) },
    ],
  };
  const second = {
    color: 0x1f6f43,
    fields: [
      { name: 'Financial conditions', value: clip(report.sections.finance.join('\n')) },
      { name: 'Labour and business', value: clip(report.sections.labour.join('\n')) },
      { name: 'Daily developments', value: clip(report.developments.map((d, i) => `${i + 1}. ${d}`).join('\n')) },
      { name: 'Risks', value: clip(report.risks.length ? report.risks.map((r) => `- ${r}`).join('\n') : '- No specific risks identified from current data.') },
      { name: 'Opportunities', value: clip(report.opportunities.length ? report.opportunities.map((r) => `- ${r}`).join('\n') : '- No specific opportunities identified from current data.') },
      { name: 'Economic outlook', value: clip(report.outlook) },
    ],
    footer: { text: 'Issued by: Secretariat for Economy and Education · (est.) = model estimate from recorded activity · All figures are fictional game data.' },
  };
  const size = (e) => (e.title?.length ?? 0) + (e.description?.length ?? 0) + (e.footer?.text?.length ?? 0) + e.fields.reduce((s, f) => s + f.name.length + f.value.length, 0);
  if (size(header) + size(second) <= 5900) return [[header, second]];
  return [[header], [second]];
}

export function reportToMarkdown(report) {
  const lines = [
    '**DEMOCRATIC REPUBLIC OF KAGUNDI**',
    '**NATIONAL ECONOMIC REPORT**',
    '',
    `Economic Day: ${report.day} (${report.date})`,
    'Currency: Kagundi Dinar (KGD)',
    '',
    '**NATIONAL INDICATORS**', ...report.sections.national.map((l) => `- ${l}`), '',
    '**PUBLIC FINANCE**', ...report.sections.publicFinance.map((l) => `- ${l}`), '',
    '**INDUSTRY AND TRADE**', '```', report.sections.commodityTable, '```', ...report.sections.trade.map((l) => `- ${l}`), '',
    '**FINANCIAL CONDITIONS**', ...report.sections.finance.map((l) => `- ${l}`), '',
    '**LABOUR AND BUSINESS**', ...report.sections.labour.map((l) => `- ${l}`), '',
    '**DAILY DEVELOPMENTS**', ...report.developments.map((d, i) => `${i + 1}. ${d}`), '',
    '**RISKS**', ...(report.risks.length ? report.risks : ['No specific risks identified from current data.']).map((l) => `- ${l}`), '',
    '**OPPORTUNITIES**', ...(report.opportunities.length ? report.opportunities : ['No specific opportunities identified from current data.']).map((l) => `- ${l}`), '',
    '**ECONOMIC OUTLOOK**', report.outlook, '',
    'Issued by: **Secretariat for Economy and Education**',
  ];
  return lines.join('\n');
}

// Daily price board for #commodity-markets.
export function marketBoardEmbed(snapshot) {
  const rows = snapshot.trade.commodities.map((c) => {
    const name = `${c.name} (${c.unit})`.padEnd(30);
    const price = c.tradable === 'export' ? (c.price / 100).toFixed(2) : (c.landed / 100).toFixed(2);
    return `${name}${price.padStart(10)} ${formatPct(c.changePct, { digits: 1 }).padStart(7)}  ${c.tradable === 'export' ? 'export' : 'import'}`;
  });
  const partners = Object.entries(snapshot.trade.byPartner).map(([k, v]) => `${PARTNERS[k].name}: demand index ${v.demandIndex.toFixed(3)} (price factor ${(PARTNERS[k].exportPriceFactor * v.demandIndex).toFixed(3)})`);
  return {
    title: `Commodity Markets - prices for Economic Day ${snapshot.day + 1}`,
    color: 0xb8860b,
    description: clip(`\`\`\`\n${'Commodity'.padEnd(30)}${'KGD/unit'.padStart(10)} ${'Chg'.padStart(7)}  Type\n${rows.join('\n')}\n\`\`\`\nExport prices are world prices before partner factors and export duty. Import prices include transport, before tariff.\n${partners.join('\n')}\nExchange rate: ${snapshot.prices.fx.toFixed(3)} KGD per EUR`, 4000),
    footer: { text: 'Use /economy markets for live quotes including duties and tariffs.' },
  };
}
