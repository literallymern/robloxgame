// Fines issued by police authorities and courts. Paid to the treasury.
import { FINE_RULES } from './constants.js';
import { transfer, tryTransfer, systemAccountId } from './ledger.js';
import { personalAccountId, requireCitizen, touchCitizen } from './citizens.js';
import { recordCreditEvent } from './credit.js';
import { formatKGD } from './money.js';
import { UserError, PermissionError } from './errors.js';
import { audit } from './audit.js';

export function issueFine(eco, { issuerId, authority, userId, amount, reason, caseRef = null }) {
  if (issuerId === userId) throw new PermissionError('You cannot fine yourself.');
  if (amount > FINE_RULES.maxFine) throw new UserError(`Fines are limited to ${formatKGD(FINE_RULES.maxFine)}. Larger penalties need a court judgment.`);
  const r = String(reason ?? '').trim();
  if (r.length < 5) throw new UserError('Give the reason for the fine (at least 5 characters).');
  return eco.tx(() => {
    requireCitizen(eco, userId, 'That person');
    const day = eco.currentDay();
    const res = eco.db.prepare(`INSERT INTO fines (user_id, amount, reason, case_ref, issued_by, authority, issued_day, due_day, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'unpaid')`).run(userId, amount, r.slice(0, 300), caseRef, issuerId, authority, day, day + FINE_RULES.dueAfterDays);
    const id = Number(res.lastInsertRowid);
    audit(eco, { actor: issuerId, action: 'fine.issue', target: `fine:${id}`, amount, reason: r, newValue: { userId, authority, caseRef } });
    return { id, dueDay: day + FINE_RULES.dueAfterDays };
  });
}

export function finesOf(eco, userId, { open = true } = {}) {
  const where = open ? "AND status IN ('unpaid','overdue')" : '';
  return eco.db.prepare(`SELECT * FROM fines WHERE user_id = ? ${where} ORDER BY id DESC LIMIT 25`).all(userId);
}

export function payFine(eco, { userId, fineId }) {
  return eco.tx(() => {
    const f = eco.db.prepare('SELECT * FROM fines WHERE id = ?').get(fineId);
    if (!f || f.user_id !== userId || !['unpaid', 'overdue'].includes(f.status)) throw new UserError('No open fine of yours with that number.');
    transfer(eco, { from: personalAccountId(eco, userId, 'bank'), to: systemAccountId(eco, 'treasury'), amount: f.amount, actor: userId,
      category: 'fine', memo: `Fine #${f.id} (${f.authority})`, refType: 'fine', refId: f.id, key: `fine:${f.id}` });
    eco.db.prepare("UPDATE fines SET status = 'paid', paid_day = ? WHERE id = ?").run(eco.currentDay(), f.id);
    touchCitizen(eco, userId);
    return f;
  });
}

export function cancelFine(eco, { fineId, actor, reason }) {
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  return eco.tx(() => {
    const f = eco.db.prepare('SELECT * FROM fines WHERE id = ?').get(fineId);
    if (!f || !['unpaid', 'overdue'].includes(f.status)) throw new UserError('No open fine with that number.');
    eco.db.prepare("UPDATE fines SET status = 'cancelled', cancelled_by = ?, cancel_reason = ? WHERE id = ?").run(actor, reason, f.id);
    audit(eco, { actor, action: 'fine.cancel', target: `fine:${f.id}`, amount: f.amount, reason });
    return f;
  });
}

// Fines past their due date are collected automatically from the bank account when possible.
export function processFines(eco, day, { late = false } = {}) {
  const out = { collected: 0, overdue: 0 };
  const treasury = systemAccountId(eco, 'treasury');
  const rows = eco.db.prepare("SELECT * FROM fines WHERE status IN ('unpaid','overdue') AND due_day <= ? ORDER BY id").all(day);
  for (const f of rows) {
    const ok = tryTransfer(eco, { from: personalAccountId(eco, f.user_id, 'bank'), to: treasury, amount: f.amount, system: true, day,
      category: 'fine', memo: `Fine #${f.id} collected automatically`, refType: 'fine', refId: f.id, key: `fine:${f.id}` });
    if (ok) {
      eco.db.prepare("UPDATE fines SET status = 'paid', paid_day = ? WHERE id = ?").run(day, f.id);
      out.collected += f.amount;
      continue;
    }
    out.overdue += 1;
    if (f.status === 'unpaid') {
      eco.db.prepare("UPDATE fines SET status = 'overdue' WHERE id = ?").run(f.id);
      if (!late) recordCreditEvent(eco, f.user_id, day, 'fine_overdue', 'fine', f.id);
    }
  }
  return out;
}
