import { test } from 'node:test';
import assert from 'node:assert/strict';
import { planSetup, summarizePlan } from '../src/setup/plan.js';
import { ROLES } from '../src/blueprint/roles.js';
import { CATEGORIES, CHANNELS } from '../src/blueprint/channels.js';

const emptyGuild = (extra = {}) => ({
  guildId: 'g', community: true, botUserId: 'bot', botHasAdministrator: true,
  everyonePermissions: ['ViewChannel', 'SendMessages', 'CreateInstantInvite'],
  roles: [{ id: 'botrole', name: 'Economy Bot', permissions: ['Administrator'], color: 0, hoist: false, mentionable: false, managed: true }],
  channels: [{ id: 'c1', name: 'general', type: 'text', parentId: null, topic: null, overwrites: [] }],
  saved: { roles: {}, channels: {}, categories: {} },
  ...extra,
});

test('on an empty server everything is created and nothing is deleted', () => {
  const plan = planSetup(emptyGuild(), { syncExisting: true });
  assert.equal(plan.roles.filter((r) => r.action === 'create').length, ROLES.length);
  assert.equal(plan.categories.filter((c) => c.action === 'create').length, CATEGORIES.length);
  // #general already exists and is adopted (moved and given the blueprint permissions).
  const general = plan.channels.find((c) => c.key === 'general');
  assert.equal(general.action, 'update');
  assert.equal(plan.channels.filter((c) => c.action === 'create').length, CHANNELS.length - 1);
  assert.equal(plan.everyone.action, 'update');
  const actions = new Set([...plan.roles, ...plan.categories, ...plan.channels].map((x) => x.action));
  assert.ok(!actions.has('delete'));
  assert.ok(!plan.extras.roles.includes('Economy Bot'), 'managed bot role is ignored');
});

test('without --sync-existing, existing items are only reported', () => {
  const plan = planSetup(emptyGuild(), { syncExisting: false });
  assert.equal(plan.channels.find((c) => c.key === 'general').action, 'differs');
  assert.equal(plan.everyone.action, 'differs');
});

test('without Community features, forum and announcement channels become text channels with a warning', () => {
  const plan = planSetup(emptyGuild({ community: false }), { syncExisting: true });
  const suggestions = plan.channels.find((c) => c.key === 'suggestions');
  assert.equal(suggestions.type, 'text');
  assert.ok(plan.warnings.some((w) => w.includes('#suggestions')));
});

test('missing Administrator permission is reported before any change', () => {
  const plan = planSetup(emptyGuild({ botHasAdministrator: false }));
  assert.ok(plan.warnings.some((w) => w.includes('Administrator')));
  assert.match(summarizePlan(plan), /Manual steps/);
});

test('a server built from the plan is reported as correct on the next run', () => {
  const first = planSetup(emptyGuild({ channels: [] }), { syncExisting: true });
  const roleId = (key) => `id-${key}`;
  const fix = (id) => (typeof id === 'string' && id.startsWith('<new:') ? `id-${id.slice(5, -1)}` : id);
  const state = emptyGuild({
    everyonePermissions: [],
    roles: first.roles.map((r) => ({ id: roleId(r.key), name: r.desired.name, permissions: r.desired.permissions, color: r.desired.color, hoist: r.desired.hoist, mentionable: r.desired.mentionable, managed: false })),
    channels: [
      ...first.categories.map((c) => ({ id: `id-${c.key}`, name: c.name, type: 'category', parentId: null, topic: null, overwrites: c.overwrites.map((o) => ({ ...o, id: fix(o.id) })) })),
      ...first.channels.map((c) => ({ id: `id-${c.key}`, name: c.name, type: c.type, parentId: `id-${c.parentKey}`, topic: c.topic, overwrites: c.overwrites.map((o) => ({ ...o, id: fix(o.id) })) })),
    ],
  });
  const second = planSetup(state, { syncExisting: true });
  const notOk = [...second.roles, ...second.categories, ...second.channels].filter((x) => x.action !== 'ok');
  assert.deepEqual(notOk.map((x) => `${x.key}: ${x.changes}`), []);
  assert.equal(second.everyone, null);
  // After the setup the bot runs without Administrator: no warning when nothing has to change.
  const locked = planSetup({ ...state, botHasAdministrator: false }, { syncExisting: true });
  assert.ok(!locked.warnings.some((w) => w.includes('Administrator')));
});
