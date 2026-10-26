// Business commands: /business and /invoice
import {
  registerBusiness, businessesForUser, publicBusinessList, businessSummary, closeBusiness, depositToBusiness, withdrawFromBusiness,
  addManager, removeManager, sellExport, buyImport, inventoryOf, requireBusinessAccess, getBusiness,
} from '../../economy/businesses.js';
import { postJob, closeJob, applicationsFor, hire, rejectApplication, fire } from '../../economy/employment.js';
import { createInvoice, payInvoice, cancelInvoice, invoicesForUser, getInvoice } from '../../economy/invoices.js';
import { accountTransactions } from '../../economy/payments.js';
import { exportQuote } from '../../economy/market.js';
import { COMMODITIES, INDUSTRIES, PARTNERS } from '../../economy/constants.js';
import { formatKGD, bpToPct } from '../../economy/money.js';
import { UserError } from '../../economy/errors.js';
import { embed, reply, user, lines, COLORS } from '../format.js';
import {
  command, citizen, notMaintenance, amountOption, idOption, autocompleteMyBusinesses, autocompleteAnyBusiness,
  commodityChoices, partnerChoices, industryChoices,
} from './common.js';

const exportChoices = () => commodityChoices((c) => c.tradable === 'export');
const importChoices = () => commodityChoices((c) => c.tradable === 'import');
const outputChoices = () => commodityChoices((c) => !!c.industry);

const businessOption = (o) => o.setName('business').setDescription('Your business').setRequired(true).setAutocomplete(true);

const business = {
  data: command('business', 'Register and run a business')
    .addSubcommand((s) => s.setName('register').setDescription('Apply to register a new business (fee charged on approval)')
      .addStringOption((o) => o.setName('name').setDescription('Business name (3-40 characters)').setRequired(true).setMinLength(3).setMaxLength(40))
      .addStringOption((o) => o.setName('industry').setDescription('Industry').setRequired(true).addChoices(...industryChoices()))
      .addStringOption((o) => o.setName('output').setDescription('Mining only: what the mine produces').addChoices(...outputChoices()))
      .addStringOption((o) => o.setName('description').setDescription('Short description of the business').setMaxLength(300)))
    .addSubcommand((s) => s.setName('list').setDescription('Directory of registered businesses'))
    .addSubcommand((s) => s.setName('status').setDescription('Finances, staff and stock of your business').addStringOption(businessOption))
    .addSubcommand((s) => s.setName('close').setDescription('Close your business permanently (remaining money is paid out)')
      .addStringOption(businessOption)
      .addStringOption((o) => o.setName('confirm').setDescription('Type the exact business name to confirm').setRequired(true)))
    .addSubcommandGroup((g) => g.setName('account').setDescription('Business bank account')
      .addSubcommand((s) => s.setName('deposit').setDescription('Move your own money into the business (capital)')
        .addStringOption(businessOption)
        .addNumberOption((o) => o.setName('amount').setDescription('Amount in KGD').setRequired(true).setMinValue(0.01)))
      .addSubcommand((s) => s.setName('withdraw').setDescription('Owner only: pay out profit (state share and distribution tax apply)')
        .addStringOption(businessOption)
        .addNumberOption((o) => o.setName('amount').setDescription('Amount in KGD').setRequired(true).setMinValue(0.01)))
      .addSubcommand((s) => s.setName('transactions').setDescription('Recent transactions of the business account')
        .addStringOption(businessOption)
        .addIntegerOption((o) => o.setName('page').setDescription('Page').setMinValue(1).setMaxValue(50))))
    .addSubcommandGroup((g) => g.setName('staff').setDescription('Jobs, hiring and managers')
      .addSubcommand((s) => s.setName('post-job').setDescription('Publish a job posting')
        .addStringOption(businessOption)
        .addStringOption((o) => o.setName('title').setDescription('Job title').setRequired(true).setMinLength(3).setMaxLength(60))
        .addNumberOption((o) => o.setName('wage').setDescription('Daily wage in KGD (gross)').setRequired(true).setMinValue(1))
        .addIntegerOption((o) => o.setName('positions').setDescription('Number of positions (1-20)').setRequired(true).setMinValue(1).setMaxValue(20)))
      .addSubcommand((s) => s.setName('close-job').setDescription('Close a job posting')
        .addStringOption((o) => o.setName('job').setDescription('Job posting').setRequired(true).setAutocomplete(true)))
      .addSubcommand((s) => s.setName('applications').setDescription('Pending applications').addStringOption(businessOption))
      .addSubcommand((s) => s.setName('hire').setDescription('Accept an application')
        .addStringOption((o) => o.setName('application').setDescription('Application').setRequired(true).setAutocomplete(true)))
      .addSubcommand((s) => s.setName('reject').setDescription('Reject an application')
        .addStringOption((o) => o.setName('application').setDescription('Application').setRequired(true).setAutocomplete(true)))
      .addSubcommand((s) => s.setName('fire').setDescription('End someone\'s employment')
        .addStringOption(businessOption)
        .addUserOption((o) => o.setName('user').setDescription('Employee').setRequired(true)))
      .addSubcommand((s) => s.setName('manager-add').setDescription('Owner only: give someone management rights')
        .addStringOption(businessOption)
        .addUserOption((o) => o.setName('user').setDescription('New manager').setRequired(true)))
      .addSubcommand((s) => s.setName('manager-remove').setDescription('Owner only: remove a manager')
        .addStringOption(businessOption)
        .addUserOption((o) => o.setName('user').setDescription('Manager').setRequired(true))))
    .addSubcommandGroup((g) => g.setName('market').setDescription('Export and import commodities')
      .addSubcommand((s) => s.setName('sell').setDescription('Export goods from your stock')
        .addStringOption(businessOption)
        .addStringOption((o) => o.setName('commodity').setDescription('Commodity').setRequired(true).addChoices(...exportChoices()))
        .addIntegerOption((o) => o.setName('quantity').setDescription('Quantity').setRequired(true).setMinValue(1))
        .addStringOption((o) => o.setName('partner').setDescription('Trading partner').setRequired(true).addChoices(...partnerChoices())))
      .addSubcommand((s) => s.setName('buy').setDescription('Import goods into your stock')
        .addStringOption(businessOption)
        .addStringOption((o) => o.setName('commodity').setDescription('Commodity').setRequired(true).addChoices(...importChoices()))
        .addIntegerOption((o) => o.setName('quantity').setDescription('Quantity').setRequired(true).setMinValue(1))
        .addStringOption((o) => o.setName('partner').setDescription('Trading partner').setRequired(true).addChoices(...partnerChoices())))
      .addSubcommand((s) => s.setName('inventory').setDescription('Stock of your business').addStringOption(businessOption))),

  async autocomplete(ctx, interaction) {
    const focused = interaction.options.getFocused(true);
    const me = interaction.user.id;
    const mine = businessesForUser(ctx.eco, me);
    if (focused.name === 'business') return autocompleteMyBusinesses(ctx, interaction);
    if (focused.name === 'job') {
      return mine.flatMap((b) => ctx.eco.db.prepare("SELECT id, title FROM jobs WHERE business_id = ? AND status = 'open'").all(b.id)
        .map((j) => ({ name: `#${j.id} ${j.title} (${b.name})`.slice(0, 100), value: String(j.id) }))).slice(0, 25);
    }
    if (focused.name === 'application') {
      return mine.flatMap((b) => applicationsFor(ctx.eco, b.id).map((a) => {
        const c = ctx.eco.db.prepare('SELECT display_name FROM citizens WHERE user_id = ?').get(a.user_id);
        return { name: `#${a.id} ${c?.display_name ?? a.user_id} for ${a.title} (${b.name})`.slice(0, 100), value: String(a.id) };
      })).slice(0, 25);
    }
    return [];
  },

  async execute(ctx, interaction) {
    const eco = ctx.eco;
    const group = interaction.options.getSubcommandGroup(false);
    const sub = interaction.options.getSubcommand();
    const me = interaction.user.id;

    if (!group && sub === 'list') {
      const rows = publicBusinessList(eco).map((b) => `\`#${b.id}\` **${b.name}** - ${INDUSTRIES[b.industry]?.name ?? b.industry}`
        + `${b.primary_output ? ` (${COMMODITIES[b.primary_output].name})` : ''} · owner ${user(b.owner_id)} · ${b.employees} employee(s)`
        + `${b.open_jobs ? ` · ${b.open_jobs} open job(s)` : ''}${b.status === 'suspended' ? ' · **suspended**' : ''}`);
      return reply(interaction, { embeds: [embed({ title: 'Business directory of Kagundi', color: COLORS.econ, description: lines(rows.slice(0, 40), 'No businesses registered yet.') })] });
    }

    citizen(ctx, interaction);

    if (!group) {
      if (sub === 'register') {
        notMaintenance(ctx, interaction);
        const res = registerBusiness(eco, { ownerId: me, name: interaction.options.getString('name'), industry: interaction.options.getString('industry'),
          output: interaction.options.getString('output'), description: interaction.options.getString('description') });
        await ctx.notify?.('economic_administration', `New business application **#${res.id} ${res.name}** (${INDUSTRIES[interaction.options.getString('industry')].name}) is waiting for the business registry: \`/registry pending\`.`);
        return reply(interaction, `Your application for **${res.name}** (#${res.id}) was submitted. The business registry reviews it; the registration fee of ${formatKGD(res.fee)} is charged from your bank account when it is approved. You can check the status with /business status.`);
      }
      const businessId = idOption(interaction, 'business');
      if (sub === 'status') {
        const s = businessSummary(eco, businessId);
        const b = s.business;
        if (b.owner_id !== me && !s.managers.includes(me)) throw new UserError('You do not own or manage this business.');
        const fields = [
          { name: 'Status', value: `${b.status}${b.suspended_reason ? ` (${b.suspended_reason})` : ''}`, inline: true },
          { name: 'Industry', value: `${INDUSTRIES[b.industry].name}${b.primary_output ? ` - ${COMMODITIES[b.primary_output].name}` : ''}`, inline: true },
          { name: 'Balance', value: s.account ? formatKGD(s.account.balance) : 'no account yet', inline: true },
          { name: 'Last 7 days', value: `in ${formatKGD(s.flows7d.inflow)} · out ${formatKGD(s.flows7d.outflow)}`, inline: true },
          { name: 'Daily licence fee', value: formatKGD(INDUSTRIES[b.industry].licenseFeeDaily), inline: true },
          { name: 'State share of profits', value: bpToPct(b.state_share_bp ?? 0), inline: true },
          { name: 'Employees', value: lines(s.employees.map((e) => `${user(e.user_id)} - ${e.title}, ${formatKGD(e.daily_wage)}/day`), 'none') },
          { name: 'Open job postings', value: lines(s.jobs.map((j) => `#${j.id} ${j.title} - ${formatKGD(j.daily_wage)}/day, ${j.slots} position(s)`), 'none') },
          { name: 'Managers', value: lines(s.managers.map(user), 'none') },
          { name: 'Stock', value: lines(s.inventory.filter((i) => i.quantity > 0).map((i) => `${COMMODITIES[i.commodity].name}: ${i.quantity} ${COMMODITIES[i.commodity].unit}`), 'empty') },
        ];
        if (b.license_arrears) fields.push({ name: 'Unpaid licence fees', value: `${formatKGD(b.license_arrears)} - deposit money to pay them automatically.` });
        if (s.unpaidWages.count) fields.push({ name: 'Unpaid wages', value: `${s.unpaidWages.count} shift(s), ${formatKGD(s.unpaidWages.total)} - paid automatically once the account has enough money.` });
        return reply(interaction, { embeds: [embed({ title: `${b.name} (#${b.id})`, color: COLORS.econ, fields })] });
      }
      if (sub === 'close') {
        notMaintenance(ctx, interaction);
        const b = requireBusinessAccess(eco, businessId, me, 'owner');
        if (interaction.options.getString('confirm').trim() !== b.name) throw new UserError(`To close the business, type its exact name: ${b.name}`);
        const employees = businessSummary(eco, businessId).employees.map((e) => e.user_id);
        const res = closeBusiness(eco, { businessId, userId: me });
        ctx.syncRoles?.([me, ...employees]);
        return reply(interaction, `**${b.name}** is closed. ${res.payout ? `Paid out to you: ${formatKGD(res.payout.net)} (state share ${formatKGD(res.payout.stateShare)}, distribution tax ${formatKGD(res.payout.tax)}).` : 'No money was left in the account.'}`);
      }
    }

    if (group === 'account') {
      const businessId = idOption(interaction, 'business');
      if (sub === 'deposit') {
        notMaintenance(ctx, interaction);
        const amount = amountOption(interaction);
        depositToBusiness(eco, { businessId, userId: me, amount });
        return reply(interaction, `Deposited ${formatKGD(amount)} from your bank account into **${getBusiness(eco, businessId).name}**.`);
      }
      if (sub === 'withdraw') {
        notMaintenance(ctx, interaction);
        const amount = amountOption(interaction);
        const r = withdrawFromBusiness(eco, { businessId, userId: me, amount });
        return reply(interaction, `Profit distribution of ${formatKGD(r.amount)}: state share ${formatKGD(r.stateShare)}, distribution tax ${formatKGD(r.tax)}, paid to your bank account ${formatKGD(r.net)}.`);
      }
      if (sub === 'transactions') {
        const b = requireBusinessAccess(eco, businessId, me, 'manager');
        const page = interaction.options.getInteger('page') ?? 1;
        const rows = accountTransactions(eco, b.account_id, { limit: 10, offset: (page - 1) * 10 }).map((t) => {
          const incoming = t.to_account === b.account_id;
          return `\`#${t.id}\` day ${t.econ_day} ${incoming ? '+' : '-'}${formatKGD(t.amount)} ${incoming ? `from ${t.from_name}` : `to ${t.to_name}`} · ${t.category}${t.memo ? ` · ${t.memo.slice(0, 60)}` : ''}`;
        });
        return reply(interaction, { embeds: [embed({ title: `Transactions: ${b.name}`, description: lines(rows, 'No transactions.'), footer: `Page ${page}` })] });
      }
    }

    if (group === 'staff') {
      notMaintenance(ctx, interaction);
      if (sub === 'post-job') {
        const r = postJob(eco, { businessId: idOption(interaction, 'business'), actor: me, title: interaction.options.getString('title'),
          wage: amountOption(interaction, 'wage'), slots: interaction.options.getInteger('positions') });
        await ctx.notify?.('employment', `**${r.business.name}** is hiring: **${r.title}** - ${formatKGD(r.wage)} per day, ${r.slots} position(s). Apply with \`/jobs apply\` (job #${r.id}).`, { title: `${r.title} at ${r.business.name}` });
        return reply(interaction, `Job #${r.id} **${r.title}** posted. Applicants appear in /business staff applications.`);
      }
      if (sub === 'close-job') {
        const job = closeJob(eco, { jobId: idOption(interaction, 'job'), actor: me });
        return reply(interaction, `Job posting #${job.id} **${job.title}** closed. Current employees keep their job.`);
      }
      if (sub === 'applications') {
        const b = requireBusinessAccess(eco, idOption(interaction, 'business'), me, 'manager');
        const rows = applicationsFor(eco, b.id).map((a) => `\`#${a.id}\` ${user(a.user_id)} for **${a.title}** (day ${a.created_day})${a.message ? `\n> ${a.message.slice(0, 200)}` : ''}`);
        return reply(interaction, { embeds: [embed({ title: `Applications: ${b.name}`, description: lines(rows, 'No pending applications.'), footer: 'Decide with /business staff hire or reject.' })] });
      }
      if (sub === 'hire') {
        const r = hire(eco, { applicationId: idOption(interaction, 'application'), actor: me });
        ctx.syncRoles?.([r.userId]);
        return reply(interaction, `${user(r.userId)} now works as **${r.job.title}** at ${r.business.name}. They clock in with /work.`);
      }
      if (sub === 'reject') {
        const r = rejectApplication(eco, { applicationId: idOption(interaction, 'application'), actor: me });
        return reply(interaction, `Application from ${user(r.userId)} for **${r.job.title}** rejected.`);
      }
      const businessId = idOption(interaction, 'business');
      const target = interaction.options.getUser('user');
      if (sub === 'fire') {
        const b = fire(eco, { businessId, actor: me, userId: target.id });
        ctx.syncRoles?.([target.id]);
        return reply(interaction, `${user(target.id)} no longer works for ${b.name}.`);
      }
      if (sub === 'manager-add') {
        if (target.bot) throw new UserError('Bots cannot be managers.');
        const b = addManager(eco, { businessId, actor: me, userId: target.id });
        return reply(interaction, `${user(target.id)} can now manage ${b.name} (jobs, hiring, trade, invoices). Only you can withdraw money or close the business.`);
      }
      if (sub === 'manager-remove') {
        const b = removeManager(eco, { businessId, actor: me, userId: target.id });
        return reply(interaction, `${user(target.id)} is no longer a manager of ${b.name}.`);
      }
    }

    if (group === 'market') {
      const businessId = idOption(interaction, 'business');
      if (sub === 'inventory') {
        const b = requireBusinessAccess(eco, businessId, me, 'manager');
        const rows = inventoryOf(eco, b.id).filter((i) => i.quantity > 0).map((i) => {
          const c = COMMODITIES[i.commodity];
          const value = c.tradable === 'export' ? ` (export value about ${formatKGD(exportQuote(eco, c.key, 'germany') * i.quantity)})` : '';
          return `${c.name}: ${i.quantity} ${c.unit}${value}`;
        });
        return reply(interaction, { embeds: [embed({ title: `Stock: ${b.name}`, description: lines(rows, 'No stock.') })] });
      }
      notMaintenance(ctx, interaction);
      const commodity = interaction.options.getString('commodity');
      const quantity = interaction.options.getInteger('quantity');
      const partner = interaction.options.getString('partner');
      const c = COMMODITIES[commodity];
      if (sub === 'sell') {
        const r = sellExport(eco, { businessId, userId: me, commodity, quantity, partner });
        return reply(interaction, `${r.business.name} exported ${quantity} ${c.unit} ${c.name} to ${PARTNERS[partner].name} at ${formatKGD(r.unit)} per ${c.unit}. `
          + `Sale ${formatKGD(r.gross)}, export duty ${formatKGD(r.duty)}, net ${formatKGD(r.net)}.`);
      }
      if (sub === 'buy') {
        const r = buyImport(eco, { businessId, userId: me, commodity, quantity, partner });
        return reply(interaction, `${r.business.name} imported ${quantity} ${c.unit} ${c.name} from ${PARTNERS[partner].name} at ${formatKGD(r.unit)} per ${c.unit} (incl. transport). `
          + `Goods ${formatKGD(r.cost)}, tariff ${formatKGD(r.tariff)}, total ${formatKGD(r.total)}.`);
      }
    }
    throw new UserError('Unknown subcommand.');
  },
};

const invoice = {
  data: command('invoice', 'Invoices between businesses, citizens and the state')
    .addSubcommand((s) => s.setName('create').setDescription('Bill a customer from your business')
      .addStringOption(businessOption)
      .addNumberOption((o) => o.setName('amount').setDescription('Amount in KGD').setRequired(true).setMinValue(0.01))
      .addStringOption((o) => o.setName('memo').setDescription('What is the invoice for?').setRequired(true).setMaxLength(200))
      .addUserOption((o) => o.setName('to_user').setDescription('Customer (person)'))
      .addStringOption((o) => o.setName('to_business').setDescription('Customer (business)').setAutocomplete(true))
      .addBooleanOption((o) => o.setName('to_state').setDescription('Bill the state (paid by the treasury after approval)'))
      .addStringOption((o) => o.setName('commodity').setDescription('Goods delivered from your stock (optional)').addChoices(...commodityChoices()))
      .addIntegerOption((o) => o.setName('quantity').setDescription('Quantity of goods').setMinValue(1)))
    .addSubcommand((s) => s.setName('list').setDescription('Open invoices you have to pay or have issued'))
    .addSubcommand((s) => s.setName('pay').setDescription('Pay an invoice')
      .addStringOption((o) => o.setName('invoice').setDescription('Invoice').setRequired(true).setAutocomplete(true)))
    .addSubcommand((s) => s.setName('cancel').setDescription('Cancel an open invoice (issuer or recipient)')
      .addStringOption((o) => o.setName('invoice').setDescription('Invoice').setRequired(true).setAutocomplete(true))),

  async autocomplete(ctx, interaction) {
    const focused = interaction.options.getFocused(true);
    if (focused.name === 'business') return autocompleteMyBusinesses(ctx, interaction);
    if (focused.name === 'to_business') return autocompleteAnyBusiness(ctx, interaction);
    const { toPay, issued } = invoicesForUser(ctx.eco, interaction.user.id);
    const sub = interaction.options.getSubcommand();
    const list = sub === 'pay' ? toPay : [...toPay, ...issued];
    return list.slice(0, 25).map((i) => ({ name: `#${i.id} ${formatKGD(i.amount)} - ${i.memo}`.slice(0, 100), value: String(i.id) }));
  },

  async execute(ctx, interaction) {
    const eco = ctx.eco;
    const sub = interaction.options.getSubcommand();
    const me = interaction.user.id;
    citizen(ctx, interaction);
    if (sub === 'create') {
      notMaintenance(ctx, interaction);
      const toUser = interaction.options.getUser('to_user');
      const toBusiness = interaction.options.getString('to_business');
      const toState = interaction.options.getBoolean('to_state') ?? false;
      const targets = [toUser, toBusiness, toState || null].filter(Boolean).length;
      if (targets !== 1) throw new UserError('Choose exactly one customer: to_user, to_business or to_state.');
      if (toUser?.bot) throw new UserError('You cannot invoice a bot.');
      if (toUser?.id === me) throw new UserError('You cannot invoice yourself.');
      const payerType = toUser ? 'citizen' : toBusiness ? 'business' : 'state';
      const payerId = toUser ? toUser.id : toBusiness ? idOption(interaction, 'to_business') : null;
      const r = createInvoice(eco, { businessId: idOption(interaction, 'business'), actor: me, payerType, payerId, amount: amountOption(interaction),
        memo: interaction.options.getString('memo'), commodity: interaction.options.getString('commodity'), quantity: interaction.options.getInteger('quantity') });
      if (payerType === 'state') {
        await ctx.notify?.('economic_administration', `Invoice #${r.id} from **${r.business.name}** to the state: ${formatKGD(amountOption(interaction))} - ${interaction.options.getString('memo')}. Pay with \`/treasury pay-invoice\`.`);
      }
      const recipient = toUser ? user(toUser.id) : toBusiness ? `business #${payerId}` : 'the state';
      return reply(interaction, `Invoice #${r.id} to ${recipient} created. It expires on economic day ${r.dueDay}. `
        + `${payerType === 'citizen' ? 'Tell your customer to pay it with /invoice pay.' : ''}`);
    }
    if (sub === 'list') {
      const { toPay, issued } = invoicesForUser(eco, me);
      const fmt = (i) => `\`#${i.id}\` ${formatKGD(i.amount)} - ${i.memo}${i.commodity ? ` (${i.quantity} ${COMMODITIES[i.commodity].unit} ${COMMODITIES[i.commodity].name})` : ''} · due day ${i.due_day}`;
      return reply(interaction, { embeds: [embed({ title: 'Open invoices', fields: [
        { name: 'To pay (you or your businesses)', value: lines(toPay.map(fmt), 'none') },
        { name: 'Issued by your businesses', value: lines(issued.map(fmt), 'none') },
      ] })] });
    }
    if (sub === 'pay') {
      notMaintenance(ctx, interaction);
      const id = idOption(interaction, 'invoice');
      const inv = getInvoice(eco, id);
      const r = payInvoice(eco, { invoiceId: id, actor: me });
      return reply(interaction, `Invoice #${inv.id} paid: ${formatKGD(inv.amount)} - ${inv.memo}. Transaction #${r.txId}.`);
    }
    if (sub === 'cancel') {
      notMaintenance(ctx, interaction);
      const inv = cancelInvoice(eco, { invoiceId: idOption(interaction, 'invoice'), actor: me });
      return reply(interaction, `Invoice #${inv.id} cancelled.`);
    }
    throw new UserError('Unknown subcommand.');
  },
};

export default [business, invoice];
