import { test } from 'node:test';
import assert from 'node:assert/strict';
import { testEconomy } from './helpers.js';
import { transfer, tryTransfer, ledgerSum, verifyLedger, systemAccountId, getAccount } from '../src/economy/ledger.js';
import { personalAccountId } from '../src/economy/citizens.js';
import { citizenPay, withdrawCash, depositCash } from '../src/economy/payments.js';
import { setFrozen, adjustBalance, ADMIN_CORRECTION_LIMIT } from '../src/economy/admin.js';
import { KGD, POLICY_DEFAULTS } from '../src/economy/constants.js';
import { parseAmount, formatKGD } from '../src/economy/money.js';

test('genesis: books balance to zero and the treasury is funded', () => {
  const { eco } = testEconomy();
  assert.equal(ledgerSum(eco), 0);
  assert.ok(verifyLedger(eco).ok);
  assert.ok(getAccount(eco, systemAccountId(eco, 'treasury')).balance > 0);
});

test('starting grant is paid exactly once and only when eligible', () => {
  const t = testEconomy();
  t.citizen('a', { grant: false });
  assert.equal(t.bank('a'), 0);
  t.citizen('a', { grant: true });
  assert.equal(t.bank('a'), POLICY_DEFAULTS.starting_grant);
  t.citizen('a', { grant: true });
  assert.equal(t.bank('a'), POLICY_DEFAULTS.starting_grant);
  assert.ok(verifyLedger(t.eco).ok);
});

test('transfers move money, never create it, and reject overdrafts', () => {
  const t = testEconomy();
  t.citizen('a'); t.citizen('b');
  const before = ledgerSum(t.eco);
  citizenPay(t.eco, { userId: 'a', toUserId: 'b', amount: KGD(100), memo: 'test' });
  assert.equal(t.bank('a'), POLICY_DEFAULTS.starting_grant - KGD(100));
  assert.equal(t.bank('b'), POLICY_DEFAULTS.starting_grant + KGD(100));
  assert.equal(ledgerSum(t.eco), before);
  assert.throws(() => citizenPay(t.eco, { userId: 'a', toUserId: 'b', amount: KGD(1_000_000), memo: 'too much' }), /Insufficient funds/);
  assert.throws(() => citizenPay(t.eco, { userId: 'a', toUserId: 'a', amount: KGD(1), memo: 'self' }), /yourself/);
  assert.ok(verifyLedger(t.eco).ok);
});

test('idempotency key prevents duplicate payments', () => {
  const t = testEconomy();
  t.citizen('a'); t.citizen('b');
  const o = { from: personalAccountId(t.eco, 'a'), to: personalAccountId(t.eco, 'b'), amount: KGD(10), category: 'payment', key: 'same-key' };
  const id1 = transfer(t.eco, o);
  const id2 = transfer(t.eco, o);
  assert.equal(id1, id2);
  assert.equal(t.bank('b'), POLICY_DEFAULTS.starting_grant + KGD(10));
});

test('cash withdrawals and deposits keep the total', () => {
  const t = testEconomy();
  t.citizen('a');
  withdrawCash(t.eco, { userId: 'a', amount: KGD(300) });
  assert.equal(t.cash('a'), KGD(300));
  depositCash(t.eco, { userId: 'a', amount: KGD(100) });
  assert.equal(t.bank('a') + t.cash('a'), POLICY_DEFAULTS.starting_grant);
});

test('frozen accounts block voluntary payments but not scheduled obligations', () => {
  const t = testEconomy();
  t.citizen('a'); t.citizen('b');
  setFrozen(t.eco, { actor: 'admin', userId: 'a', frozen: true, reason: 'fraud check' });
  assert.throws(() => citizenPay(t.eco, { userId: 'a', toUserId: 'b', amount: KGD(1), memo: 'x' }), /frozen/);
  const id = tryTransfer(t.eco, { from: personalAccountId(t.eco, 'a'), to: systemAccountId(t.eco, 'treasury'), amount: KGD(1), category: 'fine', system: true });
  assert.ok(id);
});

test('admin corrections are limited, audited and never make balances negative', () => {
  const t = testEconomy();
  t.citizen('a');
  const acc = personalAccountId(t.eco, 'a');
  assert.throws(() => adjustBalance(t.eco, { actor: 'staff', accountId: acc, amount: ADMIN_CORRECTION_LIMIT + 1, reason: 'ticket 12 duplicated wage' }), /Owner/);
  assert.throws(() => adjustBalance(t.eco, { actor: 'staff', accountId: acc, amount: 100, reason: 'short' }), /reason/);
  adjustBalance(t.eco, { actor: 'staff', accountId: acc, amount: KGD(50), reason: 'ticket 12 lost wage refund' });
  assert.throws(() => adjustBalance(t.eco, { actor: 'staff', accountId: acc, amount: -KGD(999_999), reason: 'ticket 13 remove too much', isOwner: true }), /Insufficient/);
  const audit = t.eco.db.prepare("SELECT * FROM audit_log WHERE action = 'admin.adjust'").all();
  assert.equal(audit.length, 1);
  assert.ok(verifyLedger(t.eco).ok);
});

test('money parsing rejects bad input', () => {
  assert.equal(parseAmount(12.34), 1234);
  assert.throws(() => parseAmount(0), /greater than zero/);
  assert.throws(() => parseAmount(-5), /greater than zero/);
  assert.throws(() => parseAmount(1.234), /two decimal/);
  assert.throws(() => parseAmount(Number.NaN), /valid amount/);
  assert.equal(formatKGD(123456), '1,234.56 KGD');
});
