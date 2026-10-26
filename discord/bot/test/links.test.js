// Discord <-> Roblox account links.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { testEconomy } from './helpers.js';
import {
  createLinkCode, confirmLink, activeLinkByDiscord, activeLinkByRoblox, requestLinkRemoval, cancelLinkRemoval,
  staffRemoveLink, normalizeCode, LINK_RULES,
} from '../src/economy/links.js';
import { openDatabase } from '../src/db/database.js';
import { UserError } from '../src/economy/errors.js';

test('migration adds the link tables to a database without touching existing data', () => {
  const db = openDatabase(':memory:');
  const tables = db.prepare("SELECT name FROM sqlite_master WHERE type = 'table'").all().map((r) => r.name);
  for (const t of ['account_links', 'link_codes', 'bridge_operations', 'citizens', 'transactions']) assert.ok(tables.includes(t), t);
  assert.equal(db.prepare("SELECT value FROM meta WHERE key = 'schema_version'").get().value, '2');
});

test('a code links one Roblox account to one Discord account, once', () => {
  const t = testEconomy();
  t.citizen('d1');
  const res = createLinkCode(t.eco, { robloxUserId: '1001', robloxName: 'PlayerOne' });
  assert.equal(res.status, 'code');
  assert.match(res.code, /^[A-Z2-9]{4}-[A-Z2-9]{4}$/);
  assert.equal(t.eco.db.prepare('SELECT COUNT(*) AS n FROM link_codes WHERE code_hash LIKE ?').get(`%${normalizeCode(res.code)}%`).n, 0, 'only a hash is stored');

  const link = confirmLink(t.eco, { discordId: 'd1', code: res.code.toLowerCase().replace('-', ' ') });
  assert.equal(link.roblox_user_id, '1001');
  assert.equal(link.roblox_name, 'PlayerOne');
  assert.equal(activeLinkByRoblox(t.eco, '1001').discord_id, 'd1');
  assert.throws(() => confirmLink(t.eco, { discordId: 'd2', code: res.code }), /wrong or has expired/, 'single use');
  assert.equal(createLinkCode(t.eco, { robloxUserId: '1001' }).status, 'linked', 'no new code for a linked account');
});

test('linking never pays money', () => {
  const t = testEconomy();
  t.citizen('d1');
  const before = t.bank('d1');
  const txBefore = t.eco.db.prepare('SELECT COUNT(*) AS n FROM transactions').get().n;
  confirmLink(t.eco, { discordId: 'd1', code: createLinkCode(t.eco, { robloxUserId: '1001' }).code });
  assert.equal(t.bank('d1'), before);
  assert.equal(t.eco.db.prepare('SELECT COUNT(*) AS n FROM transactions').get().n, txBefore);
});

test('codes expire, are replaced by newer codes and are rate limited', () => {
  const t = testEconomy();
  const old = createLinkCode(t.eco, { robloxUserId: '1001' });
  const fresh = createLinkCode(t.eco, { robloxUserId: '1001' });
  assert.throws(() => confirmLink(t.eco, { discordId: 'd1', code: old.code }), /wrong or has expired/, 'older code revoked');
  t.setNow(new Date(t.eco.clock.now().getTime() + (LINK_RULES.codeTtlMinutes + 1) * 60_000).toISOString());
  assert.throws(() => confirmLink(t.eco, { discordId: 'd1', code: fresh.code }), /wrong or has expired/, 'expired');

  const t2 = testEconomy();
  for (let i = 0; i < LINK_RULES.maxCodesPerWindow; i += 1) createLinkCode(t2.eco, { robloxUserId: '2002' });
  assert.throws(() => createLinkCode(t2.eco, { robloxUserId: '2002' }), /Too many link codes/);
  assert.throws(() => createLinkCode(t2.eco, { robloxUserId: 'abc' }), /Invalid Roblox user ID/);
});

test('wrong codes are limited per Discord account and recorded', () => {
  const t = testEconomy();
  for (let i = 0; i < LINK_RULES.maxFailedConfirms; i += 1) assert.throws(() => confirmLink(t.eco, { discordId: 'd1', code: 'AAAA-AAAA' }), /wrong or has expired/);
  const good = createLinkCode(t.eco, { robloxUserId: '1001' });
  assert.throws(() => confirmLink(t.eco, { discordId: 'd1', code: good.code }), /Too many wrong codes/);
  assert.equal(t.eco.db.prepare("SELECT COUNT(*) AS n FROM audit_log WHERE action = 'link.confirm_failed'").get().n, LINK_RULES.maxFailedConfirms);
});

test('no duplicate links on either side', () => {
  const t = testEconomy();
  confirmLink(t.eco, { discordId: 'd1', code: createLinkCode(t.eco, { robloxUserId: '1001' }).code });
  const other = createLinkCode(t.eco, { robloxUserId: '1002' });
  assert.throws(() => confirmLink(t.eco, { discordId: 'd1', code: other.code }), /already linked to the Roblox account/);
  // The same Roblox account cannot be linked twice, even if a code was issued before the first link.
  const t2 = testEconomy();
  const a = createLinkCode(t2.eco, { robloxUserId: '3003' });
  t2.eco.db.prepare("INSERT INTO account_links (discord_id, roblox_user_id, status, linked_at, linked_day) VALUES ('dX', '3003', 'active', ?, 1)").run(t2.eco.clock.isoNow());
  assert.throws(() => confirmLink(t2.eco, { discordId: 'd2', code: a.code }), /already linked to another Discord account/);
  assert.throws(() => t2.eco.db.prepare("INSERT INTO account_links (discord_id, roblox_user_id, status, linked_at, linked_day) VALUES ('dY', '3003', 'active', ?, 1)").run(t2.eco.clock.isoNow()), /UNIQUE/);
});

test('self removal waits for the cooling-off period and can be cancelled; staff removal is immediate', () => {
  const t = testEconomy();
  confirmLink(t.eco, { discordId: 'd1', code: createLinkCode(t.eco, { robloxUserId: '1001' }).code });
  const { effectiveAt } = requestLinkRemoval(t.eco, { discordId: 'd1' });
  assert.ok(effectiveAt > t.eco.clock.isoNow());
  assert.ok(activeLinkByDiscord(t.eco, 'd1'), 'still active during the cooling-off period');
  cancelLinkRemoval(t.eco, { discordId: 'd1' });
  requestLinkRemoval(t.eco, { discordId: 'd1' });
  t.advanceDays(1);
  t.setNow(new Date(t.eco.clock.now().getTime() + 60_000).toISOString());
  assert.equal(activeLinkByDiscord(t.eco, 'd1'), null, 'removed after 24 hours');
  assert.equal(t.eco.db.prepare("SELECT COUNT(*) AS n FROM audit_log WHERE action = 'link.removed'").get().n, 1);

  confirmLink(t.eco, { discordId: 'd1', code: createLinkCode(t.eco, { robloxUserId: '1001' }).code });
  assert.throws(() => staffRemoveLink(t.eco, { actor: 'staff', robloxUserId: '1001', reason: 'x' }), /reason/);
  staffRemoveLink(t.eco, { actor: 'staff', robloxUserId: '1001', reason: 'Lost Discord account, ticket 12' });
  assert.equal(activeLinkByRoblox(t.eco, '1001'), null);
  assert.throws(() => requestLinkRemoval(t.eco, { discordId: 'd1' }), UserError);
});
