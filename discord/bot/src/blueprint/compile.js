// Turns the channel blueprint into concrete Discord permission overwrites, and simulates Discord's
// permission calculation so the setup can be verified offline (tests and generated permission matrix).
import { ROLES, ROLE_BY_KEY, EVERYONE_PERMISSIONS } from './roles.js';
import { CATEGORIES, CHANNELS } from './channels.js';

export const BOT = '@bot';
export const EVERYONE = '@everyone';

// Permissions requested when inviting the bot. Manage Channels is only needed while running the
// setup script and for ticket channels (granted again on the TICKETS category itself).
export const BOT_PERMISSIONS = ['ViewChannel', 'SendMessages', 'SendMessagesInThreads', 'EmbedLinks', 'AttachFiles', 'ReadMessageHistory', 'ManageRoles', 'ManageChannels'];
export const BOT_PERMISSIONS_AFTER_SETUP = ['ViewChannel', 'SendMessages', 'SendMessagesInThreads', 'EmbedLinks', 'AttachFiles', 'ReadMessageHistory', 'ManageRoles'];

const TEXT_VIEW = ['ViewChannel', 'ReadMessageHistory'];
const TEXT_WRITE = ['SendMessages', 'SendMessagesInThreads', 'AddReactions'];
const TEXT_READONLY_DENY = ['SendMessages', 'SendMessagesInThreads', 'CreatePublicThreads', 'CreatePrivateThreads'];
const VOICE_VIEW = ['ViewChannel', 'Connect'];
const VOICE_WRITE = ['Speak', 'UseVAD', 'Stream', 'SendMessages'];
const VOICE_READONLY_DENY = ['Speak', 'SendMessages'];
const BOT_TEXT = ['ViewChannel', 'ReadMessageHistory', 'SendMessages', 'EmbedLinks', 'AttachFiles'];

function builder() {
  const map = new Map();
  return {
    add(target, allow = [], deny = []) {
      const cur = map.get(target) ?? { target, allow: new Set(), deny: new Set() };
      allow.forEach((p) => cur.allow.add(p));
      deny.forEach((p) => cur.deny.add(p));
      map.set(target, cur);
    },
    build() {
      return [...map.values()].map((o) => {
        for (const p of o.allow) o.deny.delete(p); // an explicit allow for the same target wins
        return { target: o.target, allow: [...o.allow].sort(), deny: [...o.deny].sort() };
      });
    },
  };
}

export function compileChannel(ch) {
  const voice = ch.type === 'voice';
  const VIEW = voice ? VOICE_VIEW : TEXT_VIEW;
  const WRITE = voice ? VOICE_WRITE : TEXT_WRITE;
  const RO = voice ? VOICE_READONLY_DENY : TEXT_READONLY_DENY;
  const b = builder();
  const canPost = (key) => ch.post === 'all' || (Array.isArray(ch.post) && ch.post.includes(key));

  if (ch.view === 'everyone') {
    b.add(EVERYONE, VIEW, ch.post === 'all' ? [] : RO);
  } else {
    b.add(EVERYONE, [], ['ViewChannel']);
    const viewers = ch.view === 'verified' ? ['verified'] : ch.view;
    for (const key of viewers) b.add(key, canPost(key) ? [...VIEW, ...WRITE] : VIEW, canPost(key) ? [] : RO);
  }
  if (Array.isArray(ch.post)) for (const key of ch.post) b.add(key, [...VIEW, ...WRITE]);
  for (const key of ch.manage ?? []) b.add(key, voice ? ['MuteMembers', 'MoveMembers'] : ['ManageMessages', 'ManageThreads']);
  // Staff oversight
  b.add('administrator', [...VIEW, ...WRITE, ...(voice ? ['MuteMembers', 'MoveMembers'] : ['ManageMessages', 'ManageThreads'])]);
  const publicChannel = ch.view === 'everyone' || ch.view === 'verified' || (Array.isArray(ch.view) && ch.view.includes('verified'));
  if (publicChannel) b.add('moderator', VIEW);
  if (ch.bot && !voice) b.add(BOT, BOT_TEXT);
  return b.build();
}

export function compileCategory(cat) {
  const b = builder();
  if (cat.tickets) {
    b.add(EVERYONE, [], ['ViewChannel']);
    b.add('administrator', [...TEXT_VIEW, ...TEXT_WRITE, 'ManageMessages', 'ManageChannels']);
    b.add(BOT, [...BOT_TEXT, 'ManageChannels', 'ManageRoles', 'ManageMessages']);
    return b.build();
  }
  const views = new Set(cat.channels.map((c) => (Array.isArray(c.view) ? 'roles' : c.view)));
  if (views.size === 1 && views.has('everyone')) {
    b.add(EVERYONE, TEXT_VIEW, TEXT_READONLY_DENY);
  } else if (views.size === 1 && views.has('verified')) {
    b.add(EVERYONE, [], ['ViewChannel']);
    b.add('verified', TEXT_VIEW);
    b.add('moderator', TEXT_VIEW);
  } else {
    b.add(EVERYONE, [], ['ViewChannel']);
  }
  b.add('administrator', [...TEXT_VIEW, ...TEXT_WRITE]);
  return b.build();
}

// Overwrites for a single ticket channel.
export function compileTicket({ reviewers }) {
  const b = builder();
  b.add(EVERYONE, [], ['ViewChannel']);
  b.add('@applicant', [...TEXT_VIEW, 'SendMessages', 'AttachFiles', 'EmbedLinks']);
  for (const key of reviewers) b.add(key, [...TEXT_VIEW, 'SendMessages', 'AttachFiles', 'EmbedLinks']);
  b.add('administrator', [...TEXT_VIEW, 'SendMessages', 'ManageMessages']);
  b.add(BOT, [...BOT_TEXT, 'ManageChannels', 'ManageRoles', 'ManageMessages']);
  return b.build();
}

export function compiledBlueprint() {
  return CATEGORIES.map((cat) => ({
    ...cat,
    overwrites: compileCategory(cat),
    channels: cat.channels.map((ch) => ({ ...ch, type: ch.type ?? 'text', overwrites: compileChannel({ ...ch, type: ch.type ?? 'text' }) })),
  }));
}

// ---------- Permission simulator (mirrors Discord's documented algorithm) ----------

export function basePermissions(roleKeys) {
  const set = new Set(EVERYONE_PERMISSIONS);
  for (const key of roleKeys) {
    if (key === BOT) BOT_PERMISSIONS_AFTER_SETUP.forEach((p) => set.add(p));
    else (ROLE_BY_KEY[key]?.permissions ?? []).forEach((p) => set.add(p));
  }
  return set;
}

export function effectivePermissions(roleKeys, overwrites, { type = 'text' } = {}) {
  const base = basePermissions(roleKeys);
  if (base.has('Administrator')) return { all: true, has: () => true };
  const perms = new Set(base);
  const everyone = overwrites.find((o) => o.target === EVERYONE);
  if (everyone) {
    everyone.deny.forEach((p) => perms.delete(p));
    everyone.allow.forEach((p) => perms.add(p));
  }
  const mine = overwrites.filter((o) => roleKeys.includes(o.target));
  mine.flatMap((o) => o.deny).forEach((p) => perms.delete(p));
  mine.flatMap((o) => o.allow).forEach((p) => perms.add(p));
  if (!perms.has('ViewChannel')) perms.clear();
  if (type !== 'voice' && !perms.has('SendMessages')) ['MentionEveryone', 'SendTTSMessages', 'AttachFiles', 'EmbedLinks'].forEach((p) => perms.delete(p));
  if (type === 'voice' && !perms.has('Connect')) ['Speak', 'Stream', 'UseVAD', 'MuteMembers', 'DeafenMembers', 'MoveMembers'].forEach((p) => perms.delete(p));
  return { all: false, has: (p) => perms.has(p), list: [...perms].sort() };
}

// Typical members used to verify the setup and to build the permission matrix.
export const PERSONAS = [
  { key: 'unverified', label: 'Unverified newcomer (@everyone)', roles: [] },
  { key: 'restricted', label: 'Restricted Member', roles: ['restricted'] },
  { key: 'new_member', label: 'New Member (first 7 days)', roles: ['verified', 'new_member', 'civilian'] },
  { key: 'civilian', label: 'Verified civilian', roles: ['verified', 'community_member', 'civilian'] },
  { key: 'business_owner', label: 'Business owner', roles: ['verified', 'community_member', 'civilian', 'business_owner'] },
  { key: 'police_officer', label: 'Department member (City Police)', roles: ['verified', 'community_member', 'city_police'] },
  { key: 'police_command', label: 'Department leader (City Police Command)', roles: ['verified', 'community_member', 'city_police', 'police_command'] },
  { key: 'intelligence', label: 'Intelligence Service officer', roles: ['verified', 'community_member', 'intelligence'] },
  { key: 'government_official', label: 'Government official', roles: ['verified', 'community_member', 'government_official'] },
  { key: 'secretary_economy', label: 'Secretary for Economy and Education', roles: ['verified', 'community_member', 'secretary_economy'] },
  { key: 'leader', label: 'Leader of the Revolution', roles: ['verified', 'community_member', 'leader'] },
  { key: 'economic_administrator', label: 'Economic Administrator (staff)', roles: ['verified', 'community_member', 'economic_administrator'] },
  { key: 'support_team', label: 'Support Team', roles: ['verified', 'community_member', 'support_team'] },
  { key: 'moderator', label: 'Moderator', roles: ['verified', 'community_member', 'moderator'] },
  { key: 'administrator', label: 'Administrator', roles: ['verified', 'community_member', 'administrator'] },
  { key: 'owner', label: 'Owner', roles: ['owner'] },
  { key: 'bot', label: 'Economy bot', roles: [BOT] },
];

// Server-wide permissions that must never come from a roleplay role.
export const DANGEROUS = ['Administrator', 'ManageGuild', 'ManageRoles', 'ManageChannels', 'BanMembers', 'KickMembers', 'ModerateMembers',
  'ManageMessages', 'ManageWebhooks', 'MentionEveryone', 'ManageNicknames', 'ViewAuditLog', 'ManageEvents', 'ManageThreads'];

export function allChannels() {
  return CHANNELS;
}

export function roleList() {
  return ROLES;
}
