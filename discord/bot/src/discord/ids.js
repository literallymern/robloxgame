// Maps blueprint keys (e.g. 'city_police', 'national_economic_report') to real Discord IDs.
// IDs come from data/guild-ids.json (written by the setup script). Anything missing there is
// looked up by its exact name, so a server built by hand works too.
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { ROLES } from '../blueprint/roles.js';
import { CHANNELS, CATEGORIES } from '../blueprint/channels.js';

export function loadIdsFile(file) {
  if (!existsSync(file)) return { roles: {}, channels: {}, categories: {} };
  const data = JSON.parse(readFileSync(file, 'utf8'));
  return { roles: data.roles ?? {}, channels: data.channels ?? {}, categories: data.categories ?? {} };
}

export function saveIdsFile(file, ids) {
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, `${JSON.stringify(ids, null, 2)}\n`);
}

export function createResolver(file) {
  let roles = {};
  let channels = {};
  let categories = {};
  let roleKeyById = new Map();
  return {
    // Call after the client is ready (and again after changes to the server).
    async refresh(guild) {
      const saved = loadIdsFile(file);
      await guild.roles.fetch();
      await guild.channels.fetch();
      roles = {};
      for (const r of ROLES) {
        const byId = saved.roles[r.key] && guild.roles.cache.get(saved.roles[r.key]);
        const byName = guild.roles.cache.find((x) => x.name === r.name);
        const role = byId ?? byName;
        if (role) roles[r.key] = role.id;
      }
      channels = {};
      for (const c of CHANNELS) {
        const byId = saved.channels[c.key] && guild.channels.cache.get(saved.channels[c.key]);
        const byName = guild.channels.cache.find((x) => x.name === c.name && !x.isThread?.());
        const ch = byId ?? byName;
        if (ch) channels[c.key] = ch.id;
      }
      categories = {};
      for (const c of CATEGORIES) {
        const byId = saved.categories[c.key] && guild.channels.cache.get(saved.categories[c.key]);
        const byName = guild.channels.cache.find((x) => x.type === 4 && x.name === c.name);
        const cat = byId ?? byName;
        if (cat) categories[c.key] = cat.id;
      }
      roleKeyById = new Map(Object.entries(roles).map(([k, id]) => [id, k]));
      return { roles: Object.keys(roles).length, channels: Object.keys(channels).length, categories: Object.keys(categories).length };
    },
    role: (key) => roles[key] ?? null,
    channel: (key) => channels[key] ?? null,
    category: (key) => categories[key] ?? null,
    keyOfRole: (id) => roleKeyById.get(id) ?? null,
    missingRoles: () => ROLES.filter((r) => !roles[r.key]).map((r) => r.key),
    missingChannels: () => CHANNELS.filter((c) => !channels[c.key]).map((c) => c.key),
    // For tests
    _set(next) {
      roles = next.roles ?? {};
      channels = next.channels ?? {};
      categories = next.categories ?? {};
      roleKeyById = new Map(Object.entries(roles).map(([k, id]) => [id, k]));
    },
  };
}
