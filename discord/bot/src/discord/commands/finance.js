// Personal finance and legal obligations: /loan, /card, /insurance, /property, /fine
import { applyForLoan, applyForCard, repay, facilitiesForUser, assessLoan, cardMinimumPayment } from '../../economy/credit.js';
import { quote, buyPolicy, policiesForUser, cancelPolicy, fileClaim } from '../../economy/insurance.js';
import {
  listProperties, propertiesOfUser, rentProperty, leaveProperty, buyProperty, listForSale, unlist, setRent, createStateProperty,
} from '../../economy/property.js';
import { issueFine, finesOf, payFine, cancelFine } from '../../economy/fines.js';
import { getPolicy } from '../../economy/policy.js';
import { AVK_PRODUCTS, CREDIT_RULES, PROPERTY_TYPES } from '../../economy/constants.js';
import { formatKGD, bpToPct } from '../../economy/money.js';
import { UserError } from '../../economy/errors.js';
import { can, requirePermission, memberRoleKeys } from '../auth.js';
import { embed, reply, user, lines, COLORS } from '../format.js';
import {
  command, citizen, notMaintenance, amountOption, amountOrZero, idOption, autocompleteMyBusinesses, productChoices, cityChoices,
} from './common.js';

const businessOpt = (desc) => (o) => o.setName('business').setDescription(desc).setAutocomplete(true);

// ---------------------------------------------------------------- /loan
const loan = {
  data: command('loan', 'Loans from the state bank')
    .addSubcommand((s) => s.setName('check').setDescription('Check whether you would get a loan, without applying')
      .addNumberOption((o) => o.setName('amount').setDescription('Amount in KGD').setRequired(true).setMinValue(100))
      .addIntegerOption((o) => o.setName('weeks').setDescription(`Term in weeks (${CREDIT_RULES.minTermWeeks}-${CREDIT_RULES.maxTermWeeks})`).setRequired(true)
        .setMinValue(CREDIT_RULES.minTermWeeks).setMaxValue(CREDIT_RULES.maxTermWeeks)))
    .addSubcommand((s) => s.setName('apply').setDescription('Apply for a loan (small loans are paid out at once)')
      .addNumberOption((o) => o.setName('amount').setDescription('Amount in KGD').setRequired(true).setMinValue(100))
      .addIntegerOption((o) => o.setName('weeks').setDescription(`Term in weeks (${CREDIT_RULES.minTermWeeks}-${CREDIT_RULES.maxTermWeeks})`).setRequired(true)
        .setMinValue(CREDIT_RULES.minTermWeeks).setMaxValue(CREDIT_RULES.maxTermWeeks))
      .addStringOption((o) => o.setName('purpose').setDescription('What is the loan for?').setRequired(true).setMaxLength(150))
      .addStringOption(businessOpt('Borrow for your business instead of yourself (owner only)')))
    .addSubcommand((s) => s.setName('list').setDescription('Your loans and credit card'))
    .addSubcommand((s) => s.setName('repay').setDescription('Repay early (any amount)')
      .addStringOption((o) => o.setName('loan').setDescription('Loan').setRequired(true).setAutocomplete(true))
      .addNumberOption((o) => o.setName('amount').setDescription('Amount in KGD').setRequired(true).setMinValue(0.01))),
  async autocomplete(ctx, interaction) {
    const focused = interaction.options.getFocused(true);
    if (focused.name === 'business') return autocompleteMyBusinesses(ctx, interaction);
    return facilitiesForUser(ctx.eco, interaction.user.id).filter((f) => f.type === 'loan' && f.status !== 'pending')
      .map((f) => ({ name: `Loan #${f.id}: ${formatKGD(f.outstanding)} owed (${f.status})`, value: String(f.id) }));
  },
  async execute(ctx, interaction) {
    const eco = ctx.eco;
    const sub = interaction.options.getSubcommand();
    const me = interaction.user.id;
    citizen(ctx, interaction);
    if (sub === 'check') {
      const amount = amountOption(interaction);
      const weeks = interaction.options.getInteger('weeks');
      const a = assessLoan(eco, { borrowerType: 'citizen', borrowerId: me, scoreUserId: me, amount, weeks });
      const total = a.installment * weeks;
      return reply(interaction, { embeds: [embed({ title: a.ok ? 'You would qualify for this loan' : 'You would not qualify right now', color: a.ok ? COLORS.ok : COLORS.warn, fields: [
        { name: 'Weekly installment', value: formatKGD(a.installment), inline: true },
        { name: 'Interest rate', value: `${bpToPct(a.rateBp)} per year`, inline: true },
        { name: 'Total repaid', value: `${formatKGD(total)} (interest ${formatKGD(total - amount)})`, inline: true },
        { name: 'Credit score', value: `${a.score} (${a.band.label})`, inline: true },
        { name: 'Approval', value: amount > CREDIT_RULES.autoApproveLimit ? 'Decided by the Secretariat for Economy (above the automatic limit)' : 'Automatic', inline: true },
        ...(a.ok ? [] : [{ name: 'Reasons', value: a.reasons.join('\n') }]),
      ], footer: `Rule: all debt payments together may not exceed ${CREDIT_RULES.maxDebtToIncome * 100}% of your verified monthly net income.` })] });
    }
    if (sub === 'apply') {
      notMaintenance(ctx, interaction);
      const amount = amountOption(interaction);
      const weeks = interaction.options.getInteger('weeks');
      const businessId = interaction.options.getString('business') ? idOption(interaction, 'business') : null;
      const r = applyForLoan(eco, { applicantId: me, amount, weeks, purpose: interaction.options.getString('purpose'), businessId });
      if (r.status === 'rejected') {
        return reply(interaction, { embeds: [embed({ title: `Loan application #${r.id} declined`, color: COLORS.warn, description: r.assessment.reasons.join('\n'),
          footer: 'Check your situation any time with /loan check and /bank credit.' })] });
      }
      if (r.status === 'pending') {
        await ctx.notify?.('economic_administration', `Loan application #${r.id} (${formatKGD(amount)}, ${weeks} weeks) passed the automatic checks and needs a decision: \`/credit-office pending\`.`);
        return reply(interaction, `Loan application #${r.id} passed all checks. Because it is above ${formatKGD(CREDIT_RULES.autoApproveLimit)}, the Secretariat for Economy and Education decides. Weekly installment if approved: ${formatKGD(r.assessment.installment)}.`);
      }
      return reply(interaction, `Loan #${r.id} approved and paid out: ${formatKGD(amount)}. You repay ${formatKGD(r.assessment.installment)} every ${CREDIT_RULES.installmentIntervalDays} economic days for ${weeks} weeks (${bpToPct(r.assessment.rateBp)} per year). Payments are collected automatically. Missed payments lower your credit score.`);
    }
    if (sub === 'list') {
      const rows = facilitiesForUser(eco, me).map((f) => {
        if (f.type === 'card') return `**Credit card #${f.id}** - limit ${formatKGD(f.principal)}, owed ${formatKGD(f.outstanding)}, minimum payment ${formatKGD(cardMinimumPayment(f.outstanding))} weekly`;
        const who = f.borrower_type === 'business' ? ` for business #${f.borrower_id}` : '';
        return `**Loan #${f.id}**${who} - ${f.status}, principal ${formatKGD(f.principal)}, owed ${formatKGD(f.outstanding)}, installment ${formatKGD(f.installment)} weekly${f.consecutive_missed ? `, **${f.consecutive_missed} missed**` : ''}`;
      });
      return reply(interaction, { embeds: [embed({ title: 'Your credit', description: lines(rows, 'No loans or credit cards.') })] });
    }
    if (sub === 'repay') {
      notMaintenance(ctx, interaction);
      const r = repay(eco, { id: idOption(interaction, 'loan'), userId: me, amount: amountOption(interaction) });
      return reply(interaction, `Repaid ${formatKGD(r.paid)}. ${r.remaining > 0 ? `Still owed: ${formatKGD(r.remaining)}.` : 'The loan is fully repaid.'}`);
    }
    throw new UserError('Unknown subcommand.');
  },
};

// ---------------------------------------------------------------- /card
const card = {
  data: command('card', 'Your credit card')
    .addSubcommand((s) => s.setName('apply').setDescription('Apply for a credit card (limit depends on credit score and income)'))
    .addSubcommand((s) => s.setName('status').setDescription('Limit, amount owed and minimum payment'))
    .addSubcommand((s) => s.setName('pay').setDescription('Pay off your card balance')
      .addNumberOption((o) => o.setName('amount').setDescription('Amount in KGD').setRequired(true).setMinValue(0.01))),
  async execute(ctx, interaction) {
    const eco = ctx.eco;
    const sub = interaction.options.getSubcommand();
    const me = interaction.user.id;
    citizen(ctx, interaction);
    const myCard = () => facilitiesForUser(eco, me).find((f) => f.type === 'card' && f.borrower_type === 'citizen');
    if (sub === 'apply') {
      notMaintenance(ctx, interaction);
      const r = applyForCard(eco, { userId: me });
      if (r.status === 'rejected') return reply(interaction, { embeds: [embed({ title: 'Card application declined', color: COLORS.warn, description: r.reasons.join('\n') })] });
      return reply(interaction, `Credit card #${r.id} approved with a limit of ${formatKGD(r.limit)} at ${bpToPct(r.rateBp)} per year. Pay businesses with /bank pay source:Credit card. A minimum payment is collected weekly from your bank account.`);
    }
    const f = myCard();
    if (!f) throw new UserError('You do not have a credit card. Apply with /card apply.');
    if (sub === 'status') {
      return reply(interaction, { embeds: [embed({ title: `Credit card #${f.id}`, fields: [
        { name: 'Limit', value: formatKGD(f.principal), inline: true },
        { name: 'Owed', value: formatKGD(f.outstanding), inline: true },
        { name: 'Available', value: formatKGD(Math.max(0, f.principal - f.outstanding)), inline: true },
        { name: 'Interest', value: `${bpToPct(f.annual_rate_bp)} per year on the amount owed`, inline: true },
        { name: 'Minimum weekly payment', value: formatKGD(cardMinimumPayment(f.outstanding)), inline: true },
        { name: 'Status', value: f.status, inline: true },
      ] })] });
    }
    if (sub === 'pay') {
      notMaintenance(ctx, interaction);
      const r = repay(eco, { id: f.id, userId: me, amount: amountOption(interaction) });
      return reply(interaction, `Paid ${formatKGD(r.paid)} towards your card. Still owed: ${formatKGD(r.remaining)}.`);
    }
    throw new UserError('Unknown subcommand.');
  },
};

// ---------------------------------------------------------------- /insurance
const insurance = {
  data: command('insurance', 'AVK - Allgemeine Volksversicherung Kagundi')
    .addSubcommand((s) => s.setName('products').setDescription('AVK products and prices'))
    .addSubcommand((s) => s.setName('quote').setDescription('Daily premium for a product')
      .addStringOption((o) => o.setName('product').setDescription('Product').setRequired(true).addChoices(...productChoices()))
      .addNumberOption((o) => o.setName('value').setDescription('Insured value in KGD (vehicle, property, business)').setMinValue(1)))
    .addSubcommand((s) => s.setName('buy').setDescription('Take out a policy (first day charged now, then daily)')
      .addStringOption((o) => o.setName('product').setDescription('Product').setRequired(true).addChoices(...productChoices()))
      .addNumberOption((o) => o.setName('value').setDescription('Vehicle or business: insured value in KGD').setMinValue(1))
      .addStringOption((o) => o.setName('vehicle').setDescription('Vehicle: model and plate').setMaxLength(60))
      .addStringOption((o) => o.setName('property').setDescription('Property insurance: your property').setAutocomplete(true))
      .addStringOption(businessOpt('Business insurance: your business')))
    .addSubcommand((s) => s.setName('policies').setDescription('Your active policies'))
    .addSubcommand((s) => s.setName('cancel').setDescription('Cancel a policy')
      .addStringOption((o) => o.setName('policy').setDescription('Policy').setRequired(true).setAutocomplete(true)))
    .addSubcommand((s) => s.setName('claim').setDescription('File a claim (reviewed by an AVK officer)')
      .addStringOption((o) => o.setName('policy').setDescription('Policy').setRequired(true).setAutocomplete(true))
      .addNumberOption((o) => o.setName('amount').setDescription('Damage in KGD').setRequired(true).setMinValue(1))
      .addStringOption((o) => o.setName('incident').setDescription('Incident or report number (police, Brandwehr, EMS)').setRequired(true).setMaxLength(40))
      .addStringOption((o) => o.setName('description').setDescription('What happened?').setRequired(true).setMaxLength(500))
      .addStringOption((o) => o.setName('evidence').setDescription('Screenshot link or official report reference').setRequired(true).setMaxLength(300))),
  async autocomplete(ctx, interaction) {
    const focused = interaction.options.getFocused(true);
    if (focused.name === 'business') return autocompleteMyBusinesses(ctx, interaction);
    if (focused.name === 'property') {
      return propertiesOfUser(ctx.eco, interaction.user.id).owned.slice(0, 25).map((p) => ({ name: `#${p.id} ${p.name} (${p.city})`.slice(0, 100), value: String(p.id) }));
    }
    return policiesForUser(ctx.eco, interaction.user.id).slice(0, 25)
      .map((p) => ({ name: `#${p.id} ${AVK_PRODUCTS[p.product]?.name ?? p.product}${p.insured_ref ? ` - ${p.insured_ref}` : ''}`.slice(0, 100), value: String(p.id) }));
  },
  async execute(ctx, interaction) {
    const eco = ctx.eco;
    const sub = interaction.options.getSubcommand();
    const me = interaction.user.id;
    if (sub === 'products') {
      const rows = Object.values(AVK_PRODUCTS).map((p) => `**${p.name}** - ${p.flatDaily ? `${formatKGD(p.flatDaily)}/day, coverage ${formatKGD(p.coverage)}`
        : `${(p.dailyRatePcm / 1000).toFixed(3)}% of the insured value per day (${formatKGD(p.minValue)}-${formatKGD(p.maxValue)})`}, deductible ${formatKGD(p.deductible)}`);
      return reply(interaction, { embeds: [embed({ title: 'AVK - Allgemeine Volksversicherung Kagundi', color: COLORS.avk, description: rows.join('\n'),
        footer: 'Basic healthcare is free for every citizen. Supplementary Health covers private treatment only. Claims need an official report reference.' })] });
    }
    if (sub === 'quote') {
      const product = interaction.options.getString('product');
      const q = quote(product, AVK_PRODUCTS[product].flatDaily ? null : amountOption(interaction, 'value', { required: false }));
      return reply(interaction, `${q.product.name}: ${formatKGD(q.dailyPremium)} per day (about ${formatKGD(q.dailyPremium * 30)} per 30 days), coverage ${formatKGD(q.coverage)}, deductible ${formatKGD(q.deductible)}.`);
    }
    citizen(ctx, interaction);
    if (sub === 'buy') {
      notMaintenance(ctx, interaction);
      const product = interaction.options.getString('product');
      const r = buyPolicy(eco, { userId: me, product,
        insuredValue: amountOption(interaction, 'value', { required: false }),
        propertyId: interaction.options.getString('property') ? idOption(interaction, 'property') : null,
        businessId: interaction.options.getString('business') ? idOption(interaction, 'business') : null,
        description: interaction.options.getString('vehicle') });
      return reply(interaction, `AVK policy #${r.id} (${r.product.name}) is active. Premium ${formatKGD(r.dailyPremium)} per day, coverage ${formatKGD(r.coverage)}, deductible ${formatKGD(r.deductible)}. Claims are possible after a waiting period of 2 economic days.`);
    }
    if (sub === 'policies') {
      const rows = policiesForUser(eco, me).map((p) => `\`#${p.id}\` ${AVK_PRODUCTS[p.product]?.name ?? p.product}${p.insured_ref ? ` (${p.insured_ref})` : ''} - ${formatKGD(p.daily_premium)}/day, coverage left ${formatKGD(p.coverage_limit - p.paid_out_total)}${p.unpaid_days ? `, **${p.unpaid_days} unpaid day(s)**` : ''}`);
      return reply(interaction, { embeds: [embed({ title: 'Your AVK policies', color: COLORS.avk, description: lines(rows, 'No active policies.'), footer: 'Policies lapse after 3 unpaid days.' })] });
    }
    if (sub === 'cancel') {
      notMaintenance(ctx, interaction);
      const p = cancelPolicy(eco, { policyId: idOption(interaction, 'policy'), userId: me });
      return reply(interaction, `Policy #${p.id} cancelled. No further premiums are charged.`);
    }
    if (sub === 'claim') {
      notMaintenance(ctx, interaction);
      const r = fileClaim(eco, { policyId: idOption(interaction, 'policy'), userId: me, amount: amountOption(interaction),
        incidentRef: interaction.options.getString('incident'), description: interaction.options.getString('description'), evidence: interaction.options.getString('evidence') });
      await ctx.notify?.('avk_office', `New AVK claim #${r.id} is waiting for review: \`/avk claims\`.`);
      return reply(interaction, `Claim #${r.id} submitted. An AVK officer reviews it. Maximum payout after deductible: ${formatKGD(r.maxPayout)}. False claims are insurance fraud and are punished in roleplay.`);
    }
    throw new UserError('Unknown subcommand.');
  },
};

// ---------------------------------------------------------------- /property
const propLabel = (p) => `\`#${p.id}\` **${p.name}** (${p.city}, ${p.type})`;
const ownerLabel = (p) => (p.owner_type === 'state' ? 'state' : p.owner_type === 'citizen' ? user(p.owner_id) : `business #${p.owner_id}`);

const property = {
  data: command('property', 'Rent, buy and sell property')
    .addSubcommand((s) => s.setName('list').setDescription('Properties available for rent or sale')
      .addStringOption((o) => o.setName('city').setDescription('City').addChoices(...cityChoices())))
    .addSubcommand((s) => s.setName('mine').setDescription('Properties you own or rent'))
    .addSubcommand((s) => s.setName('rent').setDescription('Rent a property (first day of rent paid now)')
      .addStringOption((o) => o.setName('property').setDescription('Property').setRequired(true).setAutocomplete(true))
      .addStringOption(businessOpt('Rent for your business instead of yourself')))
    .addSubcommand((s) => s.setName('leave').setDescription('End your lease')
      .addStringOption((o) => o.setName('property').setDescription('Property').setRequired(true).setAutocomplete(true)))
    .addSubcommand((s) => s.setName('buy').setDescription('Buy a property that is for sale (transfer tax applies)')
      .addStringOption((o) => o.setName('property').setDescription('Property').setRequired(true).setAutocomplete(true))
      .addStringOption(businessOpt('Buy for your business (owner only)')))
    .addSubcommand((s) => s.setName('sell').setDescription('Offer your property for sale')
      .addStringOption((o) => o.setName('property').setDescription('Property').setRequired(true).setAutocomplete(true))
      .addNumberOption((o) => o.setName('price').setDescription('Price in KGD').setRequired(true).setMinValue(1)))
    .addSubcommand((s) => s.setName('unlist').setDescription('Withdraw your sale offer')
      .addStringOption((o) => o.setName('property').setDescription('Property').setRequired(true).setAutocomplete(true)))
    .addSubcommand((s) => s.setName('set-rent').setDescription('Set the daily rent of a vacant property you own')
      .addStringOption((o) => o.setName('property').setDescription('Property').setRequired(true).setAutocomplete(true))
      .addNumberOption((o) => o.setName('rent').setDescription('Daily rent in KGD (0 allowed)').setRequired(true).setMinValue(0))
      .addBooleanOption((o) => o.setName('for_rent').setDescription('Offer it for rent (default yes)')))
    .addSubcommand((s) => s.setName('create').setDescription('Officials: register a new state-owned property')
      .addStringOption((o) => o.setName('name').setDescription('Name / address').setRequired(true).setMinLength(5).setMaxLength(60))
      .addStringOption((o) => o.setName('city').setDescription('City').setRequired(true).addChoices(...cityChoices()))
      .addStringOption((o) => o.setName('type').setDescription('Type').setRequired(true).addChoices(...PROPERTY_TYPES.map((t) => ({ name: t, value: t }))))
      .addNumberOption((o) => o.setName('value').setDescription('Value in KGD').setRequired(true).setMinValue(1))
      .addNumberOption((o) => o.setName('rent').setDescription('Daily rent in KGD').setRequired(true).setMinValue(0))
      .addBooleanOption((o) => o.setName('for_sale').setDescription('Also offer it for sale at its value'))),
  async autocomplete(ctx, interaction) {
    const eco = ctx.eco;
    const focused = interaction.options.getFocused(true);
    if (focused.name === 'business') return autocompleteMyBusinesses(ctx, interaction);
    const sub = interaction.options.getSubcommand();
    const text = String(focused.value ?? '').toLowerCase();
    const mine = propertiesOfUser(eco, interaction.user.id);
    let list;
    if (sub === 'rent') list = listProperties(eco).filter((p) => p.for_rent && !p.tenant_id);
    else if (sub === 'buy') list = listProperties(eco).filter((p) => p.for_sale);
    else if (sub === 'leave') list = mine.rented;
    else {
      list = [...mine.owned];
      if (can(ctx, interaction, 'property.state')) list.push(...eco.db.prepare("SELECT * FROM properties WHERE owner_type = 'state' ORDER BY name").all());
    }
    return list.filter((p) => `${p.name} ${p.city}`.toLowerCase().includes(text)).slice(0, 25).map((p) => {
      const price = sub === 'buy' ? ` - ${formatKGD(p.sale_price)}` : sub === 'rent' ? ` - ${formatKGD(p.daily_rent)}/day` : '';
      return { name: `#${p.id} ${p.name} (${p.city})${price}`.slice(0, 100), value: String(p.id) };
    });
  },
  async execute(ctx, interaction) {
    const eco = ctx.eco;
    const sub = interaction.options.getSubcommand();
    const me = interaction.user.id;
    if (sub === 'list') {
      const rows = listProperties(eco, { city: interaction.options.getString('city') }).slice(0, 30).map((p) => `${propLabel(p)} · owner ${ownerLabel(p)}`
        + `${p.for_rent && !p.tenant_id ? ` · rent ${formatKGD(p.daily_rent)}/day` : ''}${p.for_sale ? ` · **for sale ${formatKGD(p.sale_price)}**` : ''}`);
      return reply(interaction, { embeds: [embed({ title: 'Property market', description: lines(rows, 'Nothing available right now.'),
        footer: `Transfer tax ${bpToPct(getPolicy(eco, 'property_transfer_tax_bp'))} of the price. Owners pay ${bpToPct(getPolicy(eco, 'property_tax_annual_bp'))} property tax per year (charged daily).` })] });
    }
    citizen(ctx, interaction);
    const canState = can(ctx, interaction, 'property.state');
    if (sub === 'mine') {
      const { owned, rented } = propertiesOfUser(eco, me);
      return reply(interaction, { embeds: [embed({ title: 'Your property', fields: [
        { name: 'Owned', value: lines(owned.map((p) => `${propLabel(p)} · value ${formatKGD(p.value)}${p.tenant_id ? ` · rented out for ${formatKGD(p.daily_rent)}/day` : ''}${p.for_sale ? ` · for sale ${formatKGD(p.sale_price)}` : ''}${p.tax_arrears ? ` · tax arrears ${formatKGD(p.tax_arrears)}` : ''}`), 'none') },
        { name: 'Rented', value: lines(rented.map((p) => `${propLabel(p)} · ${formatKGD(p.daily_rent)}/day${p.rent_missed ? ` · **${p.rent_missed} missed payment(s)**` : ''}`), 'none') },
      ], footer: 'Rent is collected daily. After 3 missed payments the lease ends.' })] });
    }
    if (sub === 'create') {
      requirePermission(ctx, interaction, 'property.state');
      notMaintenance(ctx, interaction);
      const value = amountOption(interaction, 'value');
      const p = createStateProperty(eco, { actor: me, name: interaction.options.getString('name'), city: interaction.options.getString('city'), type: interaction.options.getString('type'),
        value, rent: amountOrZero(interaction, 'rent'), forSale: interaction.options.getBoolean('for_sale') ?? false, salePrice: value });
      return reply(interaction, `State property #${p.id} **${p.name}** registered in ${p.city}.`);
    }
    notMaintenance(ctx, interaction);
    const propertyId = idOption(interaction, 'property');
    const businessId = interaction.options.getString('business') ? idOption(interaction, 'business') : null;
    if (sub === 'rent') {
      const r = rentProperty(eco, { userId: me, propertyId, businessId });
      return reply(interaction, `You now rent **${r.property.name}** for ${formatKGD(r.property.daily_rent)} per day${businessId ? ' (for your business)' : ''}. The first day was paid; rent is collected automatically every day.`);
    }
    if (sub === 'leave') {
      const p = leaveProperty(eco, { userId: me, propertyId });
      return reply(interaction, `Your lease of **${p.name}** has ended.`);
    }
    if (sub === 'buy') {
      const r = buyProperty(eco, { userId: me, propertyId, businessId });
      return reply(interaction, `You bought **${r.property.name}** for ${formatKGD(r.price)} plus ${formatKGD(r.tax)} transfer tax.`);
    }
    if (sub === 'sell') {
      const p = listForSale(eco, { userId: me, propertyId, price: amountOption(interaction, 'price'), canManageState: canState });
      return reply(interaction, `**${p.name}** is now offered for sale for ${formatKGD(amountOption(interaction, 'price'))}. Anyone can buy it with /property buy.`);
    }
    if (sub === 'unlist') {
      const p = unlist(eco, { userId: me, propertyId, canManageState: canState });
      return reply(interaction, `**${p.name}** is no longer for sale.`);
    }
    if (sub === 'set-rent') {
      const rent = amountOrZero(interaction, 'rent');
      const p = setRent(eco, { userId: me, propertyId, rent, forRent: interaction.options.getBoolean('for_rent') ?? true, canManageState: canState });
      return reply(interaction, `Rent of **${p.name}** set to ${formatKGD(rent)} per day.`);
    }
    throw new UserError('Unknown subcommand.');
  },
};

// ---------------------------------------------------------------- /fine
const AUTHORITY_BY_ROLE = [
  ['judge', 'Court'], ['police_command', 'City Police'], ['city_police', 'City Police'], ['gendarmerie_command', 'Gendarmerie'], ['gendarmerie', 'Gendarmerie'],
];

const fine = {
  data: command('fine', 'Fines')
    .addSubcommand((s) => s.setName('issue').setDescription('Police, Gendarmerie and judges: issue a fine')
      .addUserOption((o) => o.setName('user').setDescription('Person to fine').setRequired(true))
      .addNumberOption((o) => o.setName('amount').setDescription('Amount in KGD').setRequired(true).setMinValue(1))
      .addStringOption((o) => o.setName('reason').setDescription('Offence').setRequired(true).setMaxLength(300))
      .addStringOption((o) => o.setName('case').setDescription('Report or case number').setMaxLength(40)))
    .addSubcommand((s) => s.setName('mine').setDescription('Your open fines'))
    .addSubcommand((s) => s.setName('pay').setDescription('Pay a fine')
      .addStringOption((o) => o.setName('fine').setDescription('Fine').setRequired(true).setAutocomplete(true)))
    .addSubcommand((s) => s.setName('cancel').setDescription('Judges and economic staff: cancel a fine (e.g. after an appeal)')
      .addIntegerOption((o) => o.setName('fine').setDescription('Fine number').setRequired(true).setMinValue(1))
      .addStringOption((o) => o.setName('reason').setDescription('Reason').setRequired(true).setMaxLength(300))),
  async autocomplete(ctx, interaction) {
    return finesOf(ctx.eco, interaction.user.id).map((f) => ({ name: `#${f.id} ${formatKGD(f.amount)} - ${f.reason}`.slice(0, 100), value: String(f.id) }));
  },
  async execute(ctx, interaction) {
    const eco = ctx.eco;
    const sub = interaction.options.getSubcommand();
    const me = interaction.user.id;
    if (sub === 'issue') {
      requirePermission(ctx, interaction, 'fines.issue');
      notMaintenance(ctx, interaction);
      const target = interaction.options.getUser('user');
      if (target.bot) throw new UserError('Bots cannot be fined.');
      const keys = memberRoleKeys(ctx, interaction.member);
      const authority = AUTHORITY_BY_ROLE.find(([k]) => keys.includes(k))?.[1] ?? 'State authority';
      const amount = amountOption(interaction);
      const reason = interaction.options.getString('reason');
      const r = issueFine(eco, { issuerId: me, authority, userId: target.id, amount, reason, caseRef: interaction.options.getString('case') });
      await ctx.dm?.(target.id, `You received fine #${r.id} from the ${authority} of Kagundi: ${formatKGD(amount)} for "${reason}". Pay it with /fine pay before economic day ${r.dueDay}; after that it is collected automatically. You can appeal through #legal-information.`);
      return reply(interaction, `Fine #${r.id} of ${formatKGD(amount)} issued to ${user(target.id)} (${authority}). Due on economic day ${r.dueDay}.`);
    }
    if (sub === 'cancel') {
      requirePermission(ctx, interaction, 'fines.cancel');
      const f = cancelFine(eco, { fineId: interaction.options.getInteger('fine'), actor: me, reason: interaction.options.getString('reason') });
      await ctx.dm?.(f.user_id, `Your fine #${f.id} (${formatKGD(f.amount)}) was cancelled.`);
      return reply(interaction, `Fine #${f.id} cancelled.`);
    }
    citizen(ctx, interaction);
    if (sub === 'mine') {
      const rows = finesOf(eco, me).map((f) => `\`#${f.id}\` ${formatKGD(f.amount)} - ${f.reason} (${f.authority}, due day ${f.due_day}${f.status === 'overdue' ? ', **overdue**' : ''})`);
      return reply(interaction, { embeds: [embed({ title: 'Your open fines', description: lines(rows, 'No open fines.'), footer: 'Unpaid fines are collected automatically after the due date. Overdue fines lower your credit score.' })] });
    }
    if (sub === 'pay') {
      notMaintenance(ctx, interaction);
      const f = payFine(eco, { userId: me, fineId: idOption(interaction, 'fine') });
      return reply(interaction, `Fine #${f.id} of ${formatKGD(f.amount)} paid.`);
    }
    throw new UserError('Unknown subcommand.');
  },
};

export default [loan, card, insurance, property, fine];
