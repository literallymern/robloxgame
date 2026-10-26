// Buttons: verification, civilian role, private tickets.
import {
  ActionRowBuilder, ButtonBuilder, ButtonStyle, ChannelType, OverwriteType, PermissionsBitField, AttachmentBuilder,
} from 'discord.js';
import { TICKET_TYPES, PANELS, ticketTypesForPanel } from '../blueprint/tickets.js';
import { compileTicket, BOT, EVERYONE } from '../blueprint/compile.js';
import { UserError, PermissionError } from '../economy/errors.js';
import { memberRoleKeys, isOwner } from './auth.js';
import { embed, reply, COLORS } from './format.js';

const MAX_OPEN_TICKETS = 3;

// ---------------------------------------------------------------- panels

export const PANEL_CHANNELS = {
  verify: 'verify',
  civilian: 'start_here',
  ...Object.fromEntries(Object.keys(PANELS).map((k) => [k, k])),
};

function rows(buttons) {
  const out = [];
  for (let i = 0; i < buttons.length; i += 5) out.push(new ActionRowBuilder().addComponents(buttons.slice(i, i + 5)));
  return out;
}

export function buildPanel(key, config) {
  if (key === 'verify') {
    return {
      embeds: [embed({ title: 'Verification', color: COLORS.ok, description: [
        'Welcome to **Ro-Nation**, the Democratic Republic of Kagundi.',
        '',
        'By pressing the button you confirm that you have read and accept the rules in #rules.',
        'You will receive the **Verified Member** role and can see the rest of the server.',
        '',
        `Requirement: your Discord account must be at least ${config.minAccountAgeDays} days old. This protects the community from spam and alternate accounts.`,
      ].join('\n') })],
      components: rows([new ButtonBuilder().setCustomId('verify').setLabel('I accept the rules').setStyle(ButtonStyle.Success).setEmoji('✅')]),
    };
  }
  if (key === 'civilian') {
    return {
      embeds: [embed({ title: 'Play as a civilian', description: 'Civilians are the backbone of Kagundi: workers, traders, farmers, miners and business owners. Press the button to add or remove the **Civilian** role. You can join a public service later through #faction-applications.' })],
      components: rows([new ButtonBuilder().setCustomId('civilian').setLabel('Civilian role on/off').setStyle(ButtonStyle.Primary).setEmoji('🧑‍🌾')]),
    };
  }
  const panel = PANELS[key];
  if (!panel) throw new Error(`Unknown panel ${key}`);
  const types = ticketTypesForPanel(key);
  return {
    embeds: [embed({ title: panel.title, description: `${panel.description}\n\nYou can have up to ${MAX_OPEN_TICKETS} open tickets at a time.` })],
    components: rows(types.map((t) => new ButtonBuilder().setCustomId(`ticket:open:${t.key}`).setLabel(t.label).setStyle(ButtonStyle.Secondary).setEmoji(t.emoji))),
  };
}

// ---------------------------------------------------------------- verification and roles

async function handleVerify(ctx, interaction) {
  const member = interaction.member;
  const keys = memberRoleKeys(ctx, member);
  if (keys.includes('restricted')) throw new PermissionError('Your access is restricted. You can appeal in #appeals.');
  if (keys.includes('verified')) return reply(interaction, 'You are already verified. Start in #start-here.');
  const ageDays = (Date.now() - interaction.user.createdTimestamp) / 86_400_000;
  if (ageDays < ctx.config.minAccountAgeDays) {
    throw new UserError(`Your Discord account is ${Math.floor(ageDays)} day(s) old. Accounts must be at least ${ctx.config.minAccountAgeDays} days old to verify. Please try again later, or ask a moderator for help.`);
  }
  const roleIds = ['verified', 'new_member'].map((k) => ctx.ids.role(k));
  if (roleIds.some((id) => !id)) throw new Error('Verified Member or New Member role is missing. Run the setup script.');
  await member.roles.add(roleIds, 'Verification button');
  ctx.eco.db.prepare('INSERT OR IGNORE INTO member_verifications (user_id, verified_at) VALUES (?, ?)').run(interaction.user.id, new Date().toISOString());
  return reply(interaction, [
    '**Welcome to Kagundi!** You are now verified.',
    '1. Read #start-here and #game-guide.',
    '2. Want to play a civilian? Use the button in #start-here.',
    '3. Open your bank account with `/bank balance` in #bank-terminal.',
    '4. Apply to a public service in #faction-applications.',
    `New members can post links and files after ${ctx.config.newMemberDays} days.`,
  ].join('\n'));
}

async function handleCivilian(ctx, interaction) {
  const keys = memberRoleKeys(ctx, interaction.member);
  if (!keys.includes('verified')) throw new PermissionError('Please verify first in #verify.');
  const id = ctx.ids.role('civilian');
  if (!id) throw new Error('Civilian role is missing.');
  if (keys.includes('civilian')) {
    await interaction.member.roles.remove(id, 'Self-service civilian toggle');
    return reply(interaction, 'Civilian role removed.');
  }
  await interaction.member.roles.add(id, 'Self-service civilian toggle');
  return reply(interaction, 'You now have the Civilian role. Find work with `/jobs list` or start a business with `/business register`.');
}

// ---------------------------------------------------------------- tickets

function resolveOverwrites(ctx, guild, applicantId, overwrites) {
  const out = [];
  for (const o of overwrites) {
    let id;
    let type = OverwriteType.Role;
    if (o.target === EVERYONE) id = guild.id;
    else if (o.target === BOT) { id = ctx.client.user.id; type = OverwriteType.Member; }
    else if (o.target === '@applicant') { id = applicantId; type = OverwriteType.Member; }
    else id = ctx.ids.role(o.target);
    if (!id) continue; // role not created on this server
    out.push({ id, type, allow: o.allow.map((p) => PermissionsBitField.Flags[p]), deny: o.deny.map((p) => PermissionsBitField.Flags[p]) });
  }
  return out;
}

function ticketChannelName(type, username) {
  const base = `${type.replace(/^apply_/, 'apply-').replace(/_/g, '-')}-${username}`.toLowerCase().replace(/[^a-z0-9-]/g, '').replace(/-+/g, '-');
  return base.slice(0, 90) || 'ticket';
}

async function openTicket(ctx, interaction, typeKey) {
  const type = TICKET_TYPES[typeKey];
  if (!type) throw new UserError('Unknown ticket type.');
  const keys = memberRoleKeys(ctx, interaction.member);
  const restricted = keys.includes('restricted');
  if (!keys.includes('verified') && !(type.allowRestricted && restricted) && !isOwner(ctx, interaction.user.id, interaction.member)) {
    throw new PermissionError('Please verify first in #verify.');
  }
  if (restricted && !type.allowRestricted) throw new PermissionError('While your access is restricted you can only open appeals.');
  const db = ctx.eco.db;
  const open = db.prepare("SELECT * FROM tickets WHERE user_id = ? AND status = 'open'").all(interaction.user.id);
  const sameType = open.find((t) => t.type === typeKey);
  if (sameType) throw new UserError(`You already have an open ticket of this type: <#${sameType.channel_id}>`);
  if (open.length >= MAX_OPEN_TICKETS) throw new UserError(`You can have at most ${MAX_OPEN_TICKETS} open tickets. Please close one first.`);
  const categoryId = ctx.ids.category('cat_tickets');
  if (!categoryId) throw new Error('TICKETS category is missing. Run the setup script.');

  await interaction.deferReply({ flags: 64 });
  const guild = interaction.guild;
  const overwrites = resolveOverwrites(ctx, guild, interaction.user.id, compileTicket({ reviewers: type.reviewers }));
  const channel = await guild.channels.create({
    name: ticketChannelName(typeKey, interaction.user.username),
    type: ChannelType.GuildText,
    parent: categoryId,
    topic: `${type.label} - ticket of ${interaction.user.tag ?? interaction.user.username} (${interaction.user.id})`,
    permissionOverwrites: overwrites,
    reason: `Ticket ${typeKey} opened by ${interaction.user.id}`,
  });
  db.prepare("INSERT INTO tickets (channel_id, user_id, type, status, created_at) VALUES (?, ?, ?, 'open', ?)").run(channel.id, interaction.user.id, typeKey, new Date().toISOString());
  const reviewerNames = type.reviewers.map((k) => ctx.ids.role(k) && `<@&${ctx.ids.role(k)}>`).filter(Boolean);
  await channel.send({
    content: `<@${interaction.user.id}>`,
    allowedMentions: { users: [interaction.user.id] },
    embeds: [embed({ title: `${type.emoji} ${type.label}`, description: `${type.template.join('\n')}\n\nResponsible: ${reviewerNames.join(', ') || 'Administrators'}`,
      footer: 'Only you, the responsible team and administrators can see this channel. Press "Close" when you are done.' })],
    components: rows([new ButtonBuilder().setCustomId('ticket:close').setLabel('Close ticket').setStyle(ButtonStyle.Danger).setEmoji('🔒')]),
  });
  return interaction.editReply({ content: `Your ticket is open: <#${channel.id}>` });
}

function ticketOf(ctx, channelId) {
  const t = ctx.eco.db.prepare('SELECT * FROM tickets WHERE channel_id = ?').get(channelId);
  if (!t) throw new UserError('This is not a ticket channel.');
  return t;
}

function isTicketStaff(ctx, interaction, ticket) {
  if (isOwner(ctx, interaction.user.id, interaction.member)) return true;
  const keys = memberRoleKeys(ctx, interaction.member);
  const reviewers = TICKET_TYPES[ticket.type]?.reviewers ?? [];
  return keys.includes('administrator') || keys.includes('moderator') || reviewers.some((k) => keys.includes(k));
}

async function transcript(channel) {
  const all = [];
  let before;
  for (let i = 0; i < 10; i++) { // up to 1,000 messages
    const batch = await channel.messages.fetch({ limit: 100, before });
    if (!batch.size) break;
    all.push(...batch.values());
    before = batch.last().id;
    if (batch.size < 100) break;
  }
  all.reverse();
  return all.map((m) => {
    const parts = [m.content];
    for (const e of m.embeds) parts.push(`[embed] ${e.title ?? ''} ${e.description ?? ''}`.trim());
    for (const a of m.attachments.values()) parts.push(`[attachment] ${a.url}`);
    return `[${m.createdAt.toISOString()}] ${m.author.tag ?? m.author.username} (${m.author.id}): ${parts.filter(Boolean).join(' | ')}`;
  }).join('\n');
}

async function closeTicket(ctx, interaction) {
  const t = ticketOf(ctx, interaction.channelId);
  if (t.status !== 'open') throw new UserError('This ticket is already closed.');
  if (t.user_id !== interaction.user.id && !isTicketStaff(ctx, interaction, t)) throw new PermissionError('Only the ticket owner or the responsible team can close this ticket.');
  await interaction.deferReply();
  const channel = interaction.channel;
  const text = await transcript(channel);
  const logId = ctx.ids.channel('ticket_transcripts');
  if (logId) {
    const log = await ctx.client.channels.fetch(logId).catch(() => null);
    await log?.send({
      content: `Transcript of ticket **${channel.name}** (${TICKET_TYPES[t.type]?.label ?? t.type}) · owner <@${t.user_id}> · closed by <@${interaction.user.id}>`,
      allowedMentions: { parse: [] },
      files: [new AttachmentBuilder(Buffer.from(text || '(empty)', 'utf8'), { name: `${channel.name}.txt` })],
    });
  }
  await channel.permissionOverwrites.edit(t.user_id, { ViewChannel: false }, { reason: 'Ticket closed' }).catch(() => null);
  ctx.eco.db.prepare("UPDATE tickets SET status = 'closed', closed_at = ?, closed_by = ? WHERE channel_id = ?").run(new Date().toISOString(), interaction.user.id, channel.id);
  await channel.setName(`closed-${channel.name}`.slice(0, 100)).catch(() => null);
  return interaction.editReply({
    content: `Ticket closed by <@${interaction.user.id}>. ${logId ? 'The transcript was saved.' : 'No transcript channel is configured.'}`,
    allowedMentions: { parse: [] },
    components: rows([
      new ButtonBuilder().setCustomId('ticket:reopen').setLabel('Reopen').setStyle(ButtonStyle.Secondary),
      new ButtonBuilder().setCustomId('ticket:delete').setLabel('Delete channel').setStyle(ButtonStyle.Danger),
    ]),
  });
}

async function reopenTicket(ctx, interaction) {
  const t = ticketOf(ctx, interaction.channelId);
  if (t.status !== 'closed') throw new UserError('This ticket is not closed.');
  if (!isTicketStaff(ctx, interaction, t)) throw new PermissionError('Only the responsible team can reopen tickets.');
  await interaction.channel.permissionOverwrites.edit(t.user_id, { ViewChannel: true, SendMessages: true, ReadMessageHistory: true }, { reason: 'Ticket reopened' });
  ctx.eco.db.prepare("UPDATE tickets SET status = 'open', closed_at = NULL, closed_by = NULL WHERE channel_id = ?").run(t.channel_id);
  await interaction.channel.setName(interaction.channel.name.replace(/^closed-/, '')).catch(() => null);
  return interaction.reply({ content: `Ticket reopened by <@${interaction.user.id}>.`, allowedMentions: { parse: [] } });
}

// Deleting is only possible after closing, when the transcript has been saved.
async function deleteTicket(ctx, interaction) {
  const t = ticketOf(ctx, interaction.channelId);
  if (t.status !== 'closed') throw new UserError('Close the ticket first (this saves the transcript).');
  if (!isTicketStaff(ctx, interaction, t)) throw new PermissionError('Only the responsible team can delete ticket channels.');
  await interaction.reply({ content: 'Deleting this channel in 5 seconds…' });
  ctx.eco.db.prepare("UPDATE tickets SET status = 'deleted' WHERE channel_id = ?").run(t.channel_id);
  setTimeout(() => interaction.channel.delete(`Ticket deleted by ${interaction.user.id}`).catch((err) => ctx.log?.error?.('Ticket delete failed', err)), 5000);
}

// ---------------------------------------------------------------- router

export async function handleButton(ctx, interaction) {
  const id = interaction.customId;
  if (id === 'verify') return handleVerify(ctx, interaction);
  if (id === 'civilian') return handleCivilian(ctx, interaction);
  if (id.startsWith('ticket:open:')) return openTicket(ctx, interaction, id.slice('ticket:open:'.length));
  if (id === 'ticket:close') return closeTicket(ctx, interaction);
  if (id === 'ticket:reopen') return reopenTicket(ctx, interaction);
  if (id === 'ticket:delete') return deleteTicket(ctx, interaction);
  throw new UserError('This button is no longer active.');
}
