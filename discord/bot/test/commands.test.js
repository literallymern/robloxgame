// Runs the slash-command handlers with fake Discord interactions against an in-memory economy.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { testEconomy } from './helpers.js';
import { COMMANDS, COMMAND_BY_NAME, commandJson } from '../src/discord/commands/index.js';
import { createResolver } from '../src/discord/ids.js';
import { ROLES } from '../src/blueprint/roles.js';
import { PermissionError, UserError } from '../src/economy/errors.js';
import { KGD, POLICY_DEFAULTS } from '../src/economy/constants.js';
import { getPolicy } from '../src/economy/policy.js';
import { createLinkCode, activeLinkByDiscord } from '../src/economy/links.js';

function setup() {
  const t = testEconomy();
  const ids = createResolver('/nonexistent/ids.json');
  ids._set({ roles: Object.fromEntries(ROLES.map((r) => [r.key, `role-${r.key}`])), channels: {}, categories: {} });
  const synced = [];
  const notices = [];
  const ctx = {
    eco: t.eco, ids,
    config: { ownerUserId: 'the-owner', grantMinAccountAgeDays: 14, minAccountAgeDays: 7, newMemberDays: 7, backupDir: '/tmp', backupKeep: 1 },
    syncRoles: (list) => synced.push(...list),
    notify: async (key, text) => { notices.push({ key, text }); },
    dm: async () => {},
  };
  return { t, ctx, synced, notices };
}

function interaction({ command, sub = null, group = null, options = {}, user = 'u1', roles = ['verified', 'community_member', 'civilian'], focused = null }) {
  const replies = [];
  const get = (name, required) => {
    if (options[name] === undefined || options[name] === null) {
      if (required) throw new Error(`missing required option ${name}`);
      return null;
    }
    return options[name];
  };
  const i = {
    commandName: command,
    guildId: 'guild',
    user: { id: user, username: user, globalName: user, createdTimestamp: Date.now() - 365 * 86_400_000, bot: false },
    member: { roles: roles.map((k) => `role-${k}`), displayName: user },
    deferred: false,
    replied: false,
    options: {
      getSubcommand: () => sub,
      getSubcommandGroup: () => group,
      getString: get, getNumber: get, getInteger: get, getBoolean: get,
      getUser: (name, required) => { const v = get(name, required); return v ? { id: v, bot: false } : null; },
      getFocused: (full) => (full ? focused : focused?.value),
    },
    async reply(d) { replies.push(d); i.replied = true; },
    async followUp(d) { replies.push(d); },
    async deferReply() { i.deferred = true; },
    async editReply(d) { replies.push(d); },
    replies,
  };
  return i;
}

const run = (ctx, spec) => {
  const i = interaction(spec);
  return COMMAND_BY_NAME.get(spec.command).execute(ctx, i).then(() => i);
};
const text = (i) => JSON.stringify(i.replies);

test('command definitions are valid for Discord', () => {
  const json = commandJson();
  assert.equal(new Set(json.map((c) => c.name)).size, json.length, 'unique names');
  for (const c of json) {
    assert.match(c.name, /^[a-z-]{1,32}$/);
    let chars = 0;
    const walk = (o, path) => {
      chars += (o.name?.length ?? 0) + (o.description?.length ?? 0);
      for (const ch of o.choices ?? []) chars += ch.name.length + String(ch.value).length;
      if (o.description) assert.ok(o.description.length <= 100, `${path} description too long`);
      const opts = o.options ?? [];
      assert.ok(opts.length <= 25, `${path} has too many options`);
      let seenOptional = false;
      for (const x of opts) {
        if (x.type === 1 || x.type === 2) { walk(x, `${path} ${x.name}`); continue; }
        if (!x.required) seenOptional = true;
        else assert.ok(!seenOptional, `${path}: required option ${x.name} after an optional one`);
        walk(x, `${path} ${x.name}`);
      }
    };
    walk(c, c.name);
    assert.ok(chars <= 4000, `${c.name} uses ${chars} characters`);
  }
  for (const c of COMMANDS) assert.equal(typeof c.execute, 'function');
});

test('economy commands require verification', async () => {
  const { ctx } = setup();
  await assert.rejects(run(ctx, { command: 'bank', sub: 'balance', roles: [] }), PermissionError);
  await assert.rejects(run(ctx, { command: 'bank', sub: 'balance', roles: ['verified', 'restricted'] }), PermissionError);
});

test('/bank balance opens an account with the starting grant (private reply)', async () => {
  const { ctx } = setup();
  const i = await run(ctx, { command: 'bank', sub: 'balance' });
  assert.match(text(i), /starting balance/);
  assert.equal(i.replies[0].flags, 64, 'ephemeral');
  assert.deepEqual(i.replies[0].allowedMentions, { parse: [] });
});

test('/bank pay and /work', async () => {
  const { t, ctx } = setup();
  await run(ctx, { command: 'bank', sub: 'balance', user: 'a' });
  await run(ctx, { command: 'bank', sub: 'balance', user: 'b' });
  await run(ctx, { command: 'bank', sub: 'pay', user: 'a', options: { amount: 25.5, memo: 'Lunch', to_user: 'b' } });
  assert.equal(t.bank('b'), POLICY_DEFAULTS.starting_grant + 2550);
  await assert.rejects(run(ctx, { command: 'work', user: 'a' }), /no job/);
  const i = await run(ctx, { command: 'work', user: 'a', roles: ['verified', 'city_police'] });
  assert.match(text(i), /City Police Officer/);
});

test('business registration and registry approval with role sync', async () => {
  const { ctx, synced, notices } = setup();
  await run(ctx, { command: 'bank', sub: 'balance', user: 'owner1' });
  await run(ctx, { command: 'business', sub: 'register', user: 'owner1', options: { name: 'Gundi Timber', industry: 'timber' } });
  assert.ok(notices.some((n) => n.key === 'economic_administration'));
  const id = String(ctx.eco.db.prepare('SELECT id FROM businesses').get().id);
  await assert.rejects(run(ctx, { command: 'registry', sub: 'approve', user: 'civ', options: { business: id } }), PermissionError);
  await assert.rejects(run(ctx, { command: 'registry', sub: 'approve', user: 'owner1', roles: ['verified', 'government_official'], options: { business: id } }), /own business/);
  await run(ctx, { command: 'registry', sub: 'approve', user: 'clerk', roles: ['verified', 'government_official'], options: { business: id } });
  assert.deepEqual(synced, ['owner1']);
  const status = await run(ctx, { command: 'business', sub: 'status', user: 'owner1', options: { business: id } });
  assert.match(text(status), /Gundi Timber/);
  await assert.rejects(run(ctx, { command: 'business', sub: 'status', user: 'stranger', options: { business: id } }), UserError);
});

test('in-game powers come from in-game offices, not from Discord staff roles', async () => {
  const { ctx } = setup();
  const spec = { command: 'policy', sub: 'set', options: { setting: 'income_tax_bp', value: 12.5, reason: 'Budget deficit' } };
  await assert.rejects(run(ctx, { ...spec, user: 'admin', roles: ['verified', 'administrator'] }), PermissionError);
  await assert.rejects(run(ctx, { ...spec, user: 'mod', roles: ['verified', 'moderator'] }), PermissionError);
  await run(ctx, { ...spec, user: 'sec', roles: ['verified', 'secretary_economy'] });
  assert.equal(getPolicy(ctx.eco, 'income_tax_bp'), 1250);
  await run(ctx, { ...spec, user: 'the-owner', roles: [], options: { ...spec.options, value: 10 } });
  assert.equal(getPolicy(ctx.eco, 'income_tax_bp'), 1000, 'the Owner can override');
});

test('staff economy tools are limited to economic administrators and audited', async () => {
  const { ctx } = setup();
  await run(ctx, { command: 'bank', sub: 'balance', user: 'target' });
  await assert.rejects(run(ctx, { command: 'econ-admin', sub: 'inspect', user: 'leader', roles: ['verified', 'leader'], options: { user: 'target', reason: 'curious' } }), PermissionError);
  const i = await run(ctx, { command: 'econ-admin', sub: 'inspect', user: 'ea', roles: ['verified', 'economic_administrator'], options: { user: 'target', reason: 'Ticket 7 check' } });
  assert.match(text(i), /Financial record/);
  assert.equal(ctx.eco.db.prepare("SELECT COUNT(*) AS n FROM audit_log WHERE action = 'admin.inspect'").get().n, 1);
  await assert.rejects(run(ctx, { command: 'econ-admin', sub: 'maintenance', user: 'ea', roles: ['verified', 'economic_administrator'], options: { on: true, reason: 'Testing' } }), /Owner/);
});

test('maintenance mode blocks player changes but not reading', async () => {
  const { ctx } = setup();
  await run(ctx, { command: 'bank', sub: 'balance', user: 'a' });
  await run(ctx, { command: 'econ-admin', sub: 'maintenance', user: 'the-owner', roles: [], options: { on: true, reason: 'Database migration' } });
  await assert.rejects(run(ctx, { command: 'bank', sub: 'withdraw', user: 'a', options: { amount: 10 } }), /maintenance/);
  await run(ctx, { command: 'bank', sub: 'balance', user: 'a' });
});

test('treasury spending above the threshold needs a second official', async () => {
  const { ctx } = setup();
  for (const u of ['sec', 'sg', 'contractor']) await run(ctx, { command: 'bank', sub: 'balance', user: u });
  await run(ctx, { command: 'treasury', sub: 'budget-set', user: 'sec', roles: ['verified', 'secretary_economy'], options: { category: 'infrastructure', amount: 100000, reason: 'Road programme' } });
  const big = await run(ctx, { command: 'treasury', sub: 'spend', user: 'sec', roles: ['verified', 'secretary_economy'], options: { amount: 30000, category: 'infrastructure', reason: 'Bridge in Stokondo', to_user: 'contractor' } });
  assert.match(text(big), /another authorised official/);
  const reqId = String(ctx.eco.db.prepare('SELECT id FROM spending_requests').get().id);
  await assert.rejects(run(ctx, { command: 'treasury', sub: 'approve', user: 'sec', roles: ['verified', 'secretary_economy'], options: { request: reqId } }), /second official/);
  await run(ctx, { command: 'treasury', sub: 'approve', user: 'sg', roles: ['verified', 'secretary_general'], options: { request: reqId } });
  await assert.rejects(run(ctx, { command: 'treasury', sub: 'spend', user: 'sec', roles: ['verified', 'secretary_economy'], options: { amount: 10, category: 'infrastructure', reason: 'Self payment', to_user: 'sec' } }), /yourself/);
});

test('fines: only police, gendarmerie and judges can issue', async () => {
  const { ctx } = setup();
  await run(ctx, { command: 'bank', sub: 'balance', user: 'driver' });
  await assert.rejects(run(ctx, { command: 'fine', sub: 'issue', user: 'civ', options: { user: 'driver', amount: 100, reason: 'Speeding' } }), PermissionError);
  const i = await run(ctx, { command: 'fine', sub: 'issue', user: 'cop', roles: ['verified', 'city_police'], options: { user: 'driver', amount: 100, reason: 'Speeding in Gundiville' } });
  assert.match(text(i), /City Police/);
});

test('/roster only lets department leaders manage their own department', async () => {
  const { ctx } = setup();
  const auto = await COMMAND_BY_NAME.get('roster').autocomplete(ctx, interaction({ command: 'roster', roles: ['verified', 'police_command'], focused: { name: 'role', value: '' } }));
  assert.deepEqual(auto.map((c) => c.value), ['city_police']);
  const adminAuto = await COMMAND_BY_NAME.get('roster').autocomplete(ctx, interaction({ command: 'roster', roles: ['verified', 'administrator'], focused: { name: 'role', value: '' } }));
  assert.ok(!adminAuto.some((c) => c.value === 'leader'), 'only the Owner assigns the Leader role');
  assert.ok(!adminAuto.some((c) => ['administrator', 'moderator', 'owner'].includes(c.value)), 'no staff roles via /roster');
  await assert.rejects(run(ctx, { command: 'roster', sub: 'add', user: 'pc', roles: ['verified', 'police_command'], options: { user: 'x', role: 'gendarmerie' } }), PermissionError);
});

test('autocomplete never fails for users without data', async () => {
  const { ctx } = setup();
  for (const c of COMMANDS.filter((x) => x.autocomplete)) {
    const json = c.data.toJSON();
    const subs = (json.options ?? []).flatMap((o) => (o.type === 2 ? o.options.map((s) => [o.name, s]) : o.type === 1 ? [[null, o]] : []));
    for (const [group, sub] of subs.length ? subs : [[null, json]]) {
      for (const opt of (sub.options ?? []).filter((o) => o.autocomplete)) {
        const i = interaction({ command: c.data.name, group, sub: sub.name === c.data.name ? null : sub.name, user: 'nobody', focused: { name: opt.name, value: '' } });
        const res = await c.autocomplete(ctx, i);
        assert.ok(Array.isArray(res) && res.length <= 25, `${c.data.name} ${sub.name} ${opt.name}`);
      }
    }
  }
});

test('reading other people\'s data is not possible', async () => {
  const { ctx } = setup();
  await run(ctx, { command: 'bank', sub: 'balance', user: 'a' });
  // Transactions are always the caller's own account; there is no option to name another user.
  const bankJson = COMMAND_BY_NAME.get('bank').data.toJSON();
  const txOptions = bankJson.options.find((o) => o.name === 'transactions').options.map((o) => o.name);
  assert.ok(!txOptions.includes('user'));
  await assert.rejects(run(ctx, { command: 'loan', sub: 'repay', user: 'b', options: { loan: '1', amount: 5 } }), UserError);
  assert.equal(KGD(1), 100);
});

test('/link confirm, status, remove and keep', async () => {
  const { t, ctx } = setup();
  await assert.rejects(run(ctx, { command: 'link', sub: 'confirm', user: 'p', roles: [], options: { code: 'AAAA-AAAA' } }), PermissionError);
  const { code } = createLinkCode(t.eco, { robloxUserId: '1001', robloxName: 'PlayerOne' });
  const i = await run(ctx, { command: 'link', sub: 'confirm', user: 'p', options: { code } });
  assert.match(text(i), /PlayerOne/);
  assert.match(text(i), /starting balance/, 'a new citizen gets the grant through the normal Discord rules');
  assert.equal(i.replies[0].flags, 64, 'ephemeral');
  assert.equal(t.bank('p'), POLICY_DEFAULTS.starting_grant, 'exactly one grant, no extra money for linking');
  assert.match(text(await run(ctx, { command: 'link', sub: 'status', user: 'p' })), /1001/);
  assert.match(text(await run(ctx, { command: 'link', sub: 'remove', user: 'p' })), /will be removed/);
  assert.match(text(await run(ctx, { command: 'link', sub: 'keep', user: 'p' })), /stays active/);
  assert.ok(activeLinkByDiscord(t.eco, 'p'));
  await assert.rejects(run(ctx, { command: 'link', sub: 'confirm', user: 'q', options: { code } }), /wrong or has expired/);
});

test('/econ-admin link-remove is staff only and audited', async () => {
  const { t, ctx } = setup();
  const { code } = createLinkCode(t.eco, { robloxUserId: '1001' });
  await run(ctx, { command: 'link', sub: 'confirm', user: 'p', options: { code } });
  const spec = { command: 'econ-admin', sub: 'link-remove', options: { roblox_id: '1001', reason: 'Lost account, ticket 3' } };
  await assert.rejects(run(ctx, { ...spec, user: 'civ' }), PermissionError);
  const i = await run(ctx, { ...spec, user: 'ea', roles: ['verified', 'economic_administrator'] });
  assert.match(text(i), /Link removed/);
  assert.equal(activeLinkByDiscord(t.eco, 'p'), null);
  assert.equal(ctx.eco.db.prepare("SELECT COUNT(*) AS n FROM audit_log WHERE action = 'link.removed_by_staff'").get().n, 1);
});
