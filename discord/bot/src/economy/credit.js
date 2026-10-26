// Credit scores, loans and credit cards.
//
// Accounting model: each loan or card has its own account that is allowed to go negative.
// Its balance is minus the amount owed. Paying out a loan moves money from the loan account into
// the borrower's account (new money is created), repayments move it back (money is removed), and
// interest and late fees are booked from the loan account to the Central Bank.
import { CREDIT_BANDS, CREDIT_RULES, NEUTRAL_POLICY_RATE_BP, STARTING_CREDIT_SCORE } from './constants.js';
import { createAccount, transfer, tryTransfer, getAccount, systemAccountId } from './ledger.js';
import { personalAccountId, requireCitizen, getCitizen, touchCitizen } from './citizens.js';
import { getPolicy } from './policy.js';
import { requireBusinessAccess, getBusiness } from './businesses.js';
import { formatKGD } from './money.js';
import { UserError, PermissionError } from './errors.js';
import { audit } from './audit.js';

const INCOME_CATEGORIES = ['wage', 'business_distribution', 'rent_income'];

export function creditBand(score) {
  return CREDIT_BANDS.find((b) => score >= b.min && score <= b.max) ?? CREDIT_BANDS[0];
}

export function lendingRateBp(eco, score) {
  const policy = getPolicy(eco, 'policy_rate_bp');
  return Math.max(100, creditBand(score).rateBp + (policy - NEUTRAL_POLICY_RATE_BP));
}

function outstanding(eco, facility) {
  if (!facility.account_id) return 0;
  return Math.max(0, -getAccount(eco, facility.account_id).balance);
}

export function getFacility(eco, id) {
  return eco.db.prepare('SELECT * FROM credit_facilities WHERE id = ?').get(id) ?? null;
}

// Verified net income over the last 30 days, scaled to a 30-day month.
// Returns { monthly, historyDays } or monthly = null when there is not enough history yet.
export function verifiedMonthlyIncome(eco, borrowerType, borrowerId, day = eco.currentDay()) {
  if (borrowerType === 'citizen') {
    const c = getCitizen(eco, borrowerId);
    if (!c) return { monthly: null, historyDays: 0 };
    const historyDays = Math.min(30, day - c.registered_day + 1);
    const bank = personalAccountId(eco, borrowerId, 'bank');
    const ph = INCOME_CATEGORIES.map(() => '?').join(',');
    const income = Number(eco.db.prepare(`SELECT COALESCE(SUM(amount), 0) AS s FROM transactions
      WHERE to_account = ? AND econ_day > ? AND (category IN (${ph}) OR category LIKE 'public_wage:%')`).get(bank, day - 30, ...INCOME_CATEGORIES).s);
    const tax = Number(eco.db.prepare(`SELECT COALESCE(SUM(amount), 0) AS s FROM transactions WHERE from_account = ? AND econ_day > ? AND category = 'income_tax'`).get(bank, day - 30).s);
    if (historyDays < CREDIT_RULES.minHistoryDays) return { monthly: null, historyDays };
    return { monthly: Math.round(((income - tax) * 30) / historyDays), historyDays };
  }
  const b = getBusiness(eco, Number(borrowerId));
  if (!b?.account_id) return { monthly: null, historyDays: 0 };
  const historyDays = Math.min(30, day - (b.decided_day ?? day) + 1);
  if (historyDays < CREDIT_RULES.minHistoryDays) return { monthly: null, historyDays };
  const flows = eco.db.prepare(`SELECT
      COALESCE(SUM(CASE WHEN to_account = ? AND category NOT IN ('business_capital','loan_disbursement') THEN amount END), 0) AS inflow,
      COALESCE(SUM(CASE WHEN from_account = ? AND category NOT IN ('business_distribution','state_dividend','distribution_tax','loan_repayment') THEN amount END), 0) AS outflow
    FROM transactions WHERE (to_account = ? OR from_account = ?) AND econ_day > ?`).get(b.account_id, b.account_id, b.account_id, b.account_id, day - 30);
  return { monthly: Math.round(((Number(flows.inflow) - Number(flows.outflow)) * 30) / historyDays), historyDays };
}

// Scheduled monthly debt payments (loan installments + card minimum payments), per 30 days.
export function monthlyDebtObligations(eco, borrowerType, borrowerId) {
  const rows = eco.db.prepare(`SELECT * FROM credit_facilities WHERE borrower_type = ? AND borrower_id = ? AND status IN ('active','defaulted')`).all(borrowerType, String(borrowerId));
  let total = 0;
  for (const f of rows) {
    if (f.type === 'loan') total += (f.installment * 30) / CREDIT_RULES.installmentIntervalDays;
    else total += (cardMinimumPayment(outstanding(eco, f)) * 30) / CREDIT_RULES.installmentIntervalDays;
  }
  return Math.round(total);
}

export function cardMinimumPayment(owed) {
  if (owed <= 0) return 0;
  return Math.min(owed, Math.max(Math.round(owed * CREDIT_RULES.cardMinPaymentRate), CREDIT_RULES.cardMinPayment));
}

// Fixed weekly installment for an annuity loan.
export function weeklyInstallment(principal, annualRateBp, weeks) {
  const r = (annualRateBp / 10000) * (CREDIT_RULES.installmentIntervalDays / CREDIT_RULES.daysPerYear);
  if (r === 0) return Math.ceil(principal / weeks);
  return Math.ceil((principal * r) / (1 - (1 + r) ** -weeks));
}

function borrowerOwnerUserId(eco, f) {
  if (f.borrower_type === 'citizen') return f.borrower_id;
  return getBusiness(eco, Number(f.borrower_id))?.owner_id ?? null;
}

function recordCreditEvent(eco, userId, day, type, refType, refId, detail = null) {
  if (!userId) return;
  eco.db.prepare('INSERT INTO credit_events (user_id, econ_day, type, ref_type, ref_id, detail) VALUES (?, ?, ?, ?, ?, ?)').run(userId, day, type, refType, String(refId), detail);
}
export { recordCreditEvent };

// Checks every lending rule. Returns { ok, reasons[], rateBp, installment, band, income, obligations }.
export function assessLoan(eco, { borrowerType, borrowerId, scoreUserId, amount, weeks }) {
  const reasons = [];
  const citizen = getCitizen(eco, scoreUserId);
  const score = citizen?.credit_score ?? STARTING_CREDIT_SCORE;
  const band = creditBand(score);
  const rateBp = lendingRateBp(eco, score);
  if (!Number.isInteger(weeks) || weeks < CREDIT_RULES.minTermWeeks || weeks > CREDIT_RULES.maxTermWeeks) {
    reasons.push(`The term must be ${CREDIT_RULES.minTermWeeks}-${CREDIT_RULES.maxTermWeeks} weeks.`);
  }
  if (amount > band.maxLoan) reasons.push(`Your credit rating (${band.label}, ${score}) allows loans up to ${formatKGD(band.maxLoan)}.`);
  const active = eco.db.prepare(`SELECT status FROM credit_facilities WHERE borrower_type = ? AND borrower_id = ? AND status IN ('pending','active','defaulted')`).all(borrowerType, String(borrowerId));
  if (active.some((f) => f.status === 'defaulted')) reasons.push('There is a credit facility in default. It must be settled first.');
  if (active.some((f) => f.status === 'pending')) reasons.push('There is already a pending credit application.');
  const activeLoans = eco.db.prepare(`SELECT COUNT(*) AS n FROM credit_facilities WHERE type = 'loan' AND borrower_type = ? AND borrower_id = ? AND status = 'active'`).get(borrowerType, String(borrowerId)).n;
  if (activeLoans >= CREDIT_RULES.maxActiveLoans) reasons.push(`At most ${CREDIT_RULES.maxActiveLoans} loans can be active at the same time.`);
  const income = verifiedMonthlyIncome(eco, borrowerType, borrowerId);
  const installment = weeks >= 1 ? weeklyInstallment(amount, rateBp, weeks) : 0;
  const obligations = monthlyDebtObligations(eco, borrowerType, borrowerId);
  const newMonthly = (installment * 30) / CREDIT_RULES.installmentIntervalDays;
  if (income.monthly === null) {
    reasons.push(`At least ${CREDIT_RULES.minHistoryDays} days of recorded income history are needed (currently ${income.historyDays}).`);
  } else if (income.monthly <= 0 || (obligations + newMonthly) / income.monthly > CREDIT_RULES.maxDebtToIncome) {
    reasons.push(`Monthly debt payments would be ${formatKGD(Math.round(obligations + newMonthly))}, more than ${Math.round(CREDIT_RULES.maxDebtToIncome * 100)}% of verified monthly net income (${formatKGD(Math.max(0, income.monthly ?? 0))}).`);
  }
  return { ok: reasons.length === 0, reasons, rateBp, installment, band, score, income, obligations };
}

// Loan application. Small loans that pass every check are paid out immediately;
// larger ones wait for a credit officer.
export function applyForLoan(eco, { applicantId, amount, weeks, purpose = null, businessId = null }) {
  return eco.tx(() => {
    requireCitizen(eco, applicantId, 'You');
    let borrowerType = 'citizen';
    let borrowerId = applicantId;
    let repayAccount = personalAccountId(eco, applicantId, 'bank');
    if (businessId) {
      const b = requireBusinessAccess(eco, businessId, applicantId, 'owner', { allowSuspended: false });
      borrowerType = 'business';
      borrowerId = String(b.id);
      repayAccount = b.account_id;
    }
    const a = assessLoan(eco, { borrowerType, borrowerId, scoreUserId: applicantId, amount, weeks });
    const day = eco.currentDay();
    const insert = eco.db.prepare(`INSERT INTO credit_facilities (type, borrower_type, borrower_id, applicant_id, repay_account_id, principal, annual_rate_bp, term_weeks, installment, status, purpose, applied_day, decided_day, decided_by, decision_reason)
      VALUES ('loan', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
    if (!a.ok) {
      const res = insert.run(borrowerType, borrowerId, applicantId, repayAccount, amount, a.rateBp, weeks, a.installment, 'rejected', purpose, day, day, 'system', a.reasons.join(' '));
      return { status: 'rejected', id: Number(res.lastInsertRowid), assessment: a };
    }
    const pending = amount > CREDIT_RULES.autoApproveLimit;
    const res = insert.run(borrowerType, borrowerId, applicantId, repayAccount, amount, a.rateBp, weeks, a.installment, 'pending', purpose, day, null, null, null);
    const id = Number(res.lastInsertRowid);
    touchCitizen(eco, applicantId);
    if (pending) return { status: 'pending', id, assessment: a };
    disburse(eco, id, 'system', 'Automatic approval within limits');
    return { status: 'active', id, assessment: a };
  });
}

function disburse(eco, id, actor, reason) {
  const f = getFacility(eco, id);
  const day = eco.currentDay();
  const changed = eco.db.prepare("UPDATE credit_facilities SET status = 'active', decided_day = ?, decided_by = ?, decision_reason = ?, start_day = ? WHERE id = ? AND status = 'pending'")
    .run(day, actor, reason, day, id).changes;
  if (!changed) throw new UserError('This application is no longer pending.');
  const accountId = createAccount(eco, { kind: 'loan', ownerType: f.borrower_type, ownerId: f.borrower_id, name: `Loan #${id}`, creditLimit: null, inMoneySupply: false });
  eco.db.prepare('UPDATE credit_facilities SET account_id = ? WHERE id = ?').run(accountId, id);
  transfer(eco, { from: accountId, to: f.repay_account_id, amount: f.principal, actor, category: 'loan_disbursement',
    memo: `Loan #${id} paid out`, refType: 'credit', refId: id, key: `disburse:${id}` });
}

export function pendingLoans(eco) {
  return eco.db.prepare("SELECT * FROM credit_facilities WHERE status = 'pending' ORDER BY id").all();
}

export function approveLoan(eco, { id, actor, reason }) {
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  return eco.tx(() => {
    const f = getFacility(eco, id);
    if (!f || f.status !== 'pending') throw new UserError('No pending application with that number.');
    if (f.applicant_id === actor || borrowerOwnerUserId(eco, f) === actor) throw new PermissionError('You cannot approve your own credit application.');
    // Re-check: the borrower's situation may have changed since applying.
    eco.db.prepare("UPDATE credit_facilities SET status = 'rejected', decided_by = 'recheck' WHERE id = ?").run(id);
    const a = assessLoan(eco, { borrowerType: f.borrower_type, borrowerId: f.borrower_id, scoreUserId: f.applicant_id, amount: f.principal, weeks: f.term_weeks });
    if (!a.ok) throw new UserError(`The application no longer meets the lending rules: ${a.reasons.join(' ')}`);
    eco.db.prepare("UPDATE credit_facilities SET status = 'pending', decided_by = NULL, annual_rate_bp = ?, installment = ? WHERE id = ?").run(a.rateBp, a.installment, id);
    disburse(eco, id, actor, reason);
    audit(eco, { actor, action: 'credit.approve', target: `credit:${id}`, amount: f.principal, reason });
    return getFacility(eco, id);
  });
}

export function rejectLoan(eco, { id, actor, reason }) {
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  return eco.tx(() => {
    const f = getFacility(eco, id);
    if (!f || f.status !== 'pending') throw new UserError('No pending application with that number.');
    eco.db.prepare("UPDATE credit_facilities SET status = 'rejected', decided_day = ?, decided_by = ?, decision_reason = ? WHERE id = ?").run(eco.currentDay(), actor, reason, id);
    audit(eco, { actor, action: 'credit.reject', target: `credit:${id}`, amount: f.principal, reason });
    return f;
  });
}

// Voluntary repayment (any amount up to what is owed).
export function repay(eco, { id, userId, amount }) {
  return eco.tx(() => {
    const f = getFacility(eco, id);
    if (!f || !['active', 'defaulted'].includes(f.status)) throw new UserError('No active credit facility with that number.');
    if (f.borrower_type === 'citizen' && f.borrower_id !== userId) throw new PermissionError('That is not your credit facility.');
    if (f.borrower_type === 'business') requireBusinessAccess(eco, Number(f.borrower_id), userId, 'owner');
    const owed = outstanding(eco, f);
    if (owed <= 0) throw new UserError('Nothing is owed on this facility.');
    const pay = Math.min(amount, owed);
    transfer(eco, { from: f.repay_account_id, to: f.account_id, amount: pay, actor: userId, category: 'loan_repayment',
      memo: `Repayment on ${f.type} #${id}`, refType: 'credit', refId: id });
    const remaining = owed - pay;
    if (remaining === 0 && f.type === 'loan') {
      eco.db.prepare("UPDATE credit_facilities SET status = 'repaid', closed_day = ?, consecutive_missed = 0 WHERE id = ?").run(eco.currentDay(), id);
      recordCreditEvent(eco, borrowerOwnerUserId(eco, f), eco.currentDay(), 'repaid', 'credit', id);
    } else if (f.status === 'defaulted' && remaining === 0) {
      eco.db.prepare("UPDATE credit_facilities SET status = 'closed', closed_day = ? WHERE id = ?").run(eco.currentDay(), id);
      recordCreditEvent(eco, borrowerOwnerUserId(eco, f), eco.currentDay(), 'repaid', 'credit', id);
    }
    touchCitizen(eco, userId);
    return { paid: pay, remaining };
  });
}

export function applyForCard(eco, { userId }) {
  return eco.tx(() => {
    const c = requireCitizen(eco, userId, 'You');
    const existing = eco.db.prepare("SELECT * FROM credit_facilities WHERE type = 'card' AND borrower_type = 'citizen' AND borrower_id = ? AND status IN ('pending','active','defaulted')").get(userId);
    if (existing) throw new UserError('You already have a credit card.');
    const band = creditBand(c.credit_score);
    const income = verifiedMonthlyIncome(eco, 'citizen', userId);
    const reasons = [];
    if (band.cardLimit <= 0) reasons.push(`Your credit rating (${band.label}, ${c.credit_score}) does not qualify for a card.`);
    if (income.monthly === null) reasons.push(`At least ${CREDIT_RULES.minHistoryDays} days of recorded income history are needed.`);
    const defaulted = eco.db.prepare("SELECT 1 FROM credit_facilities WHERE borrower_type = 'citizen' AND borrower_id = ? AND status = 'defaulted'").get(userId);
    if (defaulted) reasons.push('There is a credit facility in default.');
    const limit = Math.floor(Math.min(band.cardLimit, Math.max(0, (income.monthly ?? 0) * 0.5)) / 10000) * 10000;
    if (!reasons.length && limit < 10000) reasons.push('Your verified income is too low for a card (minimum limit 100.00 KGD).');
    const day = eco.currentDay();
    const rateBp = lendingRateBp(eco, c.credit_score);
    if (reasons.length) {
      eco.db.prepare(`INSERT INTO credit_facilities (type, borrower_type, borrower_id, applicant_id, repay_account_id, principal, annual_rate_bp, status, applied_day, decided_day, decided_by, decision_reason)
        VALUES ('card', 'citizen', ?, ?, ?, 0, ?, 'rejected', ?, ?, 'system', ?)`).run(userId, userId, personalAccountId(eco, userId, 'bank'), rateBp, day, day, reasons.join(' '));
      return { status: 'rejected', reasons };
    }
    const accountId = createAccount(eco, { kind: 'credit_card', ownerType: 'citizen', ownerId: userId, name: `Credit card of ${c.display_name}`,
      creditLimit: Math.round(limit * (1 + CREDIT_RULES.cardHeadroomFactor)), inMoneySupply: false });
    const res = eco.db.prepare(`INSERT INTO credit_facilities (type, borrower_type, borrower_id, applicant_id, account_id, repay_account_id, principal, annual_rate_bp, status, applied_day, decided_day, decided_by, decision_reason, start_day)
      VALUES ('card', 'citizen', ?, ?, ?, ?, ?, ?, 'active', ?, ?, 'system', 'Automatic approval within limits', ?)`)
      .run(userId, userId, accountId, personalAccountId(eco, userId, 'bank'), limit, rateBp, day, day, day);
    touchCitizen(eco, userId);
    return { status: 'active', id: Number(res.lastInsertRowid), limit, rateBp };
  });
}

export function facilitiesOf(eco, borrowerType, borrowerId) {
  return eco.db.prepare(`SELECT * FROM credit_facilities WHERE borrower_type = ? AND borrower_id = ? AND status IN ('pending','active','defaulted') ORDER BY id`)
    .all(borrowerType, String(borrowerId)).map((f) => ({ ...f, outstanding: outstanding(eco, f) }));
}

export function facilitiesForUser(eco, userId) {
  return eco.db.prepare(`SELECT * FROM credit_facilities WHERE status IN ('pending','active','defaulted')
    AND ((borrower_type = 'citizen' AND borrower_id = ?) OR (borrower_type = 'business' AND applicant_id = ?)) ORDER BY id`)
    .all(userId, userId).map((f) => ({ ...f, outstanding: outstanding(eco, f) }));
}

// Daily processing: interest accrual, scheduled installments, card minimum payments, defaults.
export function processCredit(eco, day, { late = false } = {}) {
  const out = { interest: 0, collected: 0, missed: 0, defaults: [], repaid: 0 };
  const cb = systemAccountId(eco, 'central_bank');
  const facilities = eco.db.prepare("SELECT * FROM credit_facilities WHERE status = 'active' AND start_day < ? ORDER BY id").all(day);
  for (const f of facilities) {
    const owed = outstanding(eco, f);
    // 1. Daily interest on the amount owed.
    const interest = Math.round((owed * f.annual_rate_bp) / 10000 / CREDIT_RULES.daysPerYear);
    if (interest > 0) {
      const ok = tryTransfer(eco, { from: f.account_id, to: cb, amount: interest, system: true, day, category: 'credit_interest',
        memo: `Interest on ${f.type} #${f.id}`, refType: 'credit', refId: f.id, key: `interest:${day}:${f.id}` });
      if (ok) out.interest += interest;
    }
    // 2. Weekly payment date.
    const elapsed = day - f.start_day;
    if (elapsed % CREDIT_RULES.installmentIntervalDays !== 0) continue;
    const owedNow = outstanding(eco, f);
    if (owedNow <= 0) {
      if (f.type === 'loan') {
        eco.db.prepare("UPDATE credit_facilities SET status = 'repaid', closed_day = ? WHERE id = ?").run(day, f.id);
        out.repaid += 1;
      }
      continue;
    }
    const due = f.type === 'loan' ? Math.min(f.installment, owedNow) : cardMinimumPayment(owedNow);
    const paid = tryTransfer(eco, { from: f.repay_account_id, to: f.account_id, amount: due, system: true, day, category: 'loan_repayment',
      memo: `Scheduled payment on ${f.type} #${f.id}`, refType: 'credit', refId: f.id, key: `installment:${day}:${f.id}` });
    const userId = borrowerOwnerUserId(eco, f);
    if (paid) {
      out.collected += due;
      eco.db.prepare('UPDATE credit_facilities SET consecutive_missed = 0 WHERE id = ?').run(f.id);
      recordCreditEvent(eco, userId, day, 'on_time', 'credit', f.id);
      if (f.type === 'loan' && outstanding(eco, f) === 0) {
        eco.db.prepare("UPDATE credit_facilities SET status = 'repaid', closed_day = ? WHERE id = ?").run(day, f.id);
        recordCreditEvent(eco, userId, day, 'repaid', 'credit', f.id);
        out.repaid += 1;
      }
      continue;
    }
    out.missed += 1;
    if (late) continue; // no penalties for days processed late after bot downtime
    const fee = Math.max(CREDIT_RULES.lateFeeMin, Math.round(due * CREDIT_RULES.lateFeeRate));
    tryTransfer(eco, { from: f.account_id, to: cb, amount: fee, system: true, day, category: 'late_fee',
      memo: `Late fee on ${f.type} #${f.id}`, refType: 'credit', refId: f.id, key: `latefee:${day}:${f.id}` });
    const missed = f.consecutive_missed + 1;
    eco.db.prepare('UPDATE credit_facilities SET consecutive_missed = ?, total_missed = total_missed + 1 WHERE id = ?').run(missed, f.id);
    recordCreditEvent(eco, userId, day, 'missed', 'credit', f.id);
    if (missed >= CREDIT_RULES.defaultAfterMissed) {
      eco.db.prepare("UPDATE credit_facilities SET status = 'defaulted' WHERE id = ?").run(f.id);
      recordCreditEvent(eco, userId, day, 'default', 'credit', f.id);
      audit(eco, { actor: 'system', action: 'credit.default', target: `credit:${f.id}`, amount: outstanding(eco, f), reason: `${missed} consecutive missed payments` });
      out.defaults.push(f.id);
    }
  }
  return out;
}

// Deterministic credit score (300-850) from payment history, debt load, utilisation and activity.
export function computeCreditScore(eco, userId, day = eco.currentDay()) {
  const c = getCitizen(eco, userId);
  if (!c) return STARTING_CREDIT_SCORE;
  const count = (type, since) => Number(eco.db.prepare('SELECT COUNT(*) AS n FROM credit_events WHERE user_id = ? AND type = ? AND econ_day > ?').get(userId, type, day - since).n);
  let score = STARTING_CREDIT_SCORE;
  const parts = {};
  parts.payments = Math.min(120, count('on_time', 90) * 4) - Math.min(250, count('missed', 180) * 25)
    - Math.min(200, count('default', 365) * 100) - Math.min(80, count('eviction', 90) * 40)
    - Math.min(60, count('fine_overdue', 90) * 20) + Math.min(45, count('repaid', 180) * 15);
  const defaultedNow = eco.db.prepare(`SELECT COUNT(*) AS n FROM credit_facilities WHERE status = 'defaulted'
    AND ((borrower_type = 'citizen' AND borrower_id = ?) OR (borrower_type = 'business' AND applicant_id = ?))`).get(userId, userId).n;
  parts.defaults = defaultedNow > 0 ? -100 : 0;
  const cards = eco.db.prepare("SELECT * FROM credit_facilities WHERE type = 'card' AND borrower_type = 'citizen' AND borrower_id = ? AND status IN ('active','defaulted')").all(userId);
  parts.utilisation = 0;
  if (cards.length) {
    const limit = cards.reduce((s, f) => s + f.principal, 0);
    const used = cards.reduce((s, f) => s + outstanding(eco, f), 0);
    const u = limit > 0 ? used / limit : 1;
    parts.utilisation = u < 0.1 ? 15 : u < 0.3 ? 5 : u > 0.9 ? -40 : u > 0.7 ? -20 : 0;
  }
  const income = verifiedMonthlyIncome(eco, 'citizen', userId, day).monthly;
  const obligations = monthlyDebtObligations(eco, 'citizen', userId);
  parts.debtLoad = 0;
  if (obligations > 0) {
    if (!income || income <= 0) parts.debtLoad = -50;
    else {
      const dti = obligations / income;
      parts.debtLoad = dti <= 0.2 ? 15 : dti <= 0.35 ? 0 : dti <= 0.5 ? -25 : -50;
    }
  }
  const ageDays = day - c.registered_day;
  parts.history = Math.min(40, Math.floor(ageDays / 7) * 5);
  const activity = Number(eco.db.prepare(`SELECT COUNT(*) AS n FROM transactions t JOIN accounts a ON (a.id = t.from_account OR a.id = t.to_account)
    WHERE a.owner_type = 'citizen' AND a.owner_id = ? AND a.kind IN ('personal_bank','personal_cash') AND t.econ_day > ?`).get(userId, day - 30).n);
  parts.activity = activity >= 10 ? 10 : 0;
  score += Object.values(parts).reduce((s, v) => s + v, 0);
  return { score: Math.max(300, Math.min(850, score)), parts };
}

export function updateAllCreditScores(eco, day) {
  const users = eco.db.prepare('SELECT user_id FROM citizens').all();
  const update = eco.db.prepare('UPDATE citizens SET credit_score = ? WHERE user_id = ?');
  for (const u of users) update.run(computeCreditScore(eco, u.user_id, day).score, u.user_id);
  return users.length;
}

export function creditSummary(eco, day) {
  const active = eco.db.prepare("SELECT * FROM credit_facilities WHERE status IN ('active','defaulted')").all();
  let outstandingTotal = 0;
  let weighted = 0;
  for (const f of active) {
    const o = outstanding(eco, f);
    outstandingTotal += o;
    weighted += o * f.annual_rate_bp;
  }
  const newLoans = eco.db.prepare("SELECT COUNT(*) AS n, COALESCE(SUM(principal), 0) AS v FROM credit_facilities WHERE type = 'loan' AND start_day = ?").get(day);
  return {
    activeFacilities: active.length,
    defaulted: active.filter((f) => f.status === 'defaulted').length,
    outstanding: outstandingTotal,
    avgLendingRateBp: outstandingTotal > 0 ? Math.round(weighted / outstandingTotal) : null,
    newLoans: Number(newLoans.n),
    newLoanValue: Number(newLoans.v),
  };
}
