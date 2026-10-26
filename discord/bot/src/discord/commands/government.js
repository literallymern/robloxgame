// Government and institutional commands: /treasury, /policy, /registry, /credit-office, /avk, /central-bank
// Every command checks the bot permission (see auth.js) at runtime, and every change is written to
// the audit log by the economy layer.
import {
  requestSpending, approveSpending, rejectSpending, pendingSpending, budgetStatus, setBudget, centralBankIssuance, APPROVAL_THRESHOLD,
} from '../../economy/treasury.js';
import { setPolicy, setCommodityPolicy, allPolicy } from '../../economy/policy.js';
import { pendingBusinesses, approveBusiness, rejectBusiness, suspendBusiness, reinstateBusiness, requireBusiness, businessSummary, searchBusinesses } from '../../economy/businesses.js';
import { pendingLoans, approveLoan, rejectLoan, assessLoan } from '../../economy/credit.js';
import { openClaims, decideClaim } from '../../economy/insurance.js';
import { stateInvoices } from '../../economy/invoices.js';
import { setPublicWage, stateJobs } from '../../economy/employment.js';
import { personalAccountId, getCitizen } from '../../economy/citizens.js';
import { businessAccountId } from '../../economy/payments.js';
import { moneyStock } from '../../economy/indicators.js';
import { marketStateFor } from '../../economy/market.js';
import { getAccount, systemAccountId } from '../../economy/ledger.js';
import { AVK_PRODUCTS, BUDGET_CATEGORIES, COMMODITIES, INDUSTRIES } from '../../economy/constants.js';
import { formatKGD, bpToPct, toMinor } from '../../economy/money.js';
import { UserError, PermissionError } from '../../economy/errors.js';
import { requirePermission, isOwner } from '../auth.js';
import { embed, reply, user, lines, COLORS } from '../format.js';
import { command, notMaintenance, amountOption, amountOrZero, idOption, autocompleteAnyBusiness, budgetChoices, commodityChoices } from './common.js';

const reasonOpt = (required = true) => (o) => o.setName('reason').setDescription('Reason (recorded in the audit log)').setRequired(required).setMaxLength(300);

// ---------------------------------------------------------------- /treasury
const treasury = {
  data: command('treasury', 'Government: public spending and budgets')
    .addSubcommand((s) => s.setName('spend').setDescription(`Pay public money (above ${formatKGD(APPROVAL_THRESHOLD)} a second official must approve)`)
      .addNumberOption((o) => o.setName('amount').setDescription('Amount in KGD').setRequired(true).setMinValue(0.01))
      .addStringOption((o) => o.setName('category').setDescription('Budget line').setRequired(true).addChoices(...budgetChoices()))
      .addStringOption(reasonOpt())
      .addUserOption((o) => o.setName('to_user').setDescription('Recipient (person)'))
      .addStringOption((o) => o.setName('to_business').setDescription('Recipient (business)').setAutocomplete(true)))
    .addSubcommand((s) => s.setName('pay-invoice').setDescription('Pay an invoice addressed to the state')
      .addStringOption((o) => o.setName('invoice').setDescription('Invoice').setRequired(true).setAutocomplete(true))
      .addStringOption((o) => o.setName('category').setDescription('Budget line').setRequired(true).addChoices(...budgetChoices()))
      .addStringOption(reasonOpt()))
    .addSubcommand((s) => s.setName('pending').setDescription('Spending requests waiting for a second approval'))
    .addSubcommand((s) => s.setName('approve').setDescription('Approve another official\'s spending request')
      .addStringOption((o) => o.setName('request').setDescription('Request').setRequired(true).setAutocomplete(true)))
    .addSubcommand((s) => s.setName('reject').setDescription('Reject a spending request')
      .addStringOption((o) => o.setName('request').setDescription('Request').setRequired(true).setAutocomplete(true))
      .addStringOption(reasonOpt()))
    .addSubcommand((s) => s.setName('budget').setDescription('Budget lines of the current 30-day period'))
    .addSubcommand((s) => s.setName('budget-set').setDescription('Set a budget line for the current period')
      .addStringOption((o) => o.setName('category').setDescription('Budget line').setRequired(true).addChoices(...budgetChoices()))
      .addNumberOption((o) => o.setName('amount').setDescription('Allocated amount in KGD for discretionary spending').setRequired(true).setMinValue(0))
      .addStringOption(reasonOpt()))
    .addSubcommand((s) => s.setName('wage').setDescription('Change a public-sector daily wage')
      .addStringOption((o) => o.setName('department').setDescription('Position').setRequired(true).setAutocomplete(true))
      .addNumberOption((o) => o.setName('wage').setDescription('Daily wage in KGD').setRequired(true).setMinValue(1))
      .addStringOption(reasonOpt())),
  async autocomplete(ctx, interaction) {
    const focused = interaction.options.getFocused(true);
    if (focused.name === 'to_business') return autocompleteAnyBusiness(ctx, interaction);
    if (focused.name === 'invoice') {
      return stateInvoices(ctx.eco).slice(0, 25).map((i) => ({ name: `#${i.id} ${formatKGD(i.amount)} - ${i.memo}`.slice(0, 100), value: String(i.id) }));
    }
    if (focused.name === 'request') {
      return pendingSpending(ctx.eco).slice(0, 25).map((r) => ({ name: `#${r.id} ${formatKGD(r.amount)} to ${r.payee_name} (${r.category})`.slice(0, 100), value: String(r.id) }));
    }
    if (focused.name === 'department') {
      const text = String(focused.value ?? '').toLowerCase();
      return stateJobs(ctx.eco).filter((j) => j.title.toLowerCase().includes(text)).slice(0, 25)
        .map((j) => ({ name: `${j.title} - now ${formatKGD(j.daily_wage)}/day`.slice(0, 100), value: j.department }));
    }
    return [];
  },
  async execute(ctx, interaction) {
    const eco = ctx.eco;
    const sub = interaction.options.getSubcommand();
    const me = interaction.user.id;
    if (sub === 'pending' || sub === 'budget') {
      requirePermission(ctx, interaction, 'treasury.view');
      if (sub === 'pending') {
        const rows = pendingSpending(eco).map((r) => `\`#${r.id}\` ${formatKGD(r.amount)} to ${r.payee_name} · ${BUDGET_CATEGORIES[r.category]} · requested by ${user(r.requested_by)} on day ${r.created_day}\n> ${r.reason}`);
        return reply(interaction, { embeds: [embed({ title: 'Pending spending requests', color: COLORS.gov, description: lines(rows, 'None.'), footer: 'A request cannot be approved by the official who made it.' })] });
      }
      const b = budgetStatus(eco);
      const rows = Object.entries(b.lines).map(([k, l]) => `**${BUDGET_CATEGORIES[k]}**: ${l.allocated === null ? 'no budget set' : `${formatKGD(l.allocated)} allocated, ${formatKGD(l.discretionary)} spent, ${formatKGD(Math.max(0, l.allocated - l.discretionary))} left`} · wages paid ${formatKGD(l.wages)}`);
      return reply(interaction, { embeds: [embed({ title: `Budget period ${b.period} (economic days ${b.first}-${b.last})`, color: COLORS.gov, description: rows.join('\n'),
        footer: `Treasury balance ${formatKGD(getAccount(eco, systemAccountId(eco, 'treasury')).balance)}. Public wages are paid automatically and are not limited by budget lines.` })] });
    }
    notMaintenance(ctx, interaction);
    if (sub === 'spend') {
      requirePermission(ctx, interaction, 'treasury.spend');
      const toUser = interaction.options.getUser('to_user');
      const toBusiness = interaction.options.getString('to_business');
      if (!!toUser === !!toBusiness) throw new UserError('Choose exactly one recipient: to_user or to_business.');
      if (toUser?.bot) throw new UserError('Public money cannot be paid to a bot.');
      if (toUser && toUser.id === me) throw new PermissionError('You cannot pay public money to yourself.');
      const payeeAccount = toUser ? personalAccountId(eco, toUser.id, 'bank') : businessAccountId(eco, idOption(interaction, 'to_business'));
      if (toBusiness && requireBusiness(eco, idOption(interaction, 'to_business')).owner_id === me) throw new PermissionError('You cannot pay public money to your own business.');
      const amount = amountOption(interaction);
      const r = requestSpending(eco, { actor: me, payeeAccount, amount, category: interaction.options.getString('category'), reason: interaction.options.getString('reason') });
      if (r.status === 'pending') {
        await ctx.notify?.('economic_administration', `Spending request #${r.id} (${formatKGD(amount)}) needs a second approval: \`/treasury approve\`.`);
        return reply(interaction, `Spending request #${r.id} for ${formatKGD(amount)} created. It is above ${formatKGD(APPROVAL_THRESHOLD)}, so another authorised official must approve it.`);
      }
      return reply(interaction, `Paid ${formatKGD(amount)} from the treasury (request #${r.id}).`);
    }
    if (sub === 'pay-invoice') {
      requirePermission(ctx, interaction, 'treasury.spend');
      const r = requestSpending(eco, { actor: me, invoiceId: idOption(interaction, 'invoice'), category: interaction.options.getString('category'), reason: interaction.options.getString('reason') });
      if (r.status === 'pending') {
        await ctx.notify?.('economic_administration', `Payment of state invoice (request #${r.id}, ${formatKGD(r.amount)}) needs a second approval: \`/treasury approve\`.`);
        return reply(interaction, `Payment request #${r.id} created. Above ${formatKGD(APPROVAL_THRESHOLD)} another official must approve it.`);
      }
      return reply(interaction, `Invoice paid: ${formatKGD(r.amount)} (request #${r.id}).`);
    }
    if (sub === 'approve') {
      requirePermission(ctx, interaction, 'treasury.approve');
      const req = approveSpending(eco, { id: idOption(interaction, 'request'), actor: me });
      return reply(interaction, `Spending request #${req.id} approved and paid: ${formatKGD(req.amount)}.`);
    }
    if (sub === 'reject') {
      requirePermission(ctx, interaction, 'treasury.approve');
      const req = rejectSpending(eco, { id: idOption(interaction, 'request'), actor: me, reason: interaction.options.getString('reason') });
      return reply(interaction, `Spending request #${req.id} rejected.`);
    }
    if (sub === 'budget-set') {
      requirePermission(ctx, interaction, 'treasury.budget');
      const amount = amountOrZero(interaction, 'amount');
      const r = setBudget(eco, { actor: me, category: interaction.options.getString('category'), amount, reason: interaction.options.getString('reason') });
      await ctx.notify?.('economic_announcements', `The budget line **${BUDGET_CATEGORIES[r.category]}** for budget period ${r.period} was set to ${formatKGD(amount)}.`);
      return reply(interaction, `Budget for ${BUDGET_CATEGORIES[r.category]} in period ${r.period} set to ${formatKGD(amount)}.`);
    }
    if (sub === 'wage') {
      requirePermission(ctx, interaction, 'treasury.wages');
      const r = setPublicWage(eco, { department: interaction.options.getString('department'), wage: amountOption(interaction, 'wage'), actor: me, reason: interaction.options.getString('reason') });
      await ctx.notify?.('economic_announcements', `Public-sector wage change: **${r.job.title}** now earns ${formatKGD(r.wage)} per day (before: ${formatKGD(r.old)}).`);
      return reply(interaction, `Wage of ${r.job.title} changed from ${formatKGD(r.old)} to ${formatKGD(r.wage)} per day.`);
    }
    throw new UserError('Unknown subcommand.');
  },
};

// ---------------------------------------------------------------- /policy
// unit 'pct' = entered in percent, stored in basis points; 'kgd' = entered in KGD, stored in minor units.
const POLICY_FIELDS = {
  policy_rate_bp: { label: 'Central bank policy rate', unit: 'pct' },
  income_tax_bp: { label: 'Income tax (withheld from wages)', unit: 'pct' },
  turnover_tax_bp: { label: 'Turnover tax on business income', unit: 'pct' },
  distribution_tax_bp: { label: 'Distribution tax on profit withdrawals', unit: 'pct' },
  property_tax_annual_bp: { label: 'Property tax per year', unit: 'pct' },
  property_transfer_tax_bp: { label: 'Property transfer tax', unit: 'pct' },
  registration_fee: { label: 'Business registration fee', unit: 'kgd' },
  min_wage_daily: { label: 'Minimum daily wage (private sector)', unit: 'kgd' },
  max_private_wage_daily: { label: 'Maximum daily wage (private sector)', unit: 'kgd' },
  starting_grant: { label: 'Starting balance for new citizens', unit: 'kgd' },
};

function toStored(unit, value) {
  if (unit === 'pct') {
    const bp = Math.round(value * 100);
    if (Math.abs(bp - value * 100) > 1e-6) throw new UserError('Percentages can have at most two decimals.');
    return bp;
  }
  const minor = toMinor(value);
  if (minor < 0) throw new UserError('The value cannot be negative.');
  return minor;
}

const showValue = (unit, v) => (unit === 'pct' ? bpToPct(v) : formatKGD(v));

const policy = {
  data: command('policy', 'Government: taxes, fees, tariffs and the policy rate')
    .addSubcommand((s) => s.setName('show').setDescription('Current economic policy'))
    .addSubcommand((s) => s.setName('set').setDescription('Change a tax rate, fee or the policy rate (within fixed limits)')
      .addStringOption((o) => o.setName('setting').setDescription('Setting').setRequired(true).addChoices(...Object.entries(POLICY_FIELDS).map(([value, f]) => ({ name: f.label, value }))))
      .addNumberOption((o) => o.setName('value').setDescription('New value: percent (e.g. 7.5) or KGD amount').setRequired(true).setMinValue(0))
      .addStringOption(reasonOpt()))
    .addSubcommand((s) => s.setName('tariff').setDescription('Import tariff on a commodity')
      .addStringOption((o) => o.setName('commodity').setDescription('Import commodity').setRequired(true).addChoices(...commodityChoices((c) => c.tradable === 'import')))
      .addNumberOption((o) => o.setName('percent').setDescription('Tariff in percent').setRequired(true).setMinValue(0).setMaxValue(50))
      .addStringOption(reasonOpt()))
    .addSubcommand((s) => s.setName('export-duty').setDescription('Export duty on a commodity')
      .addStringOption((o) => o.setName('commodity').setDescription('Export commodity').setRequired(true).addChoices(...commodityChoices((c) => c.tradable === 'export')))
      .addNumberOption((o) => o.setName('percent').setDescription('Duty in percent').setRequired(true).setMinValue(0).setMaxValue(40))
      .addStringOption(reasonOpt()))
    .addSubcommand((s) => s.setName('export-ban').setDescription('Ban or allow exports of a commodity')
      .addStringOption((o) => o.setName('commodity').setDescription('Export commodity').setRequired(true).addChoices(...commodityChoices((c) => c.tradable === 'export')))
      .addBooleanOption((o) => o.setName('banned').setDescription('true = ban exports, false = allow').setRequired(true))
      .addStringOption(reasonOpt())),
  async execute(ctx, interaction) {
    const eco = ctx.eco;
    const sub = interaction.options.getSubcommand();
    const me = interaction.user.id;
    if (sub === 'show') {
      const p = allPolicy(eco);
      const rows = Object.entries(POLICY_FIELDS).map(([k, f]) => `${f.label}: **${showValue(f.unit, p[k])}**`);
      const tariffs = Object.entries(p.import_tariff_bp).map(([c, v]) => `${COMMODITIES[c].name} ${bpToPct(v)}`).join(' · ');
      const duties = Object.entries(p.export_duty_bp).map(([c, v]) => `${COMMODITIES[c].name} ${bpToPct(v)}`).join(' · ');
      const bans = Object.keys(p.export_ban).map((c) => COMMODITIES[c].name).join(', ') || 'none';
      return reply(interaction, { embeds: [embed({ title: 'Economic policy of Kagundi', color: COLORS.gov, description: rows.join('\n'), fields: [
        { name: 'Import tariffs', value: tariffs }, { name: 'Export duties', value: duties }, { name: 'Export bans', value: bans },
      ] })] });
    }
    requirePermission(ctx, interaction, 'policy.set');
    notMaintenance(ctx, interaction);
    const reason = interaction.options.getString('reason');
    let text;
    if (sub === 'set') {
      const key = interaction.options.getString('setting');
      const f = POLICY_FIELDS[key];
      const r = setPolicy(eco, { key, value: toStored(f.unit, interaction.options.getNumber('value')), actor: me, reason });
      text = `${f.label}: ${showValue(f.unit, r.old)} → **${showValue(f.unit, r.value)}**`;
    } else if (sub === 'tariff' || sub === 'export-duty') {
      const key = sub === 'tariff' ? 'import_tariff_bp' : 'export_duty_bp';
      const commodity = interaction.options.getString('commodity');
      const r = setCommodityPolicy(eco, { key, commodity, value: toStored('pct', interaction.options.getNumber('percent')), actor: me, reason });
      text = `${sub === 'tariff' ? 'Import tariff' : 'Export duty'} on ${COMMODITIES[commodity].name}: ${bpToPct(r.old)} → **${bpToPct(r.value)}**`;
    } else if (sub === 'export-ban') {
      const commodity = interaction.options.getString('commodity');
      const banned = interaction.options.getBoolean('banned');
      setCommodityPolicy(eco, { key: 'export_ban', commodity, value: banned, actor: me, reason });
      text = `Exports of ${COMMODITIES[commodity].name} are now **${banned ? 'banned' : 'allowed'}**`;
    } else {
      throw new UserError('Unknown subcommand.');
    }
    await ctx.notify?.('economic_announcements', `**Policy change** by the Secretariat for Economy and Education: ${text}. Reason: ${reason}`);
    return reply(interaction, `${text}. The change applies from now on and is published in #economic-announcements.`);
  },
};

// ---------------------------------------------------------------- /registry
const registry = {
  data: command('registry', 'Business registry: review registrations')
    .addSubcommand((s) => s.setName('pending').setDescription('Applications waiting for a decision'))
    .addSubcommand((s) => s.setName('approve').setDescription('Approve a registration (the fee is charged now)')
      .addStringOption((o) => o.setName('business').setDescription('Application').setRequired(true).setAutocomplete(true))
      .addNumberOption((o) => o.setName('state_share').setDescription('State ownership share in percent (default 0)').setMinValue(0).setMaxValue(100))
      .addStringOption(reasonOpt(false)))
    .addSubcommand((s) => s.setName('reject').setDescription('Reject a registration')
      .addStringOption((o) => o.setName('business').setDescription('Application').setRequired(true).setAutocomplete(true))
      .addStringOption(reasonOpt()))
    .addSubcommand((s) => s.setName('suspend').setDescription('Suspend an active business')
      .addStringOption((o) => o.setName('business').setDescription('Business').setRequired(true).setAutocomplete(true))
      .addStringOption(reasonOpt()))
    .addSubcommand((s) => s.setName('reinstate').setDescription('Lift a suspension')
      .addStringOption((o) => o.setName('business').setDescription('Business').setRequired(true).setAutocomplete(true))
      .addStringOption(reasonOpt()))
    .addSubcommand((s) => s.setName('inspect').setDescription('Registry record of a business')
      .addStringOption((o) => o.setName('business').setDescription('Business').setRequired(true).setAutocomplete(true))),
  async autocomplete(ctx, interaction) {
    const sub = interaction.options.getSubcommand();
    const text = String(interaction.options.getFocused() ?? '');
    if (sub === 'approve' || sub === 'reject') {
      return pendingBusinesses(ctx.eco).filter((b) => b.name.toLowerCase().includes(text.toLowerCase())).slice(0, 25)
        .map((b) => ({ name: `#${b.id} ${b.name} (${INDUSTRIES[b.industry].name})`.slice(0, 100), value: String(b.id) }));
    }
    return searchBusinesses(ctx.eco, text).map((b) => ({ name: `#${b.id} ${b.name}`.slice(0, 100), value: String(b.id) }));
  },
  async execute(ctx, interaction) {
    const eco = ctx.eco;
    const sub = interaction.options.getSubcommand();
    const me = interaction.user.id;
    requirePermission(ctx, interaction, 'registry.review');
    if (sub === 'pending') {
      const rows = pendingBusinesses(eco).map((b) => `\`#${b.id}\` **${b.name}** - ${INDUSTRIES[b.industry].name}${b.primary_output ? ` (${COMMODITIES[b.primary_output].name})` : ''} · owner ${user(b.owner_id)} · applied day ${b.applied_day}${b.description ? `\n> ${b.description.slice(0, 200)}` : ''}`);
      return reply(interaction, { embeds: [embed({ title: 'Business registry: pending applications', color: COLORS.gov, description: lines(rows, 'No pending applications.'), footer: 'You cannot approve your own application.' })] });
    }
    const id = idOption(interaction, 'business');
    if (sub === 'inspect') {
      const s = businessSummary(eco, id);
      const b = s.business;
      return reply(interaction, { embeds: [embed({ title: `Registry record: ${b.name} (#${b.id})`, color: COLORS.gov, fields: [
        { name: 'Status', value: `${b.status}${b.suspended_reason ? ` (${b.suspended_reason})` : ''}`, inline: true },
        { name: 'Owner', value: user(b.owner_id), inline: true },
        { name: 'Industry', value: INDUSTRIES[b.industry].name, inline: true },
        { name: 'State share', value: bpToPct(b.state_share_bp ?? 0), inline: true },
        { name: 'Employees', value: String(s.employees.length), inline: true },
        { name: 'Licence arrears', value: formatKGD(b.license_arrears ?? 0), inline: true },
        { name: 'Decision', value: b.decision_reason ? `${b.decision_reason} (day ${b.decided_day}, by ${user(b.decided_by)})` : 'none' },
      ], footer: 'Account balances are private. Economic staff can inspect them with /econ-admin inspect.' })] });
    }
    notMaintenance(ctx, interaction);
    const reason = interaction.options.getString('reason');
    if (sub === 'approve') {
      const share = interaction.options.getNumber('state_share') ?? 0;
      const b = approveBusiness(eco, { id, actor: me, reason: reason ?? 'Approved', stateShareBp: Math.round(share * 100) });
      ctx.syncRoles?.([b.owner_id]);
      await ctx.dm?.(b.owner_id, `Your business **${b.name}** was approved by the business registry of Kagundi. The registration fee of ${formatKGD(b.fee)} was charged. Start with /business status.`);
      return reply(interaction, `**${b.name}** approved${share ? ` with a ${share}% state share` : ''}. Fee charged: ${formatKGD(b.fee)}.`);
    }
    if (sub === 'reject') {
      const b = rejectBusiness(eco, { id, actor: me, reason });
      await ctx.dm?.(b.owner_id, `Your business application **${b.name}** was rejected by the business registry. Reason: ${reason}. No fee was charged.`);
      return reply(interaction, `Application **${b.name}** rejected.`);
    }
    if (sub === 'suspend') {
      const b = suspendBusiness(eco, { id, actor: me, reason });
      await ctx.dm?.(b.owner_id, `Your business **${b.name}** was suspended by the business registry. Reason: ${reason}. While suspended it cannot trade, hire or produce.`);
      return reply(interaction, `**${b.name}** suspended.`);
    }
    if (sub === 'reinstate') {
      const b = reinstateBusiness(eco, { id, actor: me, reason });
      await ctx.dm?.(b.owner_id, `The suspension of your business **${b.name}** was lifted.`);
      return reply(interaction, `**${b.name}** reinstated.`);
    }
    throw new UserError('Unknown subcommand.');
  },
};

// ---------------------------------------------------------------- /credit-office
const creditOffice = {
  data: command('credit-office', 'Credit officers: review loan applications')
    .addSubcommand((s) => s.setName('pending').setDescription('Loan applications waiting for a decision'))
    .addSubcommand((s) => s.setName('approve').setDescription('Approve a loan (all lending rules are checked again)')
      .addStringOption((o) => o.setName('loan').setDescription('Application').setRequired(true).setAutocomplete(true))
      .addStringOption(reasonOpt()))
    .addSubcommand((s) => s.setName('reject').setDescription('Reject a loan application')
      .addStringOption((o) => o.setName('loan').setDescription('Application').setRequired(true).setAutocomplete(true))
      .addStringOption(reasonOpt())),
  async autocomplete(ctx, interaction) {
    return pendingLoans(ctx.eco).slice(0, 25).map((f) => ({ name: `#${f.id} ${formatKGD(f.principal)} over ${f.term_weeks} weeks`, value: String(f.id) }));
  },
  async execute(ctx, interaction) {
    const eco = ctx.eco;
    const sub = interaction.options.getSubcommand();
    const me = interaction.user.id;
    requirePermission(ctx, interaction, 'credit.review');
    if (sub === 'pending') {
      const rows = pendingLoans(eco).map((f) => {
        const a = assessLoan(eco, { borrowerType: f.borrower_type, borrowerId: f.borrower_id, scoreUserId: f.applicant_id, amount: f.principal, weeks: f.term_weeks });
        const name = getCitizen(eco, f.applicant_id)?.display_name ?? f.applicant_id;
        return `\`#${f.id}\` ${formatKGD(f.principal)} over ${f.term_weeks} weeks · ${f.borrower_type === 'business' ? `business #${f.borrower_id} of ` : ''}${name}`
          + ` · score ${a.score} · installment ${formatKGD(a.installment)} · ${a.ok ? 'meets all rules' : `**fails now:** ${a.reasons.join(' ')}`}${f.purpose ? `\n> ${f.purpose}` : ''}`;
      });
      return reply(interaction, { embeds: [embed({ title: 'Loan applications', description: lines(rows, 'None.'), footer: 'Approval re-checks every rule. You cannot approve your own application.' })] });
    }
    notMaintenance(ctx, interaction);
    const id = idOption(interaction, 'loan');
    const reason = interaction.options.getString('reason');
    if (sub === 'approve') {
      const f = approveLoan(eco, { id, actor: me, reason });
      await ctx.dm?.(f.applicant_id, `Your loan #${f.id} over ${formatKGD(f.principal)} was approved and paid out. Weekly installment: ${formatKGD(f.installment)}.`);
      return reply(interaction, `Loan #${f.id} approved and paid out.`);
    }
    if (sub === 'reject') {
      const f = rejectLoan(eco, { id, actor: me, reason });
      await ctx.dm?.(f.applicant_id, `Your loan application #${f.id} was not approved. Reason: ${reason}`);
      return reply(interaction, `Loan application #${f.id} rejected.`);
    }
    throw new UserError('Unknown subcommand.');
  },
};

// ---------------------------------------------------------------- /avk
const avk = {
  data: command('avk', 'AVK officers: review insurance claims')
    .addSubcommand((s) => s.setName('claims').setDescription('Open claims'))
    .addSubcommand((s) => s.setName('approve').setDescription('Approve and pay a claim')
      .addStringOption((o) => o.setName('claim').setDescription('Claim').setRequired(true).setAutocomplete(true))
      .addStringOption(reasonOpt())
      .addNumberOption((o) => o.setName('payout').setDescription('Payout in KGD (default: maximum allowed)').setMinValue(0.01)))
    .addSubcommand((s) => s.setName('deny').setDescription('Deny a claim')
      .addStringOption((o) => o.setName('claim').setDescription('Claim').setRequired(true).setAutocomplete(true))
      .addStringOption(reasonOpt())),
  async autocomplete(ctx, interaction) {
    return openClaims(ctx.eco).slice(0, 25).map((c) => ({ name: `#${c.id} ${formatKGD(c.amount_claimed)} - ${AVK_PRODUCTS[c.product]?.name ?? c.product} (${c.incident_ref})`.slice(0, 100), value: String(c.id) }));
  },
  async execute(ctx, interaction) {
    const eco = ctx.eco;
    const sub = interaction.options.getSubcommand();
    const me = interaction.user.id;
    requirePermission(ctx, interaction, 'avk.review');
    if (sub === 'claims') {
      const rows = openClaims(eco).map((c) => {
        const max = Math.max(0, Math.min(c.amount_claimed, c.coverage_limit - c.paid_out_total) - c.deductible);
        const earlier = eco.db.prepare('SELECT COUNT(*) AS n FROM insurance_claims WHERE claimant_id = ? AND id <> ?').get(c.claimant_id, c.id).n;
        return `\`#${c.id}\` ${AVK_PRODUCTS[c.product]?.name ?? c.product} · claimed ${formatKGD(c.amount_claimed)} · max payout ${formatKGD(max)} · incident **${c.incident_ref}** · claimant ${user(c.claimant_id)} (${earlier} earlier claim(s)) · day ${c.created_day}\n> ${c.description.slice(0, 200)}\n> Evidence: ${c.evidence.slice(0, 150)}`;
      });
      return reply(interaction, { embeds: [embed({ title: 'Open AVK claims', color: COLORS.avk, description: lines(rows, 'No open claims.'),
        footer: 'Check the incident reference with the police, Brandwehr or EMS report. You cannot decide claims on your own policies.' })] });
    }
    notMaintenance(ctx, interaction);
    const claimId = idOption(interaction, 'claim');
    const reason = interaction.options.getString('reason');
    const r = decideClaim(eco, { claimId, actor: me, approve: sub === 'approve', payout: sub === 'approve' ? amountOption(interaction, 'payout', { required: false }) : null, reason });
    if (r.status === 'paid') {
      await ctx.dm?.(r.claim.claimant_id, `AVK paid ${formatKGD(r.payout)} on your claim #${claimId}.`);
      return reply(interaction, `Claim #${claimId} paid: ${formatKGD(r.payout)}.`);
    }
    await ctx.dm?.(r.claim.claimant_id, `AVK denied your claim #${claimId}. Reason: ${reason}`);
    return reply(interaction, `Claim #${claimId} denied.`);
  },
};

// ---------------------------------------------------------------- /central-bank
const centralBank = {
  data: command('central-bank', 'Central Bank of Kagundi')
    .addSubcommand((s) => s.setName('status').setDescription('Policy rate, money supply and exchange rate'))
    .addSubcommand((s) => s.setName('finance-treasury').setDescription('Owner only: emergency money creation for the treasury (raises inflation)')
      .addNumberOption((o) => o.setName('amount').setDescription('Amount in KGD').setRequired(true).setMinValue(1))
      .addStringOption((o) => o.setName('reason').setDescription('Detailed reason').setRequired(true).setMinLength(10).setMaxLength(300))),
  async execute(ctx, interaction) {
    const eco = ctx.eco;
    const sub = interaction.options.getSubcommand();
    if (sub === 'status') {
      const m = moneyStock(eco);
      const st = marketStateFor(eco);
      const p = allPolicy(eco);
      return reply(interaction, { embeds: [embed({ title: 'Central Bank of Kagundi', color: COLORS.gov, fields: [
        { name: 'Policy rate', value: bpToPct(p.policy_rate_bp), inline: true },
        { name: 'Exchange rate', value: `${st.fx.toFixed(3)} KGD per EUR`, inline: true },
        { name: 'Consumer price index', value: Number(st.cpi).toFixed(2), inline: true },
        { name: 'Money supply', value: formatKGD(m.total), inline: true },
        { name: 'held privately', value: formatKGD(m.private), inline: true },
        { name: 'held by the state', value: formatKGD(m.public), inline: true },
      ], footer: 'The policy rate is set by the Secretariat for Economy and Education with /policy set.' })] });
    }
    if (!isOwner(ctx, interaction.user.id, interaction.member)) throw new PermissionError('Only the Owner can authorise money creation.');
    const amount = amountOption(interaction);
    const txId = centralBankIssuance(eco, { actor: interaction.user.id, amount, reason: interaction.options.getString('reason') });
    await ctx.notify?.('economic_announcements', `The Central Bank has financed the treasury with ${formatKGD(amount)} of newly created money.`);
    return reply(interaction, `Treasury financed with ${formatKGD(amount)} (transaction #${txId}). This increases the money supply and is reflected in the next report.`);
  },
};

export default [treasury, policy, registry, creditOffice, avk, centralBank];
