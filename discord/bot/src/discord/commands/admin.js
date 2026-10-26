// Staff commands: /econ-admin (economic staff), /roster (department leaders), /panel (administrators)
import { adjustBalance, setFrozen, inspectCitizen, setMaintenance, isMaintenance, ADMIN_CORRECTION_LIMIT } from '../../economy/admin.js';
import { startEvent, endEvent, eventsActiveOn, describeEffect } from '../../economy/events.js';
import { EVENT_CATALOG } from '../../economy/event-catalog.js';
import { lastCompletedDay } from '../../economy/tick.js';
import { recentAudit, audit } from '../../economy/audit.js';
import { verifyLedger } from '../../economy/ledger.js';
import { personalAccountId } from '../../economy/citizens.js';
import { staffRemoveLink } from '../../economy/links.js';
import { requireBusiness } from '../../economy/businesses.js';
import { backupDatabase } from '../../db/database.js';
import { formatKGD } from '../../economy/money.js';
import { UserError, PermissionError } from '../../economy/errors.js';
import { ROLE_BY_KEY, ROLES } from '../../blueprint/roles.js';
import { requirePermission, isOwner, assignableRoles, memberRoleKeys } from '../auth.js';
import { buildPanel, PANEL_CHANNELS } from '../components.js';
import { embed, reply, user, lines, COLORS } from '../format.js';
import { command, amountOption, idOption, autocompleteAnyBusiness } from './common.js';

const reasonOpt = (o) => o.setName('reason').setDescription('Reason, e.g. ticket or incident reference (audit log)').setRequired(true).setMaxLength(300);

// ---------------------------------------------------------------- /econ-admin
const econAdmin = {
  data: command('econ-admin', 'Economic staff tools (all actions are audited)')
    .addSubcommand((s) => s.setName('inspect').setDescription('Full financial record of a citizen (viewing is audited)')
      .addUserOption((o) => o.setName('user').setDescription('Citizen').setRequired(true)).addStringOption(reasonOpt))
    .addSubcommand((s) => s.setName('adjust').setDescription(`Correct a verified error (above ${formatKGD(ADMIN_CORRECTION_LIMIT)} Owner only)`)
      .addStringOption((o) => o.setName('direction').setDescription('Add or remove money').setRequired(true).addChoices({ name: 'Add', value: 'add' }, { name: 'Remove', value: 'remove' }))
      .addNumberOption((o) => o.setName('amount').setDescription('Amount in KGD').setRequired(true).setMinValue(0.01))
      .addStringOption((o) => o.setName('reason').setDescription('Detailed reason with ticket reference').setRequired(true).setMinLength(10).setMaxLength(300))
      .addUserOption((o) => o.setName('user').setDescription('Citizen (bank account)'))
      .addStringOption((o) => o.setName('business').setDescription('Business account').setAutocomplete(true)))
    .addSubcommand((s) => s.setName('freeze').setDescription('Freeze accounts (stops voluntary payments; obligations still run)')
      .addStringOption(reasonOpt)
      .addUserOption((o) => o.setName('user').setDescription('Citizen'))
      .addStringOption((o) => o.setName('business').setDescription('Business').setAutocomplete(true)))
    .addSubcommand((s) => s.setName('unfreeze').setDescription('Unfreeze accounts')
      .addStringOption(reasonOpt)
      .addUserOption((o) => o.setName('user').setDescription('Citizen'))
      .addStringOption((o) => o.setName('business').setDescription('Business').setAutocomplete(true)))
    .addSubcommand((s) => s.setName('events').setDescription('Active economic events and the event catalogue'))
    .addSubcommand((s) => s.setName('event-start').setDescription('Start an economic event from the catalogue (from tomorrow)')
      .addStringOption((o) => o.setName('event').setDescription('Event').setRequired(true).setAutocomplete(true))
      .addStringOption(reasonOpt)
      .addIntegerOption((o) => o.setName('days').setDescription('Duration in days (1-30)').setMinValue(1).setMaxValue(30)))
    .addSubcommand((s) => s.setName('event-end').setDescription('End an event early (from today)')
      .addIntegerOption((o) => o.setName('id').setDescription('Event number').setRequired(true).setMinValue(1))
      .addStringOption(reasonOpt))
    .addSubcommand((s) => s.setName('maintenance').setDescription('Owner only: pause all economy actions of players')
      .addBooleanOption((o) => o.setName('on').setDescription('true = pause, false = resume').setRequired(true))
      .addStringOption(reasonOpt))
    .addSubcommand((s) => s.setName('tick-status').setDescription('Daily processing status, failures and integrity check'))
    .addSubcommand((s) => s.setName('tick-run').setDescription('Process any finished economic days now (safe to repeat)'))
    .addSubcommand((s) => s.setName('backup').setDescription('Write a database backup now'))
    .addSubcommand((s) => s.setName('audit').setDescription('Recent audit log entries')
      .addUserOption((o) => o.setName('actor').setDescription('Only actions by this person')))
    .addSubcommand((s) => s.setName('link-remove').setDescription('Remove a Discord-Roblox account link at once (recovery)')
      .addStringOption(reasonOpt)
      .addUserOption((o) => o.setName('user').setDescription('Discord member'))
      .addStringOption((o) => o.setName('roblox_id').setDescription('Roblox user ID').setMaxLength(16))),
  async autocomplete(ctx, interaction) {
    const focused = interaction.options.getFocused(true);
    if (focused.name === 'business') return autocompleteAnyBusiness(ctx, interaction);
    if (focused.name === 'event') {
      const text = String(focused.value ?? '').toLowerCase();
      return Object.entries(EVENT_CATALOG).filter(([k, e]) => `${k} ${e.name}`.toLowerCase().includes(text)).slice(0, 25)
        .map(([k, e]) => ({ name: `${e.name} (${e.durationDays} days)`.slice(0, 100), value: k }));
    }
    return [];
  },
  async execute(ctx, interaction) {
    const eco = ctx.eco;
    const sub = interaction.options.getSubcommand();
    const me = interaction.user.id;
    const owner = isOwner(ctx, me, interaction.member);
    requirePermission(ctx, interaction, 'econ.admin');
    const target = () => {
      const u = interaction.options.getUser('user');
      const b = interaction.options.getString('business');
      if (!!u === !!b) throw new UserError('Choose exactly one: user or business.');
      return u ? { userId: u.id } : { businessId: idOption(interaction, 'business') };
    };

    if (sub === 'inspect') {
      const u = interaction.options.getUser('user');
      const r = inspectCitizen(eco, { actor: me, userId: u.id, reason: interaction.options.getString('reason') });
      return reply(interaction, { embeds: [embed({ title: `Financial record: ${r.citizen.display_name}`, color: COLORS.warn, fields: [
        { name: 'Citizen', value: `${user(u.id)} · registered day ${r.citizen.registered_day} · credit score ${r.citizen.credit_score} · last active day ${r.citizen.last_active_day}` },
        { name: 'Accounts', value: lines(r.accounts.map((a) => `#${a.id} ${a.kind}: ${formatKGD(a.balance)}${a.frozen ? ` (frozen: ${a.frozen_reason})` : ''}`)) },
        { name: 'Credit', value: lines(r.credit.map((f) => `${f.type} #${f.id} ${f.status}: owed ${formatKGD(f.outstanding)}, missed ${f.total_missed}`), 'none') },
        { name: 'Insurance', value: lines(r.policies.map((p) => `#${p.id} ${p.product} ${formatKGD(p.daily_premium)}/day`), 'none') },
        { name: 'Open fines', value: lines(r.fines.map((f) => `#${f.id} ${formatKGD(f.amount)} ${f.status}`), 'none') },
        { name: 'Businesses', value: lines(r.businesses.map((b) => `#${b.id} ${b.name} (${b.status})`), 'none') },
      ], footer: 'Confidential. This lookup was recorded in the audit log.' })] });
    }
    if (sub === 'adjust') {
      const t = target();
      const accountId = t.userId ? personalAccountId(eco, t.userId, 'bank') : requireBusiness(eco, t.businessId).account_id;
      if (!accountId) throw new UserError('That business has no account yet.');
      if (t.userId === me) throw new PermissionError('You cannot correct your own balance. Ask another staff member.');
      const amount = amountOption(interaction) * (interaction.options.getString('direction') === 'remove' ? -1 : 1);
      const r = adjustBalance(eco, { actor: me, accountId, amount, reason: interaction.options.getString('reason'), isOwner: owner });
      return reply(interaction, `Correction booked (transaction #${r.txId}): ${r.account.name} ${formatKGD(r.before)} → ${formatKGD(r.after)}.`);
    }
    if (sub === 'freeze' || sub === 'unfreeze') {
      const n = setFrozen(eco, { actor: me, ...target(), frozen: sub === 'freeze', reason: interaction.options.getString('reason') });
      return reply(interaction, `${n} account(s) ${sub === 'freeze' ? 'frozen' : 'unfrozen'}.`);
    }
    if (sub === 'events') {
      const today = eco.currentDay();
      const active = [...eventsActiveOn(eco, today), ...eventsActiveOn(eco, today + 1).filter((e) => e.start_day > today)]
        .map((e) => `\`#${e.id}\` **${e.name}** · days ${e.start_day}-${e.end_day} · ${e.source} · ${e.effects.map(describeEffect).join('; ')}`);
      const catalogue = Object.entries(EVENT_CATALOG).map(([k, e]) => `\`${k}\` ${e.name} (${e.durationDays}d, ${e.probability ? `${(e.probability * 100).toFixed(1)}%/day random` : 'manual only'})`);
      return reply(interaction, { embeds: [embed({ title: 'Economic events', fields: [
        { name: 'Active and scheduled', value: lines(active, 'none') }, { name: 'Catalogue', value: lines(catalogue) },
      ], footer: 'Events only change prices, production, costs and partner demand within fixed limits. They never move money.' })] });
    }
    if (sub === 'event-start') {
      const r = startEvent(eco, { key: interaction.options.getString('event'), startDay: eco.currentDay() + 1, durationDays: interaction.options.getInteger('days') ?? undefined,
        source: 'admin', actor: me, reason: interaction.options.getString('reason') });
      return reply(interaction, `Event #${r.id} **${r.name}** scheduled for economic days ${r.startDay}-${r.endDay}. It appears in the reports.`);
    }
    if (sub === 'event-end') {
      const ev = endEvent(eco, { id: interaction.options.getInteger('id'), actor: me, reason: interaction.options.getString('reason') });
      return reply(interaction, `Event #${ev.id} **${ev.name}** ends today.`);
    }
    if (sub === 'maintenance') {
      if (!owner) throw new PermissionError('Only the Owner can switch maintenance mode.');
      const on = interaction.options.getBoolean('on');
      setMaintenance(eco, { actor: me, on, reason: interaction.options.getString('reason') });
      return reply(interaction, on ? 'Maintenance mode ON: players cannot change economic data. The daily processing continues.' : 'Maintenance mode OFF.');
    }
    if (sub === 'tick-status') {
      const failures = eco.db.prepare('SELECT * FROM tick_failures ORDER BY id DESC LIMIT 5').all();
      const unpublished = eco.db.prepare('SELECT day, publish_attempts, last_error FROM reports WHERE published_at IS NULL AND suppressed = 0 ORDER BY day').all();
      const check = verifyLedger(eco);
      const last = eco.db.prepare('SELECT * FROM econ_days ORDER BY day DESC LIMIT 1').get();
      return reply(interaction, { embeds: [embed({ title: 'Daily processing status', color: check.ok ? COLORS.ok : COLORS.error, fields: [
        { name: 'Current economic day', value: `${eco.currentDay()} (${eco.clock.dateOfDay(eco.currentDay())}, ${eco.clock.timeZone})`, inline: true },
        { name: 'Last completed day', value: last ? `${last.day} at ${last.completed_at}${last.late ? ' (late)' : ''}, ${last.duration_ms} ms` : 'none yet', inline: true },
        { name: 'Ledger integrity', value: check.ok ? 'OK - all balances match their transactions and the books sum to zero' : `**FAILED** - sum ${check.sum}, ${check.mismatches.length} mismatched account(s)` },
        { name: 'Unpublished reports', value: lines(unpublished.map((r) => `Day ${r.day}: ${r.publish_attempts} attempt(s)${r.last_error ? ` - ${r.last_error.slice(0, 100)}` : ''}`), 'none') },
        { name: 'Recent failures', value: lines(failures.map((f) => `Day ${f.day} at ${f.failed_at}: ${f.error.split('\n')[0].slice(0, 150)}`), 'none') },
        { name: 'Maintenance mode', value: isMaintenance(eco) ? 'ON' : 'off', inline: true },
      ] })] });
    }
    if (sub === 'tick-run') {
      const before = lastCompletedDay(eco);
      await ctx.runScheduler?.();
      const after = lastCompletedDay(eco);
      audit(eco, { actor: me, action: 'admin.tick_run', result: { before, after } });
      return reply(interaction, after > before ? `Processed economic day(s) ${before + 1}-${after}.` : `Nothing to process. The last completed day is ${after}; day ${eco.currentDay()} is still running.`);
    }
    if (sub === 'backup') {
      const file = backupDatabase(eco.db, ctx.config.backupDir, `manual-${new Date().toISOString().replace(/[:.]/g, '-')}`, ctx.config.backupKeep);
      audit(eco, { actor: me, action: 'admin.backup', result: { file: file.split(/[\\/]/).pop() } });
      return reply(interaction, `Backup written: \`${file.split(/[\\/]/).pop()}\` (in the bot's backup folder).`);
    }
    if (sub === 'audit') {
      const actor = interaction.options.getUser('actor');
      const rows = recentAudit(eco, { actor: actor?.id ?? null, limit: 15 }).map((a) => `\`#${a.id}\` day ${a.econ_day} · ${/^\d+$/.test(a.actor_id) ? user(a.actor_id) : a.actor_id} · **${a.action}**${a.target ? ` ${a.target}` : ''}${a.amount !== null ? ` · ${formatKGD(a.amount)}` : ''}${a.reason ? ` · ${a.reason.slice(0, 80)}` : ''}`);
      return reply(interaction, { embeds: [embed({ title: 'Audit log', description: lines(rows, 'No entries.') })] });
    }
    if (sub === 'link-remove') {
      const u = interaction.options.getUser('user');
      const removed = staffRemoveLink(eco, { actor: me, discordId: u?.id ?? null, robloxUserId: interaction.options.getString('roblox_id'), reason: interaction.options.getString('reason') });
      return reply(interaction, `Link removed: ${user(removed.discord_id)} ↔ Roblox ${removed.roblox_name ?? 'user'} (ID ${removed.roblox_user_id}). Recorded in the audit log.`);
    }
    throw new UserError('Unknown subcommand.');
  },
};

// ---------------------------------------------------------------- /roster
const roster = {
  data: command('roster', 'Department leaders: manage the members of your department')
    .addSubcommand((s) => s.setName('add').setDescription('Give a department or office role')
      .addUserOption((o) => o.setName('user').setDescription('Member').setRequired(true))
      .addStringOption((o) => o.setName('role').setDescription('Role').setRequired(true).setAutocomplete(true))
      .addStringOption((o) => o.setName('note').setDescription('Note for the audit log (e.g. application ticket)').setMaxLength(200)))
    .addSubcommand((s) => s.setName('remove').setDescription('Remove a department or office role')
      .addUserOption((o) => o.setName('user').setDescription('Member').setRequired(true))
      .addStringOption((o) => o.setName('role').setDescription('Role').setRequired(true).setAutocomplete(true))
      .addStringOption((o) => o.setName('note').setDescription('Note for the audit log').setMaxLength(200)))
    .addSubcommand((s) => s.setName('list').setDescription('Members of a role you manage')
      .addStringOption((o) => o.setName('role').setDescription('Role').setRequired(true).setAutocomplete(true))),
  async autocomplete(ctx, interaction) {
    const text = String(interaction.options.getFocused() ?? '').toLowerCase();
    const owner = isOwner(ctx, interaction.user.id, interaction.member);
    return [...assignableRoles(ctx, interaction)].filter((k) => k !== 'leader' || owner).map((k) => ROLE_BY_KEY[k])
      .filter((r) => r.name.toLowerCase().includes(text)).slice(0, 25).map((r) => ({ name: r.name, value: r.key }));
  },
  async execute(ctx, interaction) {
    const sub = interaction.options.getSubcommand();
    const key = interaction.options.getString('role');
    const allowed = assignableRoles(ctx, interaction);
    const owner = isOwner(ctx, interaction.user.id, interaction.member);
    if (!allowed.has(key) || (key === 'leader' && !owner)) throw new PermissionError('You cannot manage this role. Department leaders manage only their own department.');
    const roleId = ctx.ids.role(key);
    if (!roleId) throw new UserError(`The role ${ROLE_BY_KEY[key]?.name ?? key} does not exist on this server.`);
    const role = await interaction.guild.roles.fetch(roleId);
    if (sub === 'list') {
      await interaction.guild.members.fetch();
      const members = [...role.members.values()].map((m) => `${user(m.id)} (${m.displayName})`);
      return reply(interaction, { embeds: [embed({ title: `${role.name}: ${members.length} member(s)`, description: lines(members, 'Nobody has this role.') })] });
    }
    const target = interaction.options.getUser('user');
    if (target.bot) throw new UserError('Bots cannot hold department roles.');
    if (target.id === interaction.user.id && !owner) throw new PermissionError('You cannot change your own roles.');
    const member = await interaction.guild.members.fetch(target.id).catch(() => null);
    if (!member) throw new UserError('That person is not on this server.');
    const targetKeys = memberRoleKeys(ctx, member);
    const me = interaction.guild.members.me;
    if (role.position >= me.roles.highest.position) throw new UserError('The bot\'s role must be placed above this role in the server settings (Server Settings → Roles).');
    if (sub === 'add') {
      if (!targetKeys.includes('verified') || targetKeys.includes('restricted')) throw new UserError('Only verified members without restrictions can join a department.');
      if (targetKeys.includes(key)) throw new UserError(`${member.displayName} already has ${role.name}.`);
      await member.roles.add(roleId, `/roster add by ${interaction.user.id}`);
      audit(ctx.eco, { actor: interaction.user.id, action: 'roster.add', target: `member:${target.id}`, newValue: key, reason: interaction.options.getString('note') });
      return reply(interaction, `${user(target.id)} now has **${role.name}**.`);
    }
    if (sub === 'remove') {
      if (!targetKeys.includes(key)) throw new UserError(`${member.displayName} does not have ${role.name}.`);
      await member.roles.remove(roleId, `/roster remove by ${interaction.user.id}`);
      audit(ctx.eco, { actor: interaction.user.id, action: 'roster.remove', target: `member:${target.id}`, oldValue: key, reason: interaction.options.getString('note') });
      return reply(interaction, `${user(target.id)} no longer has **${role.name}**.`);
    }
    throw new UserError('Unknown subcommand.');
  },
};

// ---------------------------------------------------------------- /panel
const panelChoices = [
  { name: 'Verification (#verify)', value: 'verify' },
  { name: 'Civilian role (#start-here)', value: 'civilian' },
  { name: 'Support tickets (#support)', value: 'support' },
  { name: 'Player reports (#player-reports)', value: 'player_reports' },
  { name: 'Appeals (#appeals)', value: 'appeals' },
  { name: 'Faction applications (#faction-applications)', value: 'faction_applications' },
  { name: 'Business registry (#business-registration)', value: 'business_registration' },
  { name: 'Legal services (#legal-information)', value: 'legal_information' },
];

const panel = {
  data: command('panel', 'Administrators: post a button panel in its channel')
    .addStringOption((o) => o.setName('panel').setDescription('Which panel').setRequired(true).addChoices(...panelChoices, { name: 'All panels', value: 'all' })),
  async execute(ctx, interaction) {
    requirePermission(ctx, interaction, 'panels.post');
    const which = interaction.options.getString('panel');
    const keys = which === 'all' ? panelChoices.map((c) => c.value) : [which];
    const done = [];
    for (const key of keys) {
      const channelId = ctx.ids.channel(PANEL_CHANNELS[key]);
      if (!channelId) { done.push(`${key}: channel missing`); continue; }
      const channel = await ctx.client.channels.fetch(channelId);
      await channel.send({ ...buildPanel(key, ctx.config), allowedMentions: { parse: [] } });
      done.push(`${key}: posted in <#${channelId}>`);
    }
    audit(ctx.eco, { actor: interaction.user.id, action: 'panel.post', newValue: keys });
    return reply(interaction, done.join('\n'));
  },
};

// ---------------------------------------------------------------- /mod
// Moderators manage access without needing Discord's "Manage Roles" permission themselves.
const STAFF_KEYS = ['owner', 'developer', 'administrator', 'moderator', 'support_team', 'economic_administrator'];
// Every role that a restriction removes (all non-staff blueprint roles except Restricted itself).
const RESTRICT_REMOVES = ROLES.map((r) => r.key).filter((k) => !STAFF_KEYS.includes(k) && k !== 'restricted');

const mod = {
  data: command('mod', 'Moderators: verification and restrictions')
    .addSubcommand((s) => s.setName('verify').setDescription('Verify a member by hand (e.g. account younger than the minimum age)')
      .addUserOption((o) => o.setName('user').setDescription('Member').setRequired(true))
      .addStringOption(reasonOpt))
    .addSubcommand((s) => s.setName('restrict').setDescription('Restrict a member: removes all member and department roles until lifted')
      .addUserOption((o) => o.setName('user').setDescription('Member').setRequired(true))
      .addStringOption(reasonOpt))
    .addSubcommand((s) => s.setName('unrestrict').setDescription('Lift a restriction and restore the previous roles')
      .addUserOption((o) => o.setName('user').setDescription('Member').setRequired(true))
      .addStringOption(reasonOpt)),
  async execute(ctx, interaction) {
    requirePermission(ctx, interaction, 'mod.members');
    const sub = interaction.options.getSubcommand();
    const target = interaction.options.getUser('user');
    const reason = interaction.options.getString('reason');
    const me = interaction.user.id;
    if (target.bot) throw new UserError('This does not work on bots.');
    if (target.id === me) throw new PermissionError('You cannot use this on yourself.');
    const member = await interaction.guild.members.fetch(target.id).catch(() => null);
    if (!member) throw new UserError('That person is not on this server.');
    const keys = memberRoleKeys(ctx, member);
    const id = (k) => ctx.ids.role(k);
    const db = ctx.eco.db;
    const logLine = async (text) => ctx.notify?.('moderation_log', `${text} · by ${user(me)} · reason: ${reason}`);

    if (sub === 'verify') {
      if (keys.includes('restricted')) throw new UserError('This member is restricted. Use /mod unrestrict instead.');
      if (keys.includes('verified')) throw new UserError('This member is already verified.');
      await member.roles.add([id('verified'), id('new_member')].filter(Boolean), `/mod verify by ${me}`);
      db.prepare('INSERT OR IGNORE INTO member_verifications (user_id, verified_at) VALUES (?, ?)').run(target.id, new Date().toISOString());
      audit(ctx.eco, { actor: me, action: 'mod.verify', target: `member:${target.id}`, reason });
      await logLine(`✅ ${user(target.id)} verified by hand`);
      return reply(interaction, `${user(target.id)} is now verified.`);
    }
    if (sub === 'restrict') {
      if (keys.some((k) => STAFF_KEYS.includes(k))) throw new PermissionError('Staff members cannot be restricted with this command. Contact the Owner.');
      if (keys.includes('restricted')) throw new UserError('This member is already restricted.');
      const removed = keys.filter((k) => RESTRICT_REMOVES.includes(k));
      const existing = db.prepare('SELECT roles FROM restrictions WHERE user_id = ?').get(target.id);
      const toSave = [...new Set([...(existing ? JSON.parse(existing.roles) : []), ...removed])];
      db.prepare(`INSERT INTO restrictions (user_id, roles, reason, restricted_by, created_at) VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET roles = excluded.roles, reason = excluded.reason, restricted_by = excluded.restricted_by, created_at = excluded.created_at`)
        .run(target.id, JSON.stringify(toSave), reason, me, new Date().toISOString());
      await member.roles.add(id('restricted'), `/mod restrict by ${me}`);
      if (removed.length) await member.roles.remove(removed.map(id).filter(Boolean), `/mod restrict by ${me}`);
      audit(ctx.eco, { actor: me, action: 'mod.restrict', target: `member:${target.id}`, oldValue: removed, reason });
      await logLine(`⛔ ${user(target.id)} restricted (removed: ${removed.map((k) => ROLE_BY_KEY[k].name).join(', ') || 'no roles'})`);
      await ctx.dm?.(target.id, `Your access to Ro-Nation has been restricted. Reason: ${reason}. You can appeal in #appeals.`);
      return reply(interaction, `${user(target.id)} is restricted. Removed roles are saved and restored with /mod unrestrict.`);
    }
    if (sub === 'unrestrict') {
      if (!keys.includes('restricted')) throw new UserError('This member is not restricted.');
      const row = db.prepare('SELECT roles FROM restrictions WHERE user_id = ?').get(target.id);
      const restore = row ? JSON.parse(row.roles) : ['verified', 'community_member'];
      if (!restore.includes('verified')) restore.push('verified');
      await member.roles.add(restore.map(id).filter(Boolean), `/mod unrestrict by ${me}`);
      await member.roles.remove(id('restricted'), `/mod unrestrict by ${me}`);
      db.prepare('DELETE FROM restrictions WHERE user_id = ?').run(target.id);
      audit(ctx.eco, { actor: me, action: 'mod.unrestrict', target: `member:${target.id}`, newValue: restore, reason });
      await logLine(`♻️ ${user(target.id)} restriction lifted`);
      await ctx.dm?.(target.id, 'Your restriction on Ro-Nation was lifted. Welcome back.');
      return reply(interaction, `${user(target.id)} is no longer restricted. Restored: ${restore.map((k) => ROLE_BY_KEY[k]?.name ?? k).join(', ')}.`);
    }
    throw new UserError('Unknown subcommand.');
  },
};

export default [econAdmin, roster, panel, mod];
