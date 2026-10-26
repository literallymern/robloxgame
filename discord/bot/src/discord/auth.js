// Bot-level permissions. These control economic and administrative commands and are completely
// separate from Discord's own permissions: a fictional government office never grants Discord
// moderation rights, and Discord staff roles do not grant in-game economic powers.
import { PermissionError } from '../economy/errors.js';
import { ROSTER_RIGHTS, ROSTER_MANAGEABLE } from '../blueprint/roles.js';

export const PERMISSIONS = {
  'treasury.view': ['economic_administrator', 'leader', 'secretary_general', 'secretary_economy', 'congress_representative'],
  'treasury.spend': ['secretary_economy', 'secretary_general', 'leader'],
  'treasury.approve': ['secretary_economy', 'secretary_general', 'leader'],
  'treasury.budget': ['secretary_economy', 'secretary_general', 'leader'],
  'treasury.wages': ['secretary_economy', 'secretary_general', 'leader'],
  'policy.set': ['secretary_economy', 'secretary_general', 'leader'],
  'registry.review': ['secretary_economy', 'government_official', 'economic_administrator'],
  'credit.review': ['secretary_economy', 'economic_administrator'],
  'avk.review': ['avk_officer'],
  'fines.issue': ['city_police', 'police_command', 'gendarmerie', 'gendarmerie_command', 'judge'],
  'fines.cancel': ['judge', 'economic_administrator'],
  'property.state': ['secretary_internal', 'economic_administrator'],
  'econ.admin': ['economic_administrator'],
  'panels.post': ['administrator'],
  'mod.members': ['moderator', 'administrator'],
};

export const PERMISSION_DESCRIPTIONS = {
  'treasury.view': 'View detailed public finances, budgets and pending spending',
  'treasury.spend': 'Request public spending (executed at once up to 25,000 KGD, otherwise needs a second approver)',
  'treasury.approve': 'Approve or reject spending requests of other officials',
  'treasury.budget': 'Set budget lines for the current 30-day budget period',
  'treasury.wages': 'Change public-sector wages',
  'policy.set': 'Change tax rates, fees, tariffs, export duties, export bans and the policy rate (within fixed limits)',
  'registry.review': 'Approve, reject, suspend and reinstate businesses',
  'credit.review': 'Approve or reject loan applications above the automatic limit',
  'avk.review': 'Decide AVK insurance claims',
  'fines.issue': 'Issue fines',
  'fines.cancel': 'Cancel fines (e.g. after an appeal)',
  'property.state': 'Create and manage state-owned property',
  'econ.admin': 'Corrections up to 10,000 KGD, freezes, inspections, events, tick recovery, audit log',
  'panels.post': 'Post verification and ticket panels',
  'mod.members': 'Verify members by hand, restrict and unrestrict members (/mod)',
};

export function memberRoleIds(member) {
  if (!member) return [];
  if (Array.isArray(member.roles)) return member.roles;
  if (member.roles?.cache) return [...member.roles.cache.keys()];
  return [];
}

export function memberRoleKeys(ctx, member) {
  return memberRoleIds(member).map((id) => ctx.ids.keyOfRole(id)).filter(Boolean);
}

export function isOwner(ctx, userId, member) {
  return (ctx.config.ownerUserId && userId === ctx.config.ownerUserId) || memberRoleKeys(ctx, member).includes('owner');
}

export function can(ctx, interaction, permission) {
  const userId = interaction.user.id;
  if (isOwner(ctx, userId, interaction.member)) return true;
  const keys = memberRoleKeys(ctx, interaction.member);
  return (PERMISSIONS[permission] ?? []).some((k) => keys.includes(k));
}

export function requirePermission(ctx, interaction, permission) {
  if (!can(ctx, interaction, permission)) {
    throw new PermissionError(`You are not authorised to do this (${PERMISSION_DESCRIPTIONS[permission] ?? permission}).`);
  }
}

// Economy commands are for verified members only.
export function requireVerified(ctx, interaction) {
  const keys = memberRoleKeys(ctx, interaction.member);
  if (isOwner(ctx, interaction.user.id, interaction.member)) return;
  if (!keys.includes('verified') || keys.includes('restricted')) {
    throw new PermissionError('Please verify in #verify first. Economy commands are available to Verified Members.');
  }
}

// Which roles may this member assign or remove with /roster?
export function assignableRoles(ctx, interaction) {
  const keys = memberRoleKeys(ctx, interaction.member);
  if (isOwner(ctx, interaction.user.id, interaction.member) || keys.includes('administrator')) return new Set(ROSTER_MANAGEABLE);
  const out = new Set();
  for (const k of keys) for (const r of ROSTER_RIGHTS[k] ?? []) out.add(r);
  return out;
}
