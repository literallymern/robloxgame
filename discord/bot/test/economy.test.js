import { test } from 'node:test';
import assert from 'node:assert/strict';
import { testEconomy } from './helpers.js';
import { verifyLedger, getAccount, systemAccountId } from '../src/economy/ledger.js';
import { personalAccountId } from '../src/economy/citizens.js';
import {
  registerBusiness, approveBusiness, rejectBusiness, depositToBusiness, withdrawFromBusiness, sellExport, buyImport, inventoryQty, adjustInventory, closeBusiness,
} from '../src/economy/businesses.js';
import { postJob, applyForJob, hire, clockIn } from '../src/economy/employment.js';
import { citizenPay } from '../src/economy/payments.js';
import { creditBand, lendingRateBp, assessLoan, applyForLoan, weeklyInstallment } from '../src/economy/credit.js';
import { buyPolicy, fileClaim, decideClaim } from '../src/economy/insurance.js';
import { setBudget, requestSpending, approveSpending, APPROVAL_THRESHOLD } from '../src/economy/treasury.js';
import { setPolicy, setCommodityPolicy, getPolicy } from '../src/economy/policy.js';
import { issueFine, payFine } from '../src/economy/fines.js';
import { createInvoice, payInvoice } from '../src/economy/invoices.js';
import { validateEventCatalog, EVENT_CATALOG } from '../src/economy/event-catalog.js';
import { startEvent } from '../src/economy/events.js';
import { catchUp } from '../src/economy/tick.js';
import { KGD, POLICY_DEFAULTS, CREDIT_RULES } from '../src/economy/constants.js';
import { applyBp } from '../src/economy/money.js';

function withBusiness(t, { owner = 'owner', industry = 'mining', output = 'gold' } = {}) {
  t.citizen(owner); t.citizen('official');
  const app = registerBusiness(t.eco, { ownerId: owner, name: `${owner} Works`, industry, output });
  const b = approveBusiness(t.eco, { id: app.id, actor: 'official' });
  return b;
}

test('business registration: fee on approval, no self-approval, rejection costs nothing', () => {
  const t = testEconomy();
  t.citizen('owner'); t.citizen('official');
  const app = registerBusiness(t.eco, { ownerId: 'owner', name: 'Gold Works', industry: 'mining', output: 'gold' });
  assert.equal(t.bank('owner'), POLICY_DEFAULTS.starting_grant);
  assert.throws(() => approveBusiness(t.eco, { id: app.id, actor: 'owner' }), /own business/);
  approveBusiness(t.eco, { id: app.id, actor: 'official' });
  assert.equal(t.bank('owner'), POLICY_DEFAULTS.starting_grant - POLICY_DEFAULTS.registration_fee);
  const app2 = registerBusiness(t.eco, { ownerId: 'owner', name: 'Second Works', industry: 'retail' });
  rejectBusiness(t.eco, { id: app2.id, actor: 'official', reason: 'Name already used in roleplay' });
  assert.equal(t.bank('owner'), POLICY_DEFAULTS.starting_grant - POLICY_DEFAULTS.registration_fee);
  assert.throws(() => registerBusiness(t.eco, { ownerId: 'owner', name: 'Gold Works', industry: 'retail' }), /already exists/);
});

test('business income pays turnover tax; withdrawals pay distribution tax and the state share', () => {
  const t = testEconomy();
  t.citizen('owner'); t.citizen('official'); t.citizen('customer');
  const app = registerBusiness(t.eco, { ownerId: 'owner', name: 'Shop', industry: 'retail' });
  const b = approveBusiness(t.eco, { id: app.id, actor: 'official', stateShareBp: 2000 });
  citizenPay(t.eco, { userId: 'customer', toBusinessId: b.id, amount: KGD(1000), memo: 'goods' });
  const turnover = applyBp(KGD(1000), POLICY_DEFAULTS.turnover_tax_bp);
  assert.equal(getAccount(t.eco, b.account_id).balance, KGD(1000) - turnover);
  const before = t.bank('owner');
  const r = withdrawFromBusiness(t.eco, { businessId: b.id, userId: 'owner', amount: KGD(500) });
  assert.equal(r.stateShare, KGD(100));
  assert.equal(r.tax, applyBp(KGD(400), POLICY_DEFAULTS.distribution_tax_bp));
  assert.equal(t.bank('owner'), before + r.net);
  assert.throws(() => withdrawFromBusiness(t.eco, { businessId: b.id, userId: 'customer', amount: KGD(1) }), /owner/);
  assert.ok(verifyLedger(t.eco).ok);
});

test('production turns shifts into stock; exports pay duty; export bans are enforced', () => {
  const t = testEconomy();
  const b = withBusiness(t);
  t.citizen('miner');
  const job = postJob(t.eco, { businessId: b.id, actor: 'owner', title: 'Miner', wage: KGD(500), slots: 2 });
  hire(t.eco, { applicationId: applyForJob(t.eco, { jobId: job.id, userId: 'miner' }).id, actor: 'owner' });
  depositToBusiness(t.eco, { businessId: b.id, userId: 'owner', amount: KGD(1400) });
  clockIn(t.eco, { userId: 'miner' });
  t.advanceDays(1);
  catchUp(t.eco);
  const gold = inventoryQty(t.eco, b.id, 'gold');
  assert.ok(gold > 0, 'gold was produced');
  const r = sellExport(t.eco, { businessId: b.id, userId: 'owner', commodity: 'gold', quantity: gold, partner: 'germany' });
  assert.equal(r.duty, applyBp(r.gross, POLICY_DEFAULTS.export_duty_bp.gold));
  assert.equal(inventoryQty(t.eco, b.id, 'gold'), 0);
  adjustInventory(t.eco, b.id, 'gold', 5, 'test');
  setCommodityPolicy(t.eco, { key: 'export_ban', commodity: 'gold', value: true, actor: 'sec', reason: 'Reserve policy test' });
  assert.throws(() => sellExport(t.eco, { businessId: b.id, userId: 'owner', commodity: 'gold', quantity: 5, partner: 'eu' }), /banned/);
  assert.throws(() => buyImport(t.eco, { businessId: b.id, userId: 'owner', commodity: 'gold', quantity: 1, partner: 'eu' }), /cannot be imported/);
  assert.ok(verifyLedger(t.eco).ok);
});

test('wage limits and unpaid wages when a business has no money', () => {
  const t = testEconomy();
  const b = withBusiness(t);
  assert.throws(() => postJob(t.eco, { businessId: b.id, actor: 'owner', title: 'Miner', wage: KGD(1), slots: 1 }), /between/);
  t.citizen('w');
  const job = postJob(t.eco, { businessId: b.id, actor: 'owner', title: 'Miner', wage: KGD(500), slots: 1 });
  hire(t.eco, { applicationId: applyForJob(t.eco, { jobId: job.id, userId: 'w' }).id, actor: 'owner' });
  clockIn(t.eco, { userId: 'w' });
  t.advanceDays(1);
  catchUp(t.eco);
  const shift = t.eco.db.prepare("SELECT status FROM shifts WHERE user_id = 'w'").get();
  assert.equal(shift.status, 'unpaid');
  depositToBusiness(t.eco, { businessId: b.id, userId: 'owner', amount: KGD(1000) });
  t.advanceDays(1);
  catchUp(t.eco);
  assert.equal(t.eco.db.prepare("SELECT status FROM shifts WHERE user_id = 'w'").get().status, 'paid');
  assert.ok(verifyLedger(t.eco).ok);
});

test('credit bands, rates and the 35% debt-to-income rule', () => {
  const t = testEconomy();
  assert.equal(creditBand(300).label, 'Very Poor');
  assert.equal(creditBand(600).label, 'Average');
  assert.equal(creditBand(850).label, 'Excellent');
  assert.equal(lendingRateBp(t.eco, 600), 1000);
  assert.equal(lendingRateBp(t.eco, 450), 1800);
  setPolicy(t.eco, { key: 'policy_rate_bp', value: 800, actor: 'sec', reason: 'Inflation rising' });
  assert.equal(lendingRateBp(t.eco, 750), 900);
  t.citizen('a');
  const fresh = assessLoan(t.eco, { borrowerType: 'citizen', borrowerId: 'a', scoreUserId: 'a', amount: KGD(1000), weeks: 4 });
  assert.equal(fresh.ok, false, 'no income history yet');
  // Build income history: 10 days of public wages.
  for (let d = 0; d < 10; d++) { clockIn(t.eco, { userId: 'a', roleKeys: ['city_police'] }); t.advanceDays(1); catchUp(t.eco); }
  const ok = assessLoan(t.eco, { borrowerType: 'citizen', borrowerId: 'a', scoreUserId: 'a', amount: KGD(1000), weeks: 4 });
  assert.equal(ok.ok, true, ok.reasons.join(' '));
  const tooBig = assessLoan(t.eco, { borrowerType: 'citizen', borrowerId: 'a', scoreUserId: 'a', amount: KGD(9000), weeks: 2 });
  assert.equal(tooBig.ok, false);
  assert.match(tooBig.reasons.join(' '), /35%/);
  const loan = applyForLoan(t.eco, { applicantId: 'a', amount: KGD(1000), weeks: 4, purpose: 'car' });
  assert.equal(loan.status, 'active');
  assert.equal(weeklyInstallment(KGD(1000), 0, 4), KGD(250));
  assert.ok(verifyLedger(t.eco).ok);
  assert.ok(CREDIT_RULES.maxDebtToIncome === 0.35);
});

test('AVK: waiting period, one claim per incident, no self-decision, payout exactly once', () => {
  const t = testEconomy();
  t.citizen('holder'); t.citizen('officer');
  const p = buyPolicy(t.eco, { userId: 'holder', product: 'vehicle', insuredValue: KGD(10000), description: 'Benz W123 KG-1234' });
  const claim = { policyId: p.id, userId: 'holder', amount: KGD(3000), incidentRef: 'POL-0042', description: 'Car hit by a truck at the border', evidence: 'police report POL-0042' };
  assert.throws(() => fileClaim(t.eco, claim), /waiting period/);
  t.advanceDays(2); catchUp(t.eco);
  const c = fileClaim(t.eco, claim);
  assert.throws(() => fileClaim(t.eco, claim), /already been filed/);
  assert.throws(() => decideClaim(t.eco, { claimId: c.id, actor: 'holder', approve: true, reason: 'my own claim' }), /own policy/);
  const before = t.bank('holder');
  const r = decideClaim(t.eco, { claimId: c.id, actor: 'officer', approve: true, reason: 'Report verified' });
  assert.equal(r.payout, KGD(3000) - KGD(500));
  assert.equal(t.bank('holder'), before + r.payout);
  assert.throws(() => decideClaim(t.eco, { claimId: c.id, actor: 'officer', approve: true, reason: 'again' }), /No open claim/);
  assert.ok(verifyLedger(t.eco).ok);
});

test('treasury: budget lines and two-person approval above the threshold', () => {
  const t = testEconomy();
  t.citizen('sec1'); t.citizen('sec2'); t.citizen('builder');
  const payee = personalAccountId(t.eco, 'builder');
  assert.throws(() => requestSpending(t.eco, { actor: 'sec1', payeeAccount: payee, amount: KGD(100), category: 'infrastructure', reason: 'Road repair' }), /no approved budget/);
  setBudget(t.eco, { actor: 'sec1', category: 'infrastructure', amount: KGD(50000), reason: 'Road programme' });
  const small = requestSpending(t.eco, { actor: 'sec1', payeeAccount: payee, amount: KGD(100), category: 'infrastructure', reason: 'Road repair' });
  assert.equal(small.status, 'executed');
  const big = requestSpending(t.eco, { actor: 'sec1', payeeAccount: payee, amount: APPROVAL_THRESHOLD + 100, category: 'infrastructure', reason: 'Bridge' });
  assert.equal(big.status, 'pending');
  assert.throws(() => approveSpending(t.eco, { id: big.id, actor: 'sec1' }), /second official/);
  assert.throws(() => approveSpending(t.eco, { id: big.id, actor: 'builder' }), /yourself/);
  approveSpending(t.eco, { id: big.id, actor: 'sec2' });
  assert.throws(() => requestSpending(t.eco, { actor: 'sec1', payeeAccount: payee, amount: KGD(30000), category: 'infrastructure', reason: 'More road works' }), /exceeds the remaining/);
  assert.ok(verifyLedger(t.eco).ok);
});

test('policy changes stay within limits and are audited', () => {
  const t = testEconomy();
  assert.throws(() => setPolicy(t.eco, { key: 'income_tax_bp', value: 9000, actor: 'sec', reason: 'too high' }), /range/);
  assert.throws(() => setPolicy(t.eco, { key: 'income_tax_bp', value: 1200, actor: 'sec', reason: '' }), /reason/);
  setPolicy(t.eco, { key: 'income_tax_bp', value: 1200, actor: 'sec', reason: 'Budget deficit' });
  assert.equal(getPolicy(t.eco, 'income_tax_bp'), 1200);
  assert.equal(t.eco.db.prepare("SELECT COUNT(*) AS n FROM audit_log WHERE action = 'policy.set'").get().n, 1);
});

test('fines and invoices', () => {
  const t = testEconomy();
  t.citizen('cop'); t.citizen('driver');
  assert.throws(() => issueFine(t.eco, { issuerId: 'cop', authority: 'City Police', userId: 'cop', amount: KGD(10), reason: 'Speeding' }), /yourself/);
  const f = issueFine(t.eco, { issuerId: 'cop', authority: 'City Police', userId: 'driver', amount: KGD(150), reason: 'Speeding in Gundiville' });
  payFine(t.eco, { userId: 'driver', fineId: f.id });
  assert.throws(() => payFine(t.eco, { userId: 'driver', fineId: f.id }), /No open fine/);
  const b = withBusiness(t, { owner: 'seller', industry: 'retail', output: null });
  const inv = createInvoice(t.eco, { businessId: b.id, actor: 'seller', payerType: 'citizen', payerId: 'driver', amount: KGD(200), memo: 'Car repair' });
  assert.throws(() => payInvoice(t.eco, { invoiceId: inv.id, actor: 'cop' }), /not addressed/);
  payInvoice(t.eco, { invoiceId: inv.id, actor: 'driver' });
  assert.throws(() => payInvoice(t.eco, { invoiceId: inv.id, actor: 'driver' }), /paid/);
  assert.ok(verifyLedger(t.eco).ok);
});

test('economic events are bounded and never overlap with themselves', () => {
  assert.deepEqual(validateEventCatalog(EVENT_CATALOG), []);
  const t = testEconomy();
  const key = Object.keys(EVENT_CATALOG)[0];
  startEvent(t.eco, { key, startDay: 2, actor: 'staff', reason: 'Test event' });
  assert.throws(() => startEvent(t.eco, { key, startDay: 2, actor: 'staff', reason: 'Test event' }), /already active/);
});

test('closing a business pays out the rest and frees employees', () => {
  const t = testEconomy();
  const b = withBusiness(t, { owner: 'o', industry: 'retail', output: null });
  depositToBusiness(t.eco, { businessId: b.id, userId: 'o', amount: KGD(500) });
  const r = closeBusiness(t.eco, { businessId: b.id, userId: 'o' });
  assert.ok(r.payout.net > 0);
  assert.equal(getAccount(t.eco, b.account_id).balance, 0);
  assert.ok(verifyLedger(t.eco).ok);
});

test('30-day simulation keeps the books balanced', () => {
  const t = testEconomy();
  const b = withBusiness(t);
  depositToBusiness(t.eco, { businessId: b.id, userId: 'owner', amount: KGD(1400) });
  for (const id of ['w1', 'w2', 'cop']) t.citizen(id);
  const job = postJob(t.eco, { businessId: b.id, actor: 'owner', title: 'Miner', wage: KGD(450), slots: 3 });
  for (const w of ['w1', 'w2']) hire(t.eco, { applicationId: applyForJob(t.eco, { jobId: job.id, userId: w }).id, actor: 'owner' });
  for (let d = 0; d < 30; d++) {
    for (const w of ['w1', 'w2']) clockIn(t.eco, { userId: w });
    clockIn(t.eco, { userId: 'cop', roleKeys: ['city_police'] });
    const gold = inventoryQty(t.eco, b.id, 'gold');
    if (gold > 0) sellExport(t.eco, { businessId: b.id, userId: 'owner', commodity: 'gold', quantity: gold, partner: 'germany' });
    t.advanceDays(1);
    catchUp(t.eco);
    assert.ok(verifyLedger(t.eco).ok, `ledger after day ${d + 1}`);
  }
  assert.equal(t.eco.db.prepare('SELECT COUNT(*) AS n FROM econ_days').get().n, 30);
  assert.ok(getAccount(t.eco, systemAccountId(t.eco, 'treasury')).balance > 0);
});
