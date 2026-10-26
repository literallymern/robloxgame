import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ROLES, ROLE_BY_KEY, EVERYONE_PERMISSIONS, ROSTER_RIGHTS, ROSTER_MANAGEABLE } from '../src/blueprint/roles.js';
import { CHANNELS, CATEGORIES } from '../src/blueprint/channels.js';
import { compiledBlueprint, effectivePermissions, PERSONAS, DANGEROUS, BOT, compileTicket, BOT_PERMISSIONS_AFTER_SETUP } from '../src/blueprint/compile.js';
import { TICKET_TYPES } from '../src/blueprint/tickets.js';
import { PERMISSIONS } from '../src/discord/auth.js';
import { STATE_JOBS } from '../src/economy/constants.js';

const blueprint = compiledBlueprint();
const channels = blueprint.flatMap((c) => c.channels);
const persona = (key) => PERSONAS.find((p) => p.key === key);
const can = (personaKey, channelKey, perm) => {
  const ch = channels.find((c) => c.key === channelKey);
  return effectivePermissions(persona(personaKey).roles, ch.overwrites, { type: ch.type }).has(perm);
};
const visible = (personaKey) => channels.filter((c) => can(personaKey, c.key, 'ViewChannel')).map((c) => c.key);
const roleKeys = new Set(ROLES.map((r) => r.key));

test('@everyone has no server-wide permissions', () => {
  assert.deepEqual(EVERYONE_PERMISSIONS, []);
});

test('only Owner, Administrator and Moderator hold dangerous server-wide permissions', () => {
  const allowed = { owner: true, administrator: true, moderator: true, developer: ['ViewAuditLog', 'ManageWebhooks'] };
  for (const r of ROLES) {
    const dangerous = r.permissions.filter((p) => DANGEROUS.includes(p));
    if (!dangerous.length) continue;
    const ok = allowed[r.key] === true || (Array.isArray(allowed[r.key]) && dangerous.every((p) => allowed[r.key].includes(p)));
    assert.ok(ok, `${r.name} has ${dangerous.join(', ')}`);
  }
  assert.ok(ROLE_BY_KEY.owner.permissions.includes('Administrator'));
  assert.ok(!ROLE_BY_KEY.administrator.permissions.includes('Administrator'), 'Administrator role must not hold the Discord Administrator flag');
});

test('fictional government, security and service roles have no server-wide permissions at all', () => {
  for (const r of ROLES.filter((x) => ['Government', 'Justice', 'Security', 'Public Services', 'Civilian'].includes(x.group))) {
    assert.deepEqual(r.permissions, [], `${r.name}`);
  }
});

test('unverified members only see the start channels and cannot write anywhere', () => {
  assert.deepEqual(visible('unverified').sort(), ['faq', 'rules', 'start_here', 'verify', 'welcome']);
  for (const c of visible('unverified')) assert.ok(!can('unverified', c, 'SendMessages'), c);
});

test('restricted members see the start channels and #appeals, and can only read', () => {
  assert.deepEqual(visible('restricted').sort(), ['appeals', 'faq', 'rules', 'start_here', 'verify', 'welcome']);
  for (const c of visible('restricted')) assert.ok(!can('restricted', c, 'SendMessages'), c);
});

test('civilians cannot see staff, government-internal, department or audit channels', () => {
  const v = new Set(visible('civilian'));
  for (const key of ['staff_chat', 'moderation_log', 'economy_audit_log', 'ticket_transcripts', 'bot_alerts', 'cabinet', 'government_internal', 'police_general', 'intelligence_secure', 'avk_office', 'economic_administration']) {
    assert.ok(!v.has(key), key);
  }
  assert.ok(v.has('general') && v.has('national_economic_report') && v.has('bank_terminal'));
  assert.ok(!can('civilian', 'national_economic_report', 'SendMessages'), 'report channel is read-only');
  assert.ok(!can('civilian', 'bank_terminal', 'SendMessages'), 'bank terminal is for slash commands only');
  assert.ok(can('civilian', 'bank_terminal', 'UseApplicationCommands'));
});

test('new members cannot post links or files; community members can', () => {
  assert.ok(!can('new_member', 'general', 'EmbedLinks'));
  assert.ok(!can('new_member', 'general', 'AttachFiles'));
  assert.ok(can('civilian', 'general', 'AttachFiles'));
});

test('government and security roles never see staff or moderation areas', () => {
  for (const p of ['leader', 'government_official', 'secretary_economy', 'intelligence', 'police_command']) {
    for (const key of ['staff_chat', 'moderation_log', 'appeals_review', 'incident_reports', 'economy_audit_log', 'ticket_transcripts', 'technical_config']) {
      assert.ok(!can(p, key, 'ViewChannel'), `${p} → ${key}`);
    }
  }
});

test('departments see their own channels only', () => {
  assert.ok(can('police_officer', 'police_general', 'SendMessages'));
  assert.ok(!can('police_officer', 'police_briefing', 'SendMessages'), 'briefings are posted by command');
  assert.ok(can('police_command', 'police_briefing', 'SendMessages'));
  assert.ok(!can('police_officer', 'gendarmerie_general', 'ViewChannel'));
  assert.ok(!can('police_officer', 'police_command_room', 'ViewChannel'));
  assert.ok(can('police_officer', 'joint_dispatch', 'SendMessages'));
});

test('the bot can post where it needs to, and holds no moderation permissions', () => {
  for (const c of CHANNELS.filter((x) => x.bot && x.type !== 'voice')) {
    assert.ok(can('bot', c.key, 'SendMessages'), c.key);
    assert.ok(can('bot', c.key, 'EmbedLinks'), c.key);
  }
  for (const p of ['Administrator', 'BanMembers', 'KickMembers', 'ModerateMembers', 'ManageGuild', 'ManageChannels', 'MentionEveryone']) {
    assert.ok(!BOT_PERMISSIONS_AFTER_SETUP.includes(p), p);
  }
});

test('staff see what they moderate', () => {
  for (const c of CHANNELS) assert.ok(can('administrator', c.key, 'ViewChannel'), `administrator → ${c.key}`);
  assert.ok(can('moderator', 'general', 'ViewChannel'));
  assert.ok(can('moderator', 'moderation_log', 'ViewChannel'));
  assert.ok(!can('moderator', 'cabinet', 'ViewChannel'), 'staff do not read in-character government secrets');
});

test('ticket channels are private to the applicant, reviewers, administrators and the bot', () => {
  const ow = compileTicket({ reviewers: ['police_command'] });
  const see = (roles) => effectivePermissions(roles, ow).has('ViewChannel');
  assert.ok(see(['@applicant']));
  assert.ok(see(['verified', 'police_command']));
  assert.ok(see(['administrator']));
  assert.ok(see([BOT]));
  assert.ok(!see(['verified', 'civilian']));
  assert.ok(!see(['verified', 'moderator']), 'moderators only see tickets they review');
});

test('every key referenced by blueprint, permissions and jobs exists', () => {
  for (const c of CHANNELS) {
    for (const list of [c.view, c.post, c.manage]) if (Array.isArray(list)) for (const k of list) assert.ok(roleKeys.has(k), `${c.key}: ${k}`);
  }
  for (const [perm, keys] of Object.entries(PERMISSIONS)) for (const k of keys) assert.ok(roleKeys.has(k), `${perm}: ${k}`);
  for (const [k, list] of Object.entries(ROSTER_RIGHTS)) {
    assert.ok(roleKeys.has(k));
    for (const r of list) assert.ok(ROSTER_MANAGEABLE.includes(r), `${k} → ${r}`);
  }
  for (const t of Object.values(TICKET_TYPES)) for (const r of t.reviewers) assert.ok(roleKeys.has(r), r);
  for (const j of STATE_JOBS) assert.ok(roleKeys.has(j.department), j.department);
  const names = CHANNELS.map((c) => c.name);
  assert.equal(new Set(names).size, names.length, 'channel names are unique');
  assert.equal(new Set(CATEGORIES.map((c) => c.name)).size, CATEGORIES.length);
});

test('in-game economic powers are separate from Discord staff roles', () => {
  for (const perm of ['treasury.spend', 'treasury.approve', 'policy.set']) {
    assert.ok(!PERMISSIONS[perm].includes('administrator'), perm);
    assert.ok(!PERMISSIONS[perm].includes('moderator'), perm);
  }
  assert.ok(!PERMISSIONS['econ.admin'].some((k) => ROLE_BY_KEY[k].group === 'Government'), 'no government role can use staff economy tools');
});
