// Player commands: /economy, /bank, /work, /jobs
import { personalAccounts, getCitizen } from '../../economy/citizens.js';
import { citizenPay, withdrawCash, depositCash, accountTransactions } from '../../economy/payments.js';
import { computeCreditScore, creditBand, lendingRateBp, facilitiesForUser, verifiedMonthlyIncome, monthlyDebtObligations } from '../../economy/credit.js';
import { clockIn, eligibleJobs, openJobs, stateJobs, applyForJob, myEmployments, quitJob, recentShifts } from '../../economy/employment.js';
import { latestReport, getReport } from '../../economy/tick.js';
import { reportToEmbeds } from '../../economy/report.js';
import { exportQuote, importQuote, marketStateFor } from '../../economy/market.js';
import { getPolicy } from '../../economy/policy.js';
import { treasuryFlows, budgetStatus, pendingSpending } from '../../economy/treasury.js';
import { getSnapshot } from '../../economy/indicators.js';
import { COMMODITIES, PARTNERS, BUDGET_CATEGORIES } from '../../economy/constants.js';
import { formatKGD, bpToPct, applyBp } from '../../economy/money.js';
import { UserError } from '../../economy/errors.js';
import { memberRoleKeys, can } from '../auth.js';
import { embed, reply, user, lines, COLORS } from '../format.js';
import { command, citizen, notMaintenance, amountOption, idOption, autocompleteAnyBusiness } from './common.js';

const economy = {
  data: command('economy', 'National economy of Kagundi')
    .addSubcommand((s) => s.setName('overview').setDescription('Latest national economic overview'))
    .addSubcommand((s) => s.setName('markets').setDescription('Current commodity prices with duties and tariffs'))
    .addSubcommand((s) => s.setName('history').setDescription('Earlier economic reports')
      .addIntegerOption((o) => o.setName('day').setDescription('Economic day number (leave empty for a list)').setMinValue(1)))
    .addSubcommand((s) => s.setName('treasury').setDescription('Public finances')),
  async execute(ctx, interaction) {
    const sub = interaction.options.getSubcommand();
    const eco = ctx.eco;
    if (sub === 'overview') {
      const r = latestReport(eco);
      if (!r) return reply(interaction, `No report yet. The first National Economic Report is published after economic day ${eco.currentDay()} ends (00:00 ${eco.clock.timeZone}).`);
      return reply(interaction, { embeds: [embed({ title: `National overview - Economic Day ${r.day}`, color: COLORS.econ,
        description: r.content.sections.national.join('\n'),
        fields: [{ name: 'Daily developments', value: r.content.developments.map((d, i) => `${i + 1}. ${d}`).join('\n') }, { name: 'Outlook', value: r.content.outlook }],
        footer: 'Full report: #national-economic-report · (est.) = model estimate' })] });
    }
    if (sub === 'markets') {
      const day = eco.currentDay();
      const duties = getPolicy(eco, 'export_duty_bp');
      const tariffs = getPolicy(eco, 'import_tariff_bp');
      const bans = getPolicy(eco, 'export_ban');
      const rows = Object.values(COMMODITIES).map((c) => {
        if (c.tradable === 'export') {
          const quotes = Object.keys(PARTNERS).map((p) => `${PARTNERS[p].name.split(' ')[0]} ${(exportQuote(eco, c.key, p, day) / 100).toFixed(2)}`).join(' | ');
          return `**${c.name}** (per ${c.unit}) - sell: ${quotes} · duty ${bpToPct(duties[c.key] ?? 0)}${bans[c.key] ? ' · **EXPORT BAN**' : ''}`;
        }
        const quotes = Object.keys(PARTNERS).map((p) => `${PARTNERS[p].name.split(' ')[0]} ${(importQuote(eco, c.key, p, day) / 100).toFixed(2)}`).join(' | ');
        return `**${c.name}** (per ${c.unit}) - buy: ${quotes} · tariff ${bpToPct(tariffs[c.key] ?? 0)}`;
      });
      const st = marketStateFor(eco, day);
      return reply(interaction, { embeds: [embed({ title: `Commodity markets - Economic Day ${day}`, color: COLORS.econ, description: rows.join('\n'),
        footer: `Prices in KGD. Exchange rate ${st.fx.toFixed(3)} KGD/EUR. Businesses trade with /business market.` })] });
    }
    if (sub === 'history') {
      const day = interaction.options.getInteger('day');
      if (day) {
        const r = getReport(eco, day);
        if (!r) throw new UserError('No report exists for that day.');
        const groups = reportToEmbeds(r.content);
        await reply(interaction, { embeds: groups[0] });
        for (const g of groups.slice(1)) await reply(interaction, { embeds: g });
        return;
      }
      const rows = eco.db.prepare('SELECT day FROM reports ORDER BY day DESC LIMIT 10').all().map((r) => {
        const s = getSnapshot(eco, r.day);
        return `Day ${r.day} (${s.date}): GDP (est.) ${formatKGD(s.gdp.estimate)} · treasury ${formatKGD(s.treasury.balance)} · CPI ${s.prices.cpi.toFixed(2)}`;
      });
      return reply(interaction, { embeds: [embed({ title: 'Recent economic reports', description: lines(rows, 'No reports yet.'), footer: 'Show one report with /economy history day:<number>' })] });
    }
    if (sub === 'treasury') {
      const today = eco.currentDay();
      const yesterday = treasuryFlows(eco, Math.max(1, today - 1));
      const fields = [
        { name: 'Balance', value: formatKGD(yesterday.balance), inline: true },
        { name: `Day ${Math.max(1, today - 1)} revenue`, value: formatKGD(yesterday.totalRevenue), inline: true },
        { name: `Day ${Math.max(1, today - 1)} expenditure`, value: formatKGD(yesterday.totalExpenditure), inline: true },
      ];
      if (can(ctx, interaction, 'treasury.view')) {
        const week = treasuryFlows(eco, Math.max(1, today - 7), today);
        const fmt = (obj) => Object.entries(obj).map(([k, v]) => `${k}: ${formatKGD(v)}`).join('\n') || 'none';
        const budget = budgetStatus(eco);
        const budgetLines = Object.entries(budget.lines).filter(([, l]) => l.allocated !== null || l.wages || l.discretionary)
          .map(([k, l]) => `${BUDGET_CATEGORIES[k]}: allocated ${l.allocated === null ? 'none' : formatKGD(l.allocated)}, spent ${formatKGD(l.discretionary)} + wages ${formatKGD(l.wages)}`);
        fields.push({ name: 'Revenue, last 7 days', value: fmt(week.revenue) });
        fields.push({ name: 'Expenditure, last 7 days', value: fmt(week.expenditure) });
        fields.push({ name: `Budget period ${budget.period} (days ${budget.first}-${budget.last})`, value: lines(budgetLines, 'No budget lines set.') });
        fields.push({ name: 'Pending spending requests', value: lines(pendingSpending(eco).map((r) => `#${r.id} ${formatKGD(r.amount)} to ${r.payee_name} (${r.category})`), 'none') });
      }
      return reply(interaction, { embeds: [embed({ title: 'National Treasury', color: COLORS.gov, fields })] });
    }
  },
};

const bank = {
  data: command('bank', 'Your personal bank account')
    .addSubcommand((s) => s.setName('balance').setDescription('Show your balances (opens an account on first use)'))
    .addSubcommand((s) => s.setName('transactions').setDescription('Your recent transactions')
      .addStringOption((o) => o.setName('account').setDescription('Which account').addChoices({ name: 'Bank', value: 'personal_bank' }, { name: 'Cash', value: 'personal_cash' }, { name: 'Credit card', value: 'credit_card' }))
      .addIntegerOption((o) => o.setName('page').setDescription('Page').setMinValue(1).setMaxValue(50)))
    .addSubcommand((s) => s.setName('pay').setDescription('Pay a person or a business')
      .addNumberOption((o) => o.setName('amount').setDescription('Amount in KGD').setRequired(true).setMinValue(0.01))
      .addStringOption((o) => o.setName('memo').setDescription('What is the payment for?').setRequired(true).setMaxLength(100))
      .addUserOption((o) => o.setName('to_user').setDescription('Person to pay'))
      .addStringOption((o) => o.setName('to_business').setDescription('Business to pay').setAutocomplete(true))
      .addStringOption((o) => o.setName('source').setDescription('Pay from (default: bank)').addChoices({ name: 'Bank account', value: 'bank' }, { name: 'Cash', value: 'cash' }, { name: 'Credit card (businesses only)', value: 'card' })))
    .addSubcommand((s) => s.setName('withdraw').setDescription('Withdraw cash from your bank account')
      .addNumberOption((o) => o.setName('amount').setDescription('Amount in KGD').setRequired(true).setMinValue(0.01)))
    .addSubcommand((s) => s.setName('deposit').setDescription('Deposit cash into your bank account')
      .addNumberOption((o) => o.setName('amount').setDescription('Amount in KGD').setRequired(true).setMinValue(0.01)))
    .addSubcommand((s) => s.setName('credit').setDescription('Your credit score and borrowing conditions')),
  autocomplete: autocompleteAnyBusiness,
  async execute(ctx, interaction) {
    const sub = interaction.options.getSubcommand();
    const eco = ctx.eco;
    const { grantPaid } = citizen(ctx, interaction);
    const me = interaction.user.id;
    if (sub === 'balance') {
      const accs = personalAccounts(eco, me).filter((a) => ['personal_bank', 'personal_cash', 'credit_card'].includes(a.kind));
      const facilities = facilitiesForUser(eco, me);
      const c = getCitizen(eco, me);
      const fields = accs.map((a) => ({ name: a.kind === 'personal_bank' ? 'Bank' : a.kind === 'personal_cash' ? 'Cash' : 'Credit card',
        value: a.kind === 'credit_card' ? `${formatKGD(Math.max(0, -a.balance))} owed` : `${formatKGD(a.balance)}${a.frozen ? ' (frozen)' : ''}`, inline: true }));
      if (facilities.length) fields.push({ name: 'Credit', value: facilities.map((f) => `${f.type} #${f.id}: ${f.status}, owed ${formatKGD(f.outstanding)}`).join('\n') });
      fields.push({ name: 'Credit score', value: `${c.credit_score} (${creditBand(c.credit_score).label})`, inline: true });
      return reply(interaction, { embeds: [embed({ title: 'Your Kagundi accounts', color: COLORS.ok, fields,
        description: grantPaid ? `Welcome to Kagundi! You received a one-time starting balance of ${formatKGD(grantPaid)}.` : null,
        footer: 'Only you can see this message.' })] });
    }
    if (sub === 'transactions') {
      const kind = interaction.options.getString('account') ?? 'personal_bank';
      const page = interaction.options.getInteger('page') ?? 1;
      const acc = personalAccounts(eco, me).find((a) => a.kind === kind);
      if (!acc) throw new UserError('You do not have that account.');
      const rows = accountTransactions(eco, acc.id, { limit: 10, offset: (page - 1) * 10 }).map((t) => {
        const incoming = t.to_account === acc.id;
        return `\`#${t.id}\` day ${t.econ_day} ${incoming ? '+' : '-'}${formatKGD(t.amount)} ${incoming ? `from ${t.from_name}` : `to ${t.to_name}`} · ${t.category}${t.memo ? ` · ${t.memo.slice(0, 60)}` : ''}`;
      });
      return reply(interaction, { embeds: [embed({ title: `Transactions: ${acc.name}`, description: lines(rows, 'No transactions.'), footer: `Page ${page} · balance ${formatKGD(acc.balance)}` })] });
    }
    if (sub === 'pay') {
      notMaintenance(ctx, interaction);
      const target = interaction.options.getUser('to_user');
      const business = interaction.options.getString('to_business');
      if (target?.bot) throw new UserError('You cannot pay a bot.');
      const amount = amountOption(interaction);
      const res = citizenPay(eco, { userId: me, source: interaction.options.getString('source') ?? 'bank', toUserId: target?.id ?? null,
        toBusinessId: business ? idOption(interaction, 'to_business') : null, amount, memo: interaction.options.getString('memo') });
      return reply(interaction, `Paid ${formatKGD(amount)} to ${target ? user(target.id) : `business #${business}`}. Transaction #${res.txId}.`);
    }
    if (sub === 'withdraw') {
      notMaintenance(ctx, interaction);
      const amount = amountOption(interaction);
      withdrawCash(eco, { userId: me, amount });
      return reply(interaction, `Withdrew ${formatKGD(amount)} in cash.`);
    }
    if (sub === 'deposit') {
      notMaintenance(ctx, interaction);
      const amount = amountOption(interaction);
      depositCash(eco, { userId: me, amount });
      return reply(interaction, `Deposited ${formatKGD(amount)} into your bank account.`);
    }
    if (sub === 'credit') {
      const { score, parts } = computeCreditScore(eco, me);
      const band = creditBand(score);
      const income = verifiedMonthlyIncome(eco, 'citizen', me);
      const obligations = monthlyDebtObligations(eco, 'citizen', me);
      return reply(interaction, { embeds: [embed({ title: `Credit score: ${score} (${band.label})`, color: COLORS.info, fields: [
        { name: 'Score factors', value: Object.entries(parts).map(([k, v]) => `${k}: ${v >= 0 ? '+' : ''}${v}`).join('\n') },
        { name: 'Your lending rate', value: `${bpToPct(lendingRateBp(eco, score))} per year`, inline: true },
        { name: 'Maximum loan', value: formatKGD(band.maxLoan), inline: true },
        { name: 'Card limit (max.)', value: formatKGD(band.cardLimit), inline: true },
        { name: 'Verified monthly net income', value: income.monthly === null ? `not enough history (${income.historyDays} day(s))` : formatKGD(income.monthly), inline: true },
        { name: 'Monthly debt payments', value: formatKGD(obligations), inline: true },
      ], footer: 'Scores are recalculated every economic day. Start: 600. Range 300-850.' })] });
    }
  },
};

const work = {
  data: command('work', 'Clock in for your shift today (one paid shift per economic day)')
    .addStringOption((o) => o.setName('job').setDescription('Which job (only needed if you have several)').setAutocomplete(true)),
  async autocomplete(ctx, interaction) {
    const jobs = eligibleJobs(ctx.eco, interaction.user.id, memberRoleKeys(ctx, interaction.member));
    return jobs.slice(0, 25).map((j) => ({ name: `${j.title}${j.business_name ? ` at ${j.business_name}` : ' (public sector)'} - ${formatKGD(j.daily_wage)}/day`.slice(0, 100), value: String(j.id) }));
  },
  async execute(ctx, interaction) {
    notMaintenance(ctx, interaction);
    citizen(ctx, interaction);
    const jobId = interaction.options.getString('job') ? idOption(interaction, 'job') : null;
    const { job, day } = clockIn(ctx.eco, { userId: interaction.user.id, roleKeys: memberRoleKeys(ctx, interaction.member), jobId });
    const tax = applyBp(job.daily_wage, getPolicy(ctx.eco, 'income_tax_bp'));
    return reply(interaction, `Shift registered for economic day ${day}: **${job.title}**${job.business_name ? ` at ${job.business_name}` : ''}. `
      + `Your wage of ${formatKGD(job.daily_wage)} (about ${formatKGD(job.daily_wage - tax)} after income tax) is paid when the day closes at 00:00 ${ctx.eco.clock.timeZone}.`);
  },
};

const jobs = {
  data: command('jobs', 'Jobs in Kagundi')
    .addSubcommand((s) => s.setName('list').setDescription('Open job postings and public-sector careers'))
    .addSubcommand((s) => s.setName('apply').setDescription('Apply for a private-sector job')
      .addStringOption((o) => o.setName('job').setDescription('Job').setRequired(true).setAutocomplete(true))
      .addStringOption((o) => o.setName('message').setDescription('Short message to the employer').setMaxLength(300)))
    .addSubcommand((s) => s.setName('mine').setDescription('Your jobs and recent shifts'))
    .addSubcommand((s) => s.setName('quit').setDescription('Resign from a private-sector job')
      .addStringOption((o) => o.setName('job').setDescription('Job').setRequired(true).setAutocomplete(true))),
  async autocomplete(ctx, interaction) {
    const sub = interaction.options.getSubcommand();
    if (sub === 'quit') {
      return myEmployments(ctx.eco, interaction.user.id).slice(0, 25).map((e) => ({ name: `${e.title} at ${e.business_name}`.slice(0, 100), value: String(e.job_id) }));
    }
    const focused = String(interaction.options.getFocused() ?? '').toLowerCase();
    return openJobs(ctx.eco).filter((j) => `${j.title} ${j.business_name}`.toLowerCase().includes(focused)).slice(0, 25)
      .map((j) => ({ name: `${j.title} at ${j.business_name} - ${formatKGD(j.daily_wage)}/day`.slice(0, 100), value: String(j.id) }));
  },
  async execute(ctx, interaction) {
    const sub = interaction.options.getSubcommand();
    const eco = ctx.eco;
    if (sub === 'list') {
      const priv = openJobs(eco).slice(0, 20).map((j) => `\`#${j.id}\` **${j.title}** at ${j.business_name} - ${formatKGD(j.daily_wage)}/day (${j.slots - j.filled} open)`);
      const pub = stateJobs(eco).map((j) => `${j.title}: ${formatKGD(j.daily_wage)}/day`);
      return reply(interaction, { embeds: [embed({ title: 'Jobs in Kagundi', fields: [
        { name: 'Private sector (apply with /jobs apply)', value: lines(priv, 'No open postings right now. Check #employment.') },
        { name: 'Public sector (join through #faction-applications)', value: lines(pub.slice(0, 15)) },
      ], footer: 'Work a shift every day with /work. Wages are paid when the economic day closes.' })] });
    }
    citizen(ctx, interaction);
    if (sub === 'apply') {
      notMaintenance(ctx, interaction);
      const r = applyForJob(eco, { jobId: idOption(interaction, 'job'), userId: interaction.user.id, message: interaction.options.getString('message') });
      return reply(interaction, `Application #${r.id} sent to ${r.business.name} for **${r.job.title}**. The owner or a manager decides with /business staff hire.`);
    }
    if (sub === 'mine') {
      const keys = memberRoleKeys(ctx, interaction.member);
      const all = eligibleJobs(eco, interaction.user.id, keys).map((j) => `${j.title}${j.business_name ? ` at ${j.business_name}` : ' (public)'} - ${formatKGD(j.daily_wage)}/day`);
      const shifts = recentShifts(eco, interaction.user.id).map((s) => `Day ${s.econ_day}: ${s.title} - ${s.status}${s.status === 'paid' ? ` (${formatKGD(s.net)} net)` : ''}`);
      return reply(interaction, { embeds: [embed({ title: 'Your jobs', fields: [{ name: 'Jobs', value: lines(all, 'No job yet.') }, { name: 'Recent shifts', value: lines(shifts, 'No shifts yet.') }] })] });
    }
    if (sub === 'quit') {
      notMaintenance(ctx, interaction);
      const job = quitJob(eco, { userId: interaction.user.id, jobId: idOption(interaction, 'job') });
      ctx.syncRoles?.([interaction.user.id]);
      return reply(interaction, `You resigned from **${job.title}**.`);
    }
  },
};

export default [economy, bank, work, jobs];
