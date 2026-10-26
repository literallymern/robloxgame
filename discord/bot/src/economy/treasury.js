// National treasury: budgets, spending requests with two-person approval, and public-finance views.
import { BUDGET_CATEGORIES, BUDGET_PERIOD_DAYS } from './constants.js';
import { transfer, systemAccountId, getAccount } from './ledger.js';
import { getInvoice } from './invoices.js';
import { requireBusiness, adjustInventory } from './businesses.js';
import { payAccount } from './payments.js';
import { formatKGD } from './money.js';
import { UserError, PermissionError } from './errors.js';
import { audit } from './audit.js';

// Spending above this amount needs a second authorised official to approve it.
export const APPROVAL_THRESHOLD = 2500000; // 25,000.00 KGD

export function budgetPeriod(day) {
  return Math.floor((day - 1) / BUDGET_PERIOD_DAYS) + 1;
}

export function periodRange(period) {
  const first = (period - 1) * BUDGET_PERIOD_DAYS + 1;
  return { first, last: first + BUDGET_PERIOD_DAYS - 1 };
}

export function setBudget(eco, { actor, category, amount, reason }) {
  if (!BUDGET_CATEGORIES[category]) throw new UserError('Unknown budget category.');
  if (!Number.isInteger(amount) || amount < 0) throw new UserError('Enter a valid amount.');
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  return eco.tx(() => {
    const period = budgetPeriod(eco.currentDay());
    const old = eco.db.prepare('SELECT allocated FROM budget_lines WHERE period = ? AND category = ?').get(period, category);
    eco.db.prepare(`INSERT INTO budget_lines (period, category, allocated, set_by, set_day) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(period, category) DO UPDATE SET allocated = excluded.allocated, set_by = excluded.set_by, set_day = excluded.set_day`)
      .run(period, category, amount, actor, eco.currentDay());
    audit(eco, { actor, action: 'treasury.budget', target: `budget:${period}:${category}`, amount, oldValue: old?.allocated ?? null, newValue: amount, reason });
    return { period, category, amount };
  });
}

// Money spent per budget line in a period (discretionary spending and public wages).
export function budgetStatus(eco, period = budgetPeriod(eco.currentDay())) {
  const { first, last } = periodRange(period);
  const treasury = systemAccountId(eco, 'treasury');
  const lines = eco.db.prepare('SELECT * FROM budget_lines WHERE period = ?').all(period);
  const spent = eco.db.prepare(`SELECT category, SUM(amount) AS total FROM transactions
    WHERE from_account = ? AND econ_day BETWEEN ? AND ? AND (category LIKE 'public_spending:%' OR category LIKE 'public_wage:%') GROUP BY category`).all(treasury, first, last);
  const out = {};
  for (const key of Object.keys(BUDGET_CATEGORIES)) out[key] = { allocated: null, discretionary: 0, wages: 0 };
  for (const l of lines) out[l.category].allocated = l.allocated;
  for (const s of spent) {
    const [kind, cat] = s.category.split(':');
    if (!out[cat]) continue;
    if (kind === 'public_wage') out[cat].wages += Number(s.total);
    else out[cat].discretionary += Number(s.total);
  }
  return { period, first, last, lines: out };
}

function checkBudget(eco, category, amount) {
  const status = budgetStatus(eco);
  const line = status.lines[category];
  if (line.allocated === null) throw new UserError(`There is no approved budget for ${BUDGET_CATEGORIES[category]} in budget period ${status.period}. Set one with /treasury budget-set first.`);
  const remaining = line.allocated - line.discretionary;
  if (amount > remaining) throw new UserError(`This exceeds the remaining ${BUDGET_CATEGORIES[category]} budget (${formatKGD(remaining)} left in period ${status.period}).`);
}

function execute(eco, request) {
  const treasury = systemAccountId(eco, 'treasury');
  const memo = `${BUDGET_CATEGORIES[request.category]}: ${request.reason}`;
  if (request.invoice_id) {
    const inv = getInvoice(eco, request.invoice_id);
    if (inv.status !== 'open') throw new UserError(`Invoice #${inv.id} is ${inv.status}.`);
    const issuer = requireBusiness(eco, inv.issuer_business_id);
    if (inv.commodity) adjustInventory(eco, issuer.id, inv.commodity, -inv.quantity, `sold to the state on invoice #${inv.id}`, 'invoice', inv.id);
    payAccount(eco, { fromAccount: treasury, toAccount: issuer.account_id, amount: inv.amount, actor: request.decided_by ?? request.requested_by,
      memo, businessCategory: `public_spending:${request.category}`, refType: 'invoice', refId: inv.id, commodity: inv.commodity, quantity: inv.quantity, key: `invoice:${inv.id}` });
    eco.db.prepare("UPDATE invoices SET status = 'paid', paid_day = ?, paid_by = ? WHERE id = ?").run(eco.currentDay(), request.decided_by ?? request.requested_by, inv.id);
    return;
  }
  const payee = getAccount(eco, request.payee_account);
  if (payee.kind === 'business') {
    payAccount(eco, { fromAccount: treasury, toAccount: payee.id, amount: request.amount, actor: request.decided_by ?? request.requested_by,
      memo, businessCategory: `public_spending:${request.category}`, refType: 'spending', refId: request.id, key: `spend:${request.id}` });
  } else {
    transfer(eco, { from: treasury, to: payee.id, amount: request.amount, actor: request.decided_by ?? request.requested_by,
      category: `public_spending:${request.category}`, memo, refType: 'spending', refId: request.id, key: `spend:${request.id}` });
  }
}

// Creates a spending request. Up to the threshold it is executed at once; above it a second
// authorised official must approve it.
export function requestSpending(eco, { actor, payeeAccount = null, invoiceId = null, amount = null, category, reason }) {
  if (!BUDGET_CATEGORIES[category]) throw new UserError('Unknown budget category.');
  const r = String(reason ?? '').trim();
  if (r.length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  return eco.tx(() => {
    let payee = payeeAccount;
    let value = amount;
    if (invoiceId) {
      const inv = getInvoice(eco, invoiceId);
      if (inv.payer_type !== 'state') throw new UserError('That invoice is not addressed to the state.');
      if (inv.status !== 'open') throw new UserError(`Invoice #${inv.id} is ${inv.status}.`);
      const pendingForInvoice = eco.db.prepare("SELECT 1 FROM spending_requests WHERE invoice_id = ? AND status = 'pending'").get(inv.id);
      if (pendingForInvoice) throw new UserError('A payment request for this invoice is already waiting for approval.');
      payee = requireBusiness(eco, inv.issuer_business_id).account_id;
      value = inv.amount;
    }
    if (!payee || !Number.isInteger(value) || value <= 0) throw new UserError('Choose a recipient and an amount.');
    const payeeAcc = getAccount(eco, payee);
    if (!['personal_bank', 'business'].includes(payeeAcc.kind)) throw new UserError('Public money can only be paid to a citizen\'s bank account or a business.');
    checkBudget(eco, category, value);
    const day = eco.currentDay();
    const needsApproval = value > APPROVAL_THRESHOLD;
    const res = eco.db.prepare(`INSERT INTO spending_requests (requested_by, payee_account, amount, category, reason, invoice_id, status, created_day)
      VALUES (?, ?, ?, ?, ?, ?, 'pending', ?)`).run(actor, payee, value, category, r.slice(0, 300), invoiceId, day);
    const id = Number(res.lastInsertRowid);
    audit(eco, { actor, action: 'treasury.request', target: `spending:${id}`, amount: value, newValue: { category, payee: payeeAcc.name, invoiceId }, reason: r });
    if (needsApproval) return { id, status: 'pending', amount: value };
    const request = eco.db.prepare('SELECT * FROM spending_requests WHERE id = ?').get(id);
    execute(eco, request);
    eco.db.prepare("UPDATE spending_requests SET status = 'executed', decided_by = ?, decided_day = ?, note = 'Below approval threshold' WHERE id = ?").run(actor, day, id);
    return { id, status: 'executed', amount: value };
  });
}

export function approveSpending(eco, { id, actor }) {
  return eco.tx(() => {
    const req = eco.db.prepare('SELECT * FROM spending_requests WHERE id = ?').get(id);
    if (!req || req.status !== 'pending') throw new UserError('No pending spending request with that number.');
    if (req.requested_by === actor) throw new PermissionError('A second official must approve this request. You cannot approve your own request.');
    const payee = getAccount(eco, req.payee_account);
    if (payee.owner_id === actor) throw new PermissionError('You cannot approve a payment to yourself.');
    checkBudget(eco, req.category, req.amount);
    execute(eco, { ...req, decided_by: actor });
    eco.db.prepare("UPDATE spending_requests SET status = 'executed', decided_by = ?, decided_day = ? WHERE id = ?").run(actor, eco.currentDay(), id);
    audit(eco, { actor, action: 'treasury.approve', target: `spending:${id}`, amount: req.amount, reason: req.reason });
    return req;
  });
}

export function rejectSpending(eco, { id, actor, reason }) {
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  return eco.tx(() => {
    const req = eco.db.prepare('SELECT * FROM spending_requests WHERE id = ?').get(id);
    if (!req || req.status !== 'pending') throw new UserError('No pending spending request with that number.');
    eco.db.prepare("UPDATE spending_requests SET status = 'rejected', decided_by = ?, decided_day = ?, note = ? WHERE id = ?").run(actor, eco.currentDay(), reason, id);
    audit(eco, { actor, action: 'treasury.reject', target: `spending:${id}`, amount: req.amount, reason });
    return req;
  });
}

export function pendingSpending(eco) {
  return eco.db.prepare("SELECT s.*, a.name AS payee_name FROM spending_requests s JOIN accounts a ON a.id = s.payee_account WHERE s.status = 'pending' ORDER BY s.id").all();
}

// Revenue and expenditure of the treasury between two days (inclusive), by category.
export function treasuryFlows(eco, firstDay, lastDay = firstDay) {
  const t = systemAccountId(eco, 'treasury');
  const revenue = eco.db.prepare(`SELECT category, SUM(amount) AS total FROM transactions WHERE to_account = ? AND econ_day BETWEEN ? AND ? AND category <> 'genesis_issuance' GROUP BY category ORDER BY total DESC`).all(t, firstDay, lastDay);
  const expenditure = eco.db.prepare(`SELECT category, SUM(amount) AS total FROM transactions WHERE from_account = ? AND econ_day BETWEEN ? AND ? GROUP BY category ORDER BY total DESC`).all(t, firstDay, lastDay);
  const sum = (rows) => rows.reduce((s, r) => s + Number(r.total), 0);
  return {
    revenue: Object.fromEntries(revenue.map((r) => [r.category, Number(r.total)])),
    expenditure: Object.fromEntries(expenditure.map((r) => [r.category, Number(r.total)])),
    totalRevenue: sum(revenue),
    totalExpenditure: sum(expenditure),
    balance: getAccount(eco, t).balance,
  };
}

// Emergency monetary financing by the Central Bank. Owner only; always audited.
export function centralBankIssuance(eco, { actor, amount, reason }) {
  if (!reason || reason.trim().length < 10) throw new UserError('Please give a detailed reason (at least 10 characters).');
  return eco.tx(() => {
    const id = transfer(eco, { from: systemAccountId(eco, 'central_bank'), to: systemAccountId(eco, 'treasury'), amount, actor,
      category: 'central_bank_financing', memo: reason });
    audit(eco, { actor, action: 'treasury.central_bank_financing', target: 'treasury', amount, reason, result: { transaction: id } });
    return id;
  });
}
