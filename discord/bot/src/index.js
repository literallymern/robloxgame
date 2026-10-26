// Ro-Nation economy bot: entry point.
// Start with `npm start` after filling in .env and running `npm run deploy-commands`.
import { Client, Events, GatewayIntentBits, ChannelType, MessageFlags } from 'discord.js';
import { config, requireDiscordConfig } from './config.js';
import { createEconomy } from './economy/index.js';
import { catchUp, recordTickFailure, unpublishedReports, markReportPublished, markReportFailed, lastCompletedDay } from './economy/tick.js';
import { reportToEmbeds, marketBoardEmbed } from './economy/report.js';
import { getSnapshot } from './economy/indicators.js';
import { unmirroredAudit, markMirrored } from './economy/audit.js';
import { UserError } from './economy/errors.js';
import { formatKGD } from './economy/money.js';
import { backupDatabase } from './db/database.js';
import { createResolver } from './discord/ids.js';
import { COMMAND_BY_NAME } from './discord/commands/index.js';
import { handleButton } from './discord/components.js';
import { embed, COLORS } from './discord/format.js';

try {
  requireDiscordConfig();
} catch (err) {
  console.error(err.message);
  process.exit(1);
}

const log = {
  info: (...a) => console.log(new Date().toISOString(), '[info]', ...a),
  warn: (...a) => console.warn(new Date().toISOString(), '[warn]', ...a),
  error: (...a) => console.error(new Date().toISOString(), '[error]', ...a),
};

const eco = createEconomy({ dbPath: config.databasePath, timeZone: config.timeZone, logger: log });
const ids = createResolver(config.idsFile);
// GuildMembers is a privileged intent: switch on "Server Members Intent" in the Developer Portal.
const client = new Client({ intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMembers] });

const ctx = { eco, config, ids, client, log };

// ---------------------------------------------------------------- helpers used by commands

async function fetchChannel(key) {
  const id = ids.channel(key);
  if (!id) return null;
  return client.channels.fetch(id).catch(() => null);
}

// Posts a message to a blueprint channel. Forum channels get a new post with `title`.
ctx.notify = async (key, content, { title = null, embeds = undefined } = {}) => {
  try {
    const channel = await fetchChannel(key);
    if (!channel) return null;
    const message = { content: content ?? undefined, embeds, allowedMentions: { parse: [] } };
    if (channel.type === ChannelType.GuildForum) {
      return await channel.threads.create({ name: (title ?? String(content).slice(0, 90)).slice(0, 100), message });
    }
    return await channel.send(message);
  } catch (err) {
    log.warn(`Could not post to #${key}:`, err.message);
    return null;
  }
};

// Best-effort direct message (members can block DMs; that is not an error).
ctx.dm = async (userId, content) => {
  try {
    const u = await client.users.fetch(userId);
    await u.send({ content, allowedMentions: { parse: [] } });
  } catch {
    // DMs closed - the information is also available through the bot's commands.
  }
};

// Gives or removes the automatic Business Owner / Business Employee roles.
ctx.syncRoles = (userIds) => {
  syncBusinessRoles(userIds).catch((err) => log.warn('Role sync failed:', err.message));
};

async function syncBusinessRoles(userIds) {
  const guild = await client.guilds.fetch(config.guildId);
  const ownerRole = ids.role('business_owner');
  const employeeRole = ids.role('business_employee');
  for (const userId of new Set(userIds)) {
    const member = await guild.members.fetch(userId).catch(() => null);
    if (!member) continue;
    const owns = !!eco.db.prepare("SELECT 1 FROM businesses WHERE owner_id = ? AND status IN ('active','suspended')").get(userId);
    const employed = !!eco.db.prepare(`SELECT 1 FROM employments e JOIN jobs j ON j.id = e.job_id JOIN businesses b ON b.id = j.business_id
      WHERE e.user_id = ? AND e.status = 'active' AND b.status IN ('active','suspended')`).get(userId);
    for (const [roleId, want] of [[ownerRole, owns], [employeeRole, employed]]) {
      if (!roleId) continue;
      const has = member.roles.cache.has(roleId);
      if (want && !has) await member.roles.add(roleId, 'Economy: business status');
      if (!want && has) await member.roles.remove(roleId, 'Economy: business status');
    }
  }
}

async function alert(text) {
  log.warn('ALERT', text);
  await ctx.notify('bot_alerts', text.slice(0, 1900));
}

// ---------------------------------------------------------------- scheduler

let running = false;
let failureStreak = 0;
let nextTickAttempt = 0;
let lastGraduationRun = 0;

async function runScheduler() {
  if (running) return;
  running = true;
  try {
    await runTicks();
    await publishReports();
    await mirrorAudit();
    if (Date.now() - lastGraduationRun > 10 * 60_000) {
      lastGraduationRun = Date.now();
      await graduateNewMembers();
    }
  } catch (err) {
    log.error('Scheduler error:', err);
  } finally {
    running = false;
  }
}
ctx.runScheduler = async () => {
  nextTickAttempt = 0; // a manual run skips the retry wait
  while (running) await new Promise((r) => setTimeout(r, 200));
  await runScheduler();
};

async function runTicks() {
  if (eco.currentDay() <= lastCompletedDay(eco) + 1) return; // nothing has ended yet
  if (Date.now() < nextTickAttempt) return;
  const day = lastCompletedDay(eco) + 1;
  try {
    const processed = catchUp(eco, { publishAll: config.catchUpPublishAll });
    if (processed.length) {
      log.info(`Processed economic day(s): ${processed.join(', ')}`);
      try {
        backupDatabase(eco.db, config.backupDir, `day-${String(processed.at(-1)).padStart(5, '0')}`, config.backupKeep);
      } catch (err) {
        await alert(`Backup after day ${processed.at(-1)} failed: ${err.message}`);
      }
      if (processed.length > 1) await alert(`Catch-up after downtime: processed economic days ${processed[0]}-${processed.at(-1)}. Only the newest report is published${config.catchUpPublishAll ? ' (CATCHUP_PUBLISH_ALL is on: all reports are published)' : ''}.`);
    }
    if (failureStreak) await alert(`Daily processing recovered after ${failureStreak} failed attempt(s).`);
    failureStreak = 0;
  } catch (err) {
    failureStreak += 1;
    recordTickFailure(eco, day, err);
    // Retry with exponential backoff: 1, 2, 4 ... up to 30 minutes. Nothing of the failed day was saved.
    const waitMinutes = Math.min(30, 2 ** (failureStreak - 1));
    nextTickAttempt = Date.now() + waitMinutes * 60_000;
    log.error(`Economic day ${day} failed (attempt ${failureStreak}):`, err);
    if (failureStreak === 1 || failureStreak % 5 === 0) {
      await alert(`Economic day ${day} could not be processed (attempt ${failureStreak}). No partial changes were saved. Next attempt in ${waitMinutes} minute(s). Error: ${String(err.message).slice(0, 500)}`);
    }
  }
}

async function publishReports() {
  for (const r of unpublishedReports(eco)) {
    if (r.publish_attempts >= 10) continue; // give up automatically; staff can read it with /economy history
    try {
      const channel = await fetchChannel('national_economic_report');
      if (!channel) throw new Error('Channel #national-economic-report not found');
      const report = JSON.parse(r.content);
      let first = null;
      for (const group of reportToEmbeds(report)) {
        const msg = await channel.send({ embeds: group, allowedMentions: { parse: [] } });
        first ??= msg;
      }
      markReportPublished(eco, r.day, { channelId: channel.id, messageId: first.id });
      const snapshot = getSnapshot(eco, r.day);
      if (snapshot) await ctx.notify('commodity_markets', null, { embeds: [marketBoardEmbed(snapshot)] });
      log.info(`Published report for economic day ${r.day}`);
    } catch (err) {
      markReportFailed(eco, r.day, err.message);
      log.warn(`Publishing report ${r.day} failed:`, err.message);
      if (r.publish_attempts === 0) await alert(`Report for economic day ${r.day} could not be published: ${err.message}. It is stored and will be retried.`);
    }
  }
}

async function mirrorAudit() {
  const channel = await fetchChannel('economy_audit_log');
  if (!channel) return;
  for (const a of unmirroredAudit(eco, 20)) {
    const who = a.actor_id === 'system' ? 'system' : `<@${a.actor_id}>`;
    const line = `\`#${a.id}\` day ${a.econ_day} · ${who} · **${a.action}**${a.target ? ` · ${a.target}` : ''}${a.amount !== null ? ` · ${formatKGD(a.amount)}` : ''}`
      + `${a.old_value !== null || a.new_value !== null ? ` · ${a.old_value ?? '-'} → ${a.new_value ?? '-'}` : ''}${a.reason ? ` · reason: ${a.reason}` : ''}`;
    try {
      await channel.send({ content: line.slice(0, 1900), allowedMentions: { parse: [] } });
      markMirrored(eco, a.id);
    } catch (err) {
      log.warn('Audit mirror failed:', err.message);
      return;
    }
  }
}

// New Member → Community Member after NEW_MEMBER_DAYS.
async function graduateNewMembers() {
  const cutoff = new Date(Date.now() - config.newMemberDays * 86_400_000).toISOString();
  const rows = eco.db.prepare('SELECT user_id FROM member_verifications WHERE graduated_at IS NULL AND verified_at <= ?').all(cutoff);
  if (!rows.length) return;
  const guild = await client.guilds.fetch(config.guildId);
  const newRole = ids.role('new_member');
  const communityRole = ids.role('community_member');
  for (const { user_id: userId } of rows) {
    const member = await guild.members.fetch(userId).catch(() => null);
    if (member && !member.roles.cache.has(ids.role('restricted'))) {
      if (newRole && member.roles.cache.has(newRole)) await member.roles.remove(newRole, 'New member period over');
      if (communityRole && !member.roles.cache.has(communityRole)) await member.roles.add(communityRole, 'New member period over');
    }
    eco.db.prepare('UPDATE member_verifications SET graduated_at = ? WHERE user_id = ?').run(new Date().toISOString(), userId);
  }
}

// ---------------------------------------------------------------- interactions

const cooldowns = new Map();

function onCooldown(userId) {
  const now = Date.now();
  const until = cooldowns.get(userId) ?? 0;
  if (until > now) return true;
  cooldowns.set(userId, now + config.commandCooldownSeconds * 1000);
  if (cooldowns.size > 5000) for (const [k, v] of cooldowns) if (v < now) cooldowns.delete(k);
  return false;
}

async function sendError(interaction, text) {
  const payload = { embeds: [embed({ title: 'Not possible', description: text, color: COLORS.error })], flags: MessageFlags.Ephemeral, allowedMentions: { parse: [] } };
  try {
    if (interaction.deferred || interaction.replied) await interaction.followUp(payload);
    else await interaction.reply(payload);
  } catch (err) {
    log.warn('Could not send error reply:', err.message);
  }
}

client.on(Events.InteractionCreate, async (interaction) => {
  if (interaction.guildId && interaction.guildId !== config.guildId) return; // single-server bot
  try {
    if (interaction.isAutocomplete()) {
      const cmd = COMMAND_BY_NAME.get(interaction.commandName);
      const choices = cmd?.autocomplete ? await cmd.autocomplete(ctx, interaction) : [];
      return await interaction.respond((choices ?? []).slice(0, 25));
    }
    if (interaction.isChatInputCommand()) {
      const cmd = COMMAND_BY_NAME.get(interaction.commandName);
      if (!cmd) return await sendError(interaction, 'Unknown command. The command list may be outdated.');
      if (onCooldown(interaction.user.id)) return await sendError(interaction, `Please wait ${config.commandCooldownSeconds} seconds between commands.`);
      return await cmd.execute(ctx, interaction);
    }
    if (interaction.isButton()) {
      if (onCooldown(interaction.user.id)) return await sendError(interaction, 'Please wait a moment and try again.');
      return await handleButton(ctx, interaction);
    }
  } catch (err) {
    if (interaction.isAutocomplete()) {
      return interaction.respond([]).catch(() => null);
    }
    if (err instanceof UserError) return sendError(interaction, err.message);
    log.error(`Interaction ${interaction.commandName ?? interaction.customId} failed:`, err);
    await sendError(interaction, 'Something went wrong. Nothing was changed. The team has been notified.');
    await alert(`Error in ${interaction.isChatInputCommand?.() ? `/${interaction.commandName}` : interaction.customId ?? 'interaction'} (user ${interaction.user.id}): ${String(err.message).slice(0, 500)}`);
  }
});

client.once(Events.ClientReady, async () => {
  log.info(`Logged in as ${client.user.tag}. Economic day ${eco.currentDay()} (${config.timeZone}), last completed ${lastCompletedDay(eco)}.`);
  const guild = await client.guilds.fetch(config.guildId);
  const found = await ids.refresh(guild);
  log.info(`Server mapping: ${found.roles} roles, ${found.channels} channels, ${found.categories} categories.`);
  const missingRoles = ids.missingRoles();
  const missingChannels = ids.missingChannels();
  if (missingRoles.length || missingChannels.length) {
    log.warn(`Missing roles: ${missingRoles.join(', ') || 'none'}. Missing channels: ${missingChannels.join(', ') || 'none'}. Run "npm run setup-server" (dry run first).`);
  }
  await runScheduler();
  setInterval(runScheduler, config.schedulerIntervalSeconds * 1000).unref?.();
});

// Re-read role and channel IDs when the server structure changes.
let refreshTimer = null;
const scheduleRefresh = () => {
  clearTimeout(refreshTimer);
  refreshTimer = setTimeout(async () => {
    const guild = await client.guilds.fetch(config.guildId).catch(() => null);
    if (guild) await ids.refresh(guild).catch((err) => log.warn('ID refresh failed:', err.message));
  }, 5000);
};
for (const ev of [Events.GuildRoleCreate, Events.GuildRoleDelete, Events.GuildRoleUpdate, Events.ChannelCreate, Events.ChannelDelete, Events.ChannelUpdate]) {
  client.on(ev, scheduleRefresh);
}

client.on(Events.Error, (err) => log.error('Discord client error:', err));

function shutdown(signal) {
  log.info(`${signal} received, shutting down.`);
  client.destroy().catch(() => null).finally(() => {
    try { eco.close(); } catch { /* already closed */ }
    process.exit(0);
  });
}
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('unhandledRejection', (err) => log.error('Unhandled promise rejection:', err));

client.login(config.token).catch((err) => {
  if (String(err.message).includes('disallowed intents')) {
    log.error('Login failed: enable "Server Members Intent" for the bot in the Discord Developer Portal (Bot → Privileged Gateway Intents).');
  } else {
    log.error('Login failed:', err.message);
  }
  process.exit(1);
});
