// The Roblox bridge over real HTTP against an in-memory economy.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { testEconomy } from './helpers.js';
import { createBridgeServer, startBridge, TEST_TRANSFER_MAX } from '../src/bridge/server.js';
import { confirmLink, createLinkCode } from '../src/economy/links.js';
import { setMaintenance, setFrozen } from '../src/economy/admin.js';
import { verifyLedger } from '../src/economy/ledger.js';

const KEY = 'test-key-0123456789-0123456789-0123456789';
const quiet = { info() {}, warn() {}, error() {} };

async function withBridge(fn, { testOperations = true, roles = async () => ['verified', 'city_police'] } = {}) {
  const t = testEconomy();
  const server = createBridgeServer({ eco: t.eco, apiKey: KEY, testOperations, memberRoleKeys: roles, log: quiet });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = async (method, path, body, { key = KEY, header = 'authorization' } = {}) => {
    const headers = {};
    if (key) headers[header] = header === 'authorization' ? `Bearer ${key}` : key;
    if (body !== undefined) headers['content-type'] = 'application/json';
    const res = await fetch(base + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: res.status, body: await res.json() };
  };
  try {
    await fn({ t, call });
  } finally {
    await new Promise((r) => server.close(r));
  }
}

function link(t, discordId, robloxUserId) {
  t.citizen(discordId);
  return confirmLink(t.eco, { discordId, code: createLinkCode(t.eco, { robloxUserId }).code });
}

test('the bridge refuses short keys and stays off unless enabled', () => {
  const t = testEconomy();
  assert.throws(() => createBridgeServer({ eco: t.eco, apiKey: 'short', log: quiet }), /at least 32/);
  assert.equal(startBridge({ eco: t.eco, config: { bridge: { enabled: false } }, log: quiet }), null);
  assert.equal(startBridge({ eco: t.eco, config: { bridge: { enabled: true, apiKey: '' } }, log: quiet }), null);
});

test('every request needs the API key (bearer or x-api-key)', async () => {
  await withBridge(async ({ call }) => {
    assert.equal((await call('GET', '/v1/health', undefined, { key: null })).status, 401);
    assert.equal((await call('GET', '/v1/health', undefined, { key: `${KEY}x` })).status, 401);
    const ok = await call('GET', '/v1/health');
    assert.equal(ok.status, 200);
    assert.equal(ok.body.service, 'ro-nation-bridge');
    assert.equal(ok.body.testOperations, true);
    assert.equal((await call('GET', '/v1/health', undefined, { header: 'x-api-key' })).status, 200);
    assert.equal((await call('GET', '/v1/nothing')).status, 404);
    assert.equal((await call('POST', '/v1/health', {})).status, 405);
  });
});

test('link flow: the game gets a code, Discord confirms, the summary shows the same balances as /bank balance', async () => {
  await withBridge(async ({ t, call }) => {
    const before = await call('GET', '/v1/players/1001/summary');
    assert.equal(before.body.linked, false);
    const start = await call('POST', '/v1/links/start', { robloxUserId: 1001, robloxName: 'PlayerOne' });
    assert.equal(start.body.status, 'code');
    t.citizen('d1');
    confirmLink(t.eco, { discordId: 'd1', code: start.body.code });
    const s = await call('GET', '/v1/players/1001/summary');
    assert.equal(s.body.linked, true);
    assert.equal(s.body.accounts.bank.balance, t.bank('d1'));
    assert.equal(s.body.accounts.cash.balance, t.cash('d1'));
    assert.deepEqual(s.body.roles, ['verified', 'city_police']);
    assert.equal((await call('POST', '/v1/links/start', { robloxUserId: '1001' })).body.status, 'linked');
    assert.equal((await call('POST', '/v1/links/start', { robloxUserId: 'x1' })).status, 400);
  });
});

test('roblox logins never create citizens or pay the starting grant', async () => {
  await withBridge(async ({ t, call }) => {
    await call('POST', '/v1/links/start', { robloxUserId: '1001' });
    await call('GET', '/v1/players/1001/summary');
    assert.equal(t.eco.db.prepare('SELECT COUNT(*) AS n FROM citizens').get().n, 0);
    assert.equal(t.eco.db.prepare("SELECT COUNT(*) AS n FROM transactions WHERE category = 'citizen_starting_grant'").get().n, 0);
  });
});

test('test transfer runs exactly once per operation ID, also when repeated', async () => {
  await withBridge(async ({ t, call }) => {
    link(t, 'd1', '1001');
    const bank = t.bank('d1');
    const op = { operationId: 'op-11111111-aaaa', robloxUserId: '1001', direction: 'withdraw', amount: 150 };
    const first = await call('POST', '/v1/operations/test-cash-transfer', op);
    assert.equal(first.status, 200);
    assert.equal(first.body.replayed, false);
    const again = await call('POST', '/v1/operations/test-cash-transfer', op);
    assert.equal(again.status, 200);
    assert.equal(again.body.replayed, true);
    assert.equal(again.body.transactionId, first.body.transactionId);
    assert.equal(t.bank('d1'), bank - 150);
    assert.equal(t.cash('d1'), 150);
    assert.equal(t.eco.db.prepare("SELECT COUNT(*) AS n FROM transactions WHERE idempotency_key = 'bridge:op-11111111-aaaa'").get().n, 1);
    const conflict = await call('POST', '/v1/operations/test-cash-transfer', { ...op, amount: 151 });
    assert.equal(conflict.status, 409);
    assert.equal(t.bank('d1'), bank - 150);
    const audit = t.eco.db.prepare("SELECT * FROM audit_log WHERE action = 'bridge.test_cash_transfer.succeeded'").all();
    assert.equal(audit.length, 1);
    assert.equal(audit[0].actor_id, 'd1');
    assert.ok(verifyLedger(t.eco).ok);
  });
});

test('refusals are stored and replayed, nothing moves', async () => {
  await withBridge(async ({ t, call }) => {
    link(t, 'd1', '1001');
    const op = { operationId: 'op-22222222-bbbb', robloxUserId: '1001', direction: 'deposit', amount: 100 };
    const r = await call('POST', '/v1/operations/test-cash-transfer', op);
    assert.equal(r.status, 422);
    assert.match(r.body.message, /Insufficient funds/);
    assert.equal((await call('POST', '/v1/operations/test-cash-transfer', op)).body.replayed, true);
    const unlinked = await call('POST', '/v1/operations/test-cash-transfer', { ...op, operationId: 'op-33333333-cccc', robloxUserId: '9999' });
    assert.equal(unlinked.status, 422);
    assert.match(unlinked.body.message, /not linked/);
    setFrozen(t.eco, { actor: 'staff', userId: 'd1', frozen: true, reason: 'Investigation' });
    const frozen = await call('POST', '/v1/operations/test-cash-transfer', { ...op, operationId: 'op-44444444-dddd', direction: 'withdraw' });
    assert.equal(frozen.status, 422);
    assert.match(frozen.body.message, /frozen/);
    assert.equal(t.cash('d1'), 0);
    assert.equal(t.eco.db.prepare("SELECT COUNT(*) AS n FROM audit_log WHERE action = 'bridge.test_cash_transfer.refused'").get().n, 3);
  });
});

test('maintenance mode blocks writes without storing them, reads still work', async () => {
  await withBridge(async ({ t, call }) => {
    link(t, 'd1', '1001');
    setMaintenance(t.eco, { actor: 'owner', on: true, reason: 'Test' });
    const op = { operationId: 'op-55555555-eeee', robloxUserId: '1001', direction: 'withdraw', amount: 100 };
    assert.equal((await call('POST', '/v1/operations/test-cash-transfer', op)).status, 503);
    assert.equal((await call('POST', '/v1/links/start', { robloxUserId: '1002' })).status, 503);
    const s = await call('GET', '/v1/players/1001/summary');
    assert.equal(s.status, 200);
    assert.equal(s.body.maintenance, true);
    setMaintenance(t.eco, { actor: 'owner', on: false, reason: 'Test' });
    assert.equal((await call('POST', '/v1/operations/test-cash-transfer', op)).status, 200, 'the same operation runs after maintenance');
  });
});

test('resolve returns the stored answer or voids an operation that never arrived', async () => {
  await withBridge(async ({ t, call }) => {
    link(t, 'd1', '1001');
    const op = { operationId: 'op-66666666-ffff', robloxUserId: '1001', direction: 'withdraw', amount: 100 };
    await call('POST', '/v1/operations/test-cash-transfer', op);
    const known = await call('POST', `/v1/operations/${op.operationId}/resolve`, {});
    assert.equal(known.body.state, 'succeeded');
    const lost = await call('POST', '/v1/operations/op-77777777-0000/resolve', {});
    assert.equal(lost.status, 410);
    assert.equal(lost.body.state, 'voided');
    const late = await call('POST', '/v1/operations/test-cash-transfer', { ...op, operationId: 'op-77777777-0000' });
    assert.equal(late.status, 409, 'a late copy of a voided operation never runs');
    assert.equal(t.cash('d1'), 100);
  });
});

test('test operations are off unless enabled, and input is validated', async () => {
  await withBridge(async ({ t, call }) => {
    link(t, 'd1', '1001');
    const r = await call('POST', '/v1/operations/test-cash-transfer', { operationId: 'op-88888888-1111', robloxUserId: '1001', direction: 'withdraw', amount: 100 });
    assert.equal(r.status, 404);
  }, { testOperations: false });
  await withBridge(async ({ t, call }) => {
    link(t, 'd1', '1001');
    const base = { operationId: 'op-99999999-2222', robloxUserId: '1001', direction: 'withdraw', amount: 100 };
    for (const bad of [{ amount: 0 }, { amount: TEST_TRANSFER_MAX + 1 }, { amount: 1.5 }, { direction: 'steal' }, { operationId: 'x' }]) {
      assert.equal((await call('POST', '/v1/operations/test-cash-transfer', { ...base, ...bad })).status, 400, JSON.stringify(bad));
    }
  });
});

test('transactions endpoint pages the linked account', async () => {
  await withBridge(async ({ t, call }) => {
    link(t, 'd1', '1001');
    const r = await call('GET', '/v1/players/1001/transactions?account=bank&page=1');
    assert.equal(r.status, 200);
    assert.equal(r.body.items[0].category, 'citizen_starting_grant');
    assert.equal(r.body.items[0].direction, 'in');
    assert.equal((await call('GET', '/v1/players/1001/transactions?account=savings')).status, 400);
    assert.equal((await call('GET', '/v1/players/2002/transactions')).status, 422);
  });
});

test('startBridge listens only when switched on with a valid key', async () => {
  const t = testEconomy();
  const server = startBridge({ eco: t.eco, config: { bridge: { enabled: true, apiKey: KEY, host: '127.0.0.1', port: 0, testOperations: false } }, log: quiet });
  await new Promise((r) => server.once('listening', r));
  const res = await fetch(`http://127.0.0.1:${server.address().port}/v1/health`, { headers: { authorization: `Bearer ${KEY}` } });
  assert.equal((await res.json()).testOperations, false);
  await new Promise((r) => server.close(r));
});
