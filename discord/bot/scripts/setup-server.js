// Builds the Ro-Nation server structure (roles, categories, channels, permissions) from the blueprint.
//
//   npm run setup-server                       dry run: shows what would change, changes nothing
//   npm run setup-server -- --apply            creates missing roles, categories and channels
//   npm run setup-server -- --apply --sync-existing
//                                              also updates existing roles/channels with the same
//                                              name to match the blueprint (recommended on a new server)
//
// The script never deletes anything. It writes the IDs it finds or creates to data/guild-ids.json.
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { Client, Events, GatewayIntentBits, ChannelType, OverwriteType, PermissionsBitField, PermissionFlagsBits } from 'discord.js';
import { config, requireDiscordConfig } from '../src/config.js';
import { ROLES } from '../src/blueprint/roles.js';
import { loadIdsFile, saveIdsFile } from '../src/discord/ids.js';
import { planSetup, summarizePlan } from '../src/setup/plan.js';

const args = new Set(process.argv.slice(2));
const APPLY = args.has('--apply');
const SYNC = args.has('--sync-existing');

const TYPE_TO_DISCORD = { text: ChannelType.GuildText, announcement: ChannelType.GuildAnnouncement, forum: ChannelType.GuildForum, voice: ChannelType.GuildVoice };
const DISCORD_TO_TYPE = {
  [ChannelType.GuildCategory]: 'category', [ChannelType.GuildText]: 'text', [ChannelType.GuildAnnouncement]: 'announcement',
  [ChannelType.GuildForum]: 'forum', [ChannelType.GuildVoice]: 'voice',
};
const flags = (names) => names.map((n) => PermissionFlagsBits[n]);
const names = (bitfield) => new PermissionsBitField(bitfield).toArray();

function snapshot(guild, me, saved) {
  return {
    guildId: guild.id,
    community: guild.features.includes('COMMUNITY'),
    botUserId: me.id,
    botHasAdministrator: me.permissions.has(PermissionFlagsBits.Administrator),
    everyonePermissions: guild.roles.everyone.permissions.toArray(),
    roles: [...guild.roles.cache.values()].filter((r) => r.id !== guild.id).map((r) => ({
      id: r.id, name: r.name, permissions: r.permissions.toArray(), color: r.color, hoist: r.hoist, mentionable: r.mentionable, managed: r.managed,
    })),
    channels: [...guild.channels.cache.values()].filter((c) => !c.isThread()).map((c) => ({
      id: c.id, name: c.name, type: DISCORD_TO_TYPE[c.type] ?? 'other', parentId: c.parentId ?? null, topic: c.topic ?? null,
      overwrites: [...(c.permissionOverwrites?.cache.values() ?? [])].map((o) => ({
        id: o.id, type: o.type === OverwriteType.Member ? 'member' : 'role', allow: names(o.allow), deny: names(o.deny),
      })),
    })),
    saved,
  };
}

const toDiscordOverwrites = (overwrites, idMap) => overwrites.map((o) => ({
  id: idMap(o.id),
  type: o.type === 'member' ? OverwriteType.Member : OverwriteType.Role,
  allow: flags(o.allow),
  deny: flags(o.deny),
}));

async function main() {
  requireDiscordConfig();
  const client = new Client({ intents: [GatewayIntentBits.Guilds] });
  await client.login(config.token);
  await new Promise((resolve) => (client.isReady() ? resolve() : client.once(Events.ClientReady, resolve)));
  try {
    const guild = await client.guilds.fetch(config.guildId);
    await guild.roles.fetch();
    await guild.channels.fetch();
    const me = await guild.members.fetchMe();
    const saved = loadIdsFile(config.idsFile);
    const plan = planSetup(snapshot(guild, me, saved), { syncExisting: SYNC });

    console.log(`Server: ${guild.name} (${guild.id}) · Community features: ${guild.features.includes('COMMUNITY') ? 'yes' : 'no'}`);
    console.log(APPLY ? `Mode: APPLY${SYNC ? ' + SYNC EXISTING' : ''}` : 'Mode: DRY RUN (nothing is changed; add --apply to make the changes)');
    console.log('');
    console.log(summarizePlan(plan));
    mkdirSync(join(config.root, 'data'), { recursive: true });
    const report = join(config.root, 'data', `setup-plan-${new Date().toISOString().replace(/[:.]/g, '-')}.txt`);
    writeFileSync(report, summarizePlan(plan));
    console.log(`\nPlan saved to ${report}`);

    if (!APPLY) {
      await client.destroy();
      return;
    }
    if (!me.permissions.has(PermissionFlagsBits.Administrator)) {
      throw new Error('The bot needs the Administrator permission while the setup runs (see the warning above). Nothing was changed.');
    }

    const ids = { roles: {}, channels: {}, categories: {} };
    const newIds = new Map();
    const realId = (id) => (typeof id === 'string' && id.startsWith('<new:') ? newIds.get(id) : id);

    // Roles: create top to bottom (new roles appear at the bottom), then fix the order.
    for (const r of plan.roles) {
      if (r.action === 'create') {
        const role = await guild.roles.create({ name: r.desired.name, permissions: flags(r.desired.permissions), color: r.desired.color, hoist: r.desired.hoist,
          mentionable: r.desired.mentionable, reason: 'Ro-Nation setup' });
        newIds.set(`<new:${r.key}>`, role.id);
        ids.roles[r.key] = role.id;
        console.log(`created role ${role.name}`);
      } else {
        ids.roles[r.key] = r.id;
        if (r.action === 'update') {
          await guild.roles.edit(r.id, { permissions: flags(r.desired.permissions), color: r.desired.color, hoist: r.desired.hoist, mentionable: r.desired.mentionable, reason: 'Ro-Nation setup (sync)' });
          console.log(`updated role ${r.desired.name}`);
        }
      }
    }
    // Order: blueprint order directly below the bot's highest role. A bot can only move roles below
    // its own role, so roles above it (e.g. staff roles after the bot role was moved down) stay put.
    await guild.roles.fetch(); // positions moved while roles were created
    const top = (await guild.members.fetchMe({ force: true })).roles.highest.position;
    const movable = ROLES.filter((r) => (guild.roles.cache.get(ids.roles[r.key])?.position ?? Infinity) < top);
    if (movable.length < ROLES.length) console.warn(`${ROLES.length - movable.length} role(s) are above the bot's role and were not reordered.`);
    const positions = movable.map((r, i) => ({ role: ids.roles[r.key], position: Math.max(1, top - 1 - i) }));
    if (positions.length) {
      await guild.roles.setPositions(positions).catch((err) => console.warn(`Could not reorder roles automatically (${err.message}). Please order them by hand as listed in docs/02-role-hierarchy.md.`));
    }

    if (plan.everyone?.action === 'update') {
      await guild.roles.everyone.setPermissions(flags(plan.everyone.to), 'Ro-Nation setup: least privilege for unverified members');
      console.log('set @everyone permissions');
    }

    // Categories and channels in blueprint order.
    let catPosition = 0;
    for (const cat of plan.categories) {
      let id = cat.id;
      if (cat.action === 'create') {
        const created = await guild.channels.create({ name: cat.name, type: ChannelType.GuildCategory, permissionOverwrites: toDiscordOverwrites(cat.overwrites, realId), reason: 'Ro-Nation setup' });
        id = created.id;
        newIds.set(`<new:${cat.key}>`, id);
        console.log(`created category ${cat.name}`);
      } else if (cat.action === 'update') {
        await guild.channels.edit(id, { permissionOverwrites: toDiscordOverwrites(cat.overwrites, realId), reason: 'Ro-Nation setup (sync)' });
        console.log(`updated category ${cat.name}`);
      }
      ids.categories[cat.key] = id;
      await guild.channels.setPosition(id, catPosition++).catch(() => null);
      let chPosition = 0;
      for (const ch of plan.channels.filter((c) => c.parentKey === cat.key)) {
        const options = {
          parent: id,
          permissionOverwrites: toDiscordOverwrites(ch.overwrites, realId),
          ...(ch.type !== 'voice' && ch.topic ? { topic: ch.topic } : {}),
        };
        let chId = ch.id;
        if (ch.action === 'create') {
          const created = await guild.channels.create({ name: ch.name, type: TYPE_TO_DISCORD[ch.type], ...options, reason: 'Ro-Nation setup' });
          chId = created.id;
          console.log(`created #${ch.name}`);
        } else if (ch.action === 'update') {
          await guild.channels.edit(chId, { ...options, lockPermissions: false, reason: 'Ro-Nation setup (sync)' });
          console.log(`updated #${ch.name}`);
        }
        ids.channels[ch.key] = chId;
        await guild.channels.setPosition(chId, chPosition++).catch(() => null);
      }
    }
    saveIdsFile(config.idsFile, ids);
    console.log(`\nDone. IDs saved to ${config.idsFile}. Now do the manual steps listed above.`);
  } finally {
    await client.destroy();
  }
}

main().catch((err) => {
  console.error(`Setup failed: ${err.message}`);
  console.error('Nothing is deleted by this script. Fix the problem and run it again; existing items are reused.');
  process.exit(1);
});

