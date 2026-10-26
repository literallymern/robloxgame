// Compares the blueprint with the current state of a Discord server and lists the changes needed.
// Pure functions without Discord calls, so the plan can be tested offline.
//
// Safety rules:
// - Nothing is ever deleted. Roles and channels that are not in the blueprint are only listed.
// - Existing roles and channels (matched by saved ID or exact name) are only changed when
//   syncExisting is true. Otherwise differences are reported.
import { ROLES, EVERYONE_PERMISSIONS } from '../blueprint/roles.js';
import { compiledBlueprint, BOT, EVERYONE } from '../blueprint/compile.js';

const COMMUNITY_TYPES = new Set(['announcement', 'forum']);

const sameSet = (a, b) => a.length === b.length && [...a].sort().join() === [...b].sort().join();
const hex = (color) => (color ? parseInt(color.replace('#', ''), 16) : 0);

// state = {
//   guildId, community: boolean, botUserId, botHasAdministrator: boolean,
//   everyonePermissions: string[],
//   roles: [{ id, name, permissions: string[], color: number, hoist, mentionable, managed }],
//   channels: [{ id, name, type: 'category'|'text'|'announcement'|'forum'|'voice'|'other', parentId, topic,
//                overwrites: [{ id, type: 'role'|'member', allow: string[], deny: string[] }] }],
//   saved: { roles: {}, channels: {}, categories: {} }   // data/guild-ids.json
// }
export function planSetup(state, { syncExisting = false } = {}) {
  const plan = { roles: [], everyone: null, categories: [], channels: [], extras: { roles: [], channels: [] }, warnings: [], manual: [] };
  const saved = state.saved ?? { roles: {}, channels: {}, categories: {} };

  // ---- roles
  const roleIdByKey = {};
  for (const r of ROLES) {
    const existing = state.roles.find((x) => x.id === saved.roles?.[r.key]) ?? state.roles.find((x) => x.name === r.name && !x.managed);
    const desired = { name: r.name, permissions: r.permissions, color: hex(r.color), hoist: r.hoist, mentionable: r.mentionable };
    if (!existing) {
      plan.roles.push({ key: r.key, action: 'create', desired });
      roleIdByKey[r.key] = `<new:${r.key}>`;
      continue;
    }
    roleIdByKey[r.key] = existing.id;
    const changes = [];
    if (!sameSet(existing.permissions, r.permissions)) changes.push(`permissions: [${existing.permissions.join(', ') || 'none'}] → [${r.permissions.join(', ') || 'none'}]`);
    if (existing.color !== desired.color) changes.push(`colour ${existing.color.toString(16)} → ${desired.color.toString(16)}`);
    if (!!existing.hoist !== r.hoist) changes.push(`shown separately: ${existing.hoist} → ${r.hoist}`);
    if (!!existing.mentionable !== r.mentionable) changes.push(`mentionable: ${existing.mentionable} → ${r.mentionable}`);
    plan.roles.push({ key: r.key, id: existing.id, action: changes.length ? (syncExisting ? 'update' : 'differs') : 'ok', desired, changes });
  }
  const blueprintRoleIds = new Set(Object.values(roleIdByKey));
  plan.extras.roles = state.roles.filter((x) => !x.managed && x.id !== state.guildId && !blueprintRoleIds.has(x.id)).map((x) => x.name);

  if (!sameSet(state.everyonePermissions, EVERYONE_PERMISSIONS)) {
    plan.everyone = { action: syncExisting ? 'update' : 'differs', from: state.everyonePermissions, to: EVERYONE_PERMISSIONS };
  }

  // ---- overwrites with real IDs
  const resolve = (overwrites) => overwrites.map((o) => {
    if (o.target === EVERYONE) return { id: state.guildId, type: 'role', allow: o.allow, deny: o.deny, label: '@everyone' };
    if (o.target === BOT) return { id: state.botUserId, type: 'member', allow: o.allow, deny: o.deny, label: 'economy bot' };
    return { id: roleIdByKey[o.target], type: 'role', allow: o.allow, deny: o.deny, label: o.target };
  });
  const overwritesDiffer = (current, desired) => {
    if (current.length !== desired.length) return true;
    return desired.some((d) => {
      const c = current.find((x) => x.id === d.id);
      return !c || !sameSet(c.allow, d.allow) || !sameSet(c.deny, d.deny);
    });
  };

  // ---- categories and channels
  const blueprint = compiledBlueprint();
  const usedChannelIds = new Set();
  for (const cat of blueprint) {
    const existingCat = state.channels.find((x) => x.id === saved.categories?.[cat.key] && x.type === 'category')
      ?? state.channels.find((x) => x.type === 'category' && x.name === cat.name);
    const catOverwrites = resolve(cat.overwrites);
    let catId;
    if (!existingCat) {
      plan.categories.push({ key: cat.key, action: 'create', name: cat.name, overwrites: catOverwrites });
      catId = `<new:${cat.key}>`;
    } else {
      catId = existingCat.id;
      usedChannelIds.add(existingCat.id);
      const differs = overwritesDiffer(existingCat.overwrites, catOverwrites);
      plan.categories.push({ key: cat.key, id: existingCat.id, name: cat.name, action: differs ? (syncExisting ? 'update' : 'differs') : 'ok', overwrites: catOverwrites, changes: differs ? ['permission overwrites'] : [] });
    }
    for (const ch of cat.channels) {
      let type = ch.type;
      if (COMMUNITY_TYPES.has(type) && !state.community) {
        plan.warnings.push(`#${ch.name} should be a ${type} channel, but the server has no Community features. It is created as a text channel. Enable Community (Server Settings → Enable Community) before running the setup to get ${type} channels.`);
        type = 'text';
      }
      const existing = state.channels.find((x) => x.id === saved.channels?.[ch.key]) ?? state.channels.find((x) => x.type !== 'category' && x.name === ch.name);
      const overwrites = resolve(ch.overwrites);
      if (!existing) {
        plan.channels.push({ key: ch.key, action: 'create', name: ch.name, type, parentKey: cat.key, parentId: catId, topic: ch.topic ?? null, overwrites });
        continue;
      }
      usedChannelIds.add(existing.id);
      const changes = [];
      if (existing.parentId !== catId) changes.push(`move into ${cat.name}`);
      if (type !== 'voice' && (existing.topic ?? null) !== (ch.topic ?? null)) changes.push('topic');
      if (overwritesDiffer(existing.overwrites, overwrites)) changes.push('permission overwrites');
      if (existing.type !== type && !(existing.type === 'text' && type === 'announcement')) {
        plan.warnings.push(`#${ch.name} exists as a ${existing.type} channel but the blueprint expects ${type}. Channel types cannot be changed automatically; recreate it by hand if needed.`);
      }
      plan.channels.push({ key: ch.key, id: existing.id, action: changes.length ? (syncExisting ? 'update' : 'differs') : 'ok', name: ch.name, type, parentKey: cat.key, parentId: catId, topic: ch.topic ?? null, overwrites, changes });
    }
  }
  plan.extras.channels = state.channels.filter((x) => !usedChannelIds.has(x.id)).map((x) => `${x.type === 'category' ? '[category] ' : '#'}${x.name}`);

  // ---- warnings and manual steps
  // Only relevant when there is something to apply: after the setup the bot runs without Administrator.
  const pending = [...plan.roles, ...plan.categories, ...plan.channels, plan.everyone].some((x) => x && ['create', 'update'].includes(x.action));
  if (!state.botHasAdministrator && pending) {
    plan.warnings.push('The bot does not have the Administrator permission. Discord only lets a bot grant permissions it has itself, so creating staff roles and channel permissions will fail. Give the bot role Administrator for the setup run and remove it afterwards (see docs/07-setup-guide.md).');
  }
  plan.manual.push('Server Settings → Roles: drag the bot\'s own role so it sits directly below "Economic Administrator" and above "Leader of the Revolution". The bot can then manage department, community and business roles, but never staff roles.');
  plan.manual.push('Remove the Administrator permission from the bot role again. Keep only: View Channels, Send Messages, Send Messages in Threads, Embed Links, Attach Files, Read Message History, Manage Roles. (Ticket channels work through the TICKETS category permissions.)');
  plan.manual.push('Assign the Owner role to yourself. The bot never assigns staff roles.');
  if (plan.extras.channels.length) plan.manual.push(`Channels not in the blueprint were left untouched: ${plan.extras.channels.join(', ')}. Delete them yourself if you do not need them.`);
  if (plan.extras.roles.length) plan.manual.push(`Roles not in the blueprint were left untouched: ${plan.extras.roles.join(', ')}.`);
  return plan;
}

export function summarizePlan(plan) {
  const count = (list, action) => list.filter((x) => x.action === action).length;
  const lines = [];
  lines.push(`Roles: ${count(plan.roles, 'create')} to create, ${count(plan.roles, 'update')} to update, ${count(plan.roles, 'differs')} differ (not changed), ${count(plan.roles, 'ok')} already correct.`);
  lines.push(`Categories: ${count(plan.categories, 'create')} to create, ${count(plan.categories, 'update')} to update, ${count(plan.categories, 'differs')} differ, ${count(plan.categories, 'ok')} correct.`);
  lines.push(`Channels: ${count(plan.channels, 'create')} to create, ${count(plan.channels, 'update')} to update, ${count(plan.channels, 'differs')} differ, ${count(plan.channels, 'ok')} correct.`);
  if (plan.everyone) lines.push(`@everyone permissions: ${plan.everyone.action === 'update' ? 'will be set' : 'differ (not changed)'} [${plan.everyone.from.join(', ') || 'none'}] → [${plan.everyone.to.join(', ') || 'none'}]`);
  for (const r of plan.roles.filter((x) => x.action !== 'ok')) lines.push(`  role ${r.action}: ${r.desired.name}${r.changes?.length ? ` (${r.changes.join('; ')})` : ''}`);
  for (const c of plan.categories.filter((x) => x.action !== 'ok')) lines.push(`  category ${c.action}: ${c.name}`);
  for (const c of plan.channels.filter((x) => x.action !== 'ok')) lines.push(`  channel ${c.action}: #${c.name} (${c.type})${c.changes?.length ? ` (${c.changes.join(', ')})` : ''}`);
  if (plan.warnings.length) lines.push('', 'Warnings:', ...plan.warnings.map((w) => `  - ${w}`));
  lines.push('', 'Manual steps after the setup:', ...plan.manual.map((m, i) => `  ${i + 1}. ${m}`));
  return lines.join('\n');
}
