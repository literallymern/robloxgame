// AVK - Allgemeine Volksversicherung Kagundi (General People's Insurance of Kagundi).
import { AVK_PRODUCTS, AVK_RULES } from './constants.js';
import { transfer, tryTransfer, systemAccountId, getAccount } from './ledger.js';
import { personalAccountId, requireCitizen, touchCitizen } from './citizens.js';
import { requireBusinessAccess, isManager, getBusiness } from './businesses.js';
import { formatKGD } from './money.js';
import { UserError, PermissionError } from './errors.js';
import { audit } from './audit.js';

export function quote(productKey, insuredValue) {
  const p = AVK_PRODUCTS[productKey];
  if (!p) throw new UserError('Unknown AVK product.');
  if (p.flatDaily) return { product: p, dailyPremium: p.flatDaily, coverage: p.coverage, deductible: p.deductible, insuredValue: p.coverage };
  if (!Number.isInteger(insuredValue) || insuredValue < p.minValue || insuredValue > p.maxValue) {
    throw new UserError(`${p.name}: the insured value must be between ${formatKGD(p.minValue)} and ${formatKGD(p.maxValue)}.`);
  }
  return { product: p, dailyPremium: Math.max(100, Math.round((insuredValue * p.dailyRatePcm) / 100000)), coverage: insuredValue, deductible: p.deductible, insuredValue };
}

// Buys a policy. The first day's premium is charged immediately; later premiums are collected daily.
export function buyPolicy(eco, { userId, product, insuredValue = null, propertyId = null, businessId = null, description = null }) {
  return eco.tx(() => {
    requireCitizen(eco, userId, 'You');
    const p = AVK_PRODUCTS[product];
    if (!p) throw new UserError('Unknown AVK product.');
    let holderType = 'citizen';
    let holderId = userId;
    let payAccount = personalAccountId(eco, userId, 'bank');
    let insuredRef = null;
    let value = insuredValue;
    if (p.needs === 'property') {
      const prop = eco.db.prepare('SELECT * FROM properties WHERE id = ?').get(propertyId);
      if (!prop) throw new UserError('Choose a property you own (property option).');
      if (prop.owner_type === 'citizen' && prop.owner_id === userId) {
        // personal property
      } else if (prop.owner_type === 'business') {
        const b = requireBusinessAccess(eco, Number(prop.owner_id), userId, 'manager', { allowSuspended: false });
        holderType = 'business'; holderId = String(b.id); payAccount = b.account_id;
      } else {
        throw new PermissionError('You can only insure property that you or your business own.');
      }
      insuredRef = `property:${prop.id}`;
      value = prop.value;
    } else if (p.needs === 'business') {
      const b = requireBusinessAccess(eco, businessId, userId, 'manager', { allowSuspended: false });
      holderType = 'business'; holderId = String(b.id); payAccount = b.account_id;
      insuredRef = `business:${b.id}`;
    } else if (product === 'vehicle') {
      const d = String(description ?? '').trim();
      if (d.length < 3 || d.length > 60) throw new UserError('Describe the vehicle (3-60 characters, e.g. model and plate).');
      insuredRef = `vehicle:${d.toLowerCase()}`;
      const vehicles = eco.db.prepare("SELECT COUNT(*) AS n FROM insurance_policies WHERE holder_type = 'citizen' AND holder_id = ? AND product = 'vehicle' AND status = 'active'").get(userId).n;
      if (vehicles >= 3) throw new UserError('You can insure at most 3 vehicles.');
    }
    const q = quote(product, value);
    const duplicate = eco.db.prepare(`SELECT 1 FROM insurance_policies WHERE holder_type = ? AND holder_id = ? AND product = ? AND status = 'active'
      AND COALESCE(insured_ref, '') = COALESCE(?, '')`).get(holderType, holderId, product, insuredRef);
    if (duplicate) throw new UserError('An active policy already covers this.');
    const day = eco.currentDay();
    const res = eco.db.prepare(`INSERT INTO insurance_policies (holder_type, holder_id, product, insured_ref, insured_value, coverage_limit, daily_premium, deductible, status, start_day, pay_account_id)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?)`).run(holderType, holderId, product, insuredRef, q.insuredValue, q.coverage, q.dailyPremium, q.deductible, day, payAccount);
    const id = Number(res.lastInsertRowid);
    transfer(eco, { from: payAccount, to: systemAccountId(eco, 'avk'), amount: q.dailyPremium, actor: userId, category: 'insurance_premium',
      memo: `AVK ${p.name} policy #${id}, first day`, refType: 'policy', refId: id, key: `premium:${day}:${id}` });
    touchCitizen(eco, userId);
    return { id, ...q };
  });
}

function canManagePolicy(eco, policy, userId) {
  if (policy.holder_type === 'citizen') return policy.holder_id === userId;
  const b = getBusiness(eco, Number(policy.holder_id));
  return !!b && (b.owner_id === userId || isManager(eco, b.id, userId));
}

export function policiesForUser(eco, userId) {
  return eco.db.prepare(`SELECT * FROM insurance_policies WHERE status = 'active' AND (
      (holder_type = 'citizen' AND holder_id = ?) OR
      (holder_type = 'business' AND holder_id IN (SELECT CAST(id AS TEXT) FROM businesses WHERE owner_id = ?
         UNION SELECT CAST(business_id AS TEXT) FROM business_managers WHERE user_id = ?))) ORDER BY id`).all(userId, userId, userId);
}

export function cancelPolicy(eco, { policyId, userId }) {
  return eco.tx(() => {
    const p = eco.db.prepare('SELECT * FROM insurance_policies WHERE id = ?').get(policyId);
    if (!p || p.status !== 'active' || !canManagePolicy(eco, p, userId)) throw new UserError('No active policy of yours with that number.');
    const open = eco.db.prepare("SELECT 1 FROM insurance_claims WHERE policy_id = ? AND status = 'submitted'").get(policyId);
    if (open) throw new UserError('This policy has an open claim. Wait for the AVK decision before cancelling.');
    eco.db.prepare("UPDATE insurance_policies SET status = 'cancelled', end_day = ? WHERE id = ?").run(eco.currentDay(), policyId);
    return p;
  });
}

export function fileClaim(eco, { policyId, userId, amount, incidentRef, description, evidence }) {
  return eco.tx(() => {
    const p = eco.db.prepare('SELECT * FROM insurance_policies WHERE id = ?').get(policyId);
    if (!p || p.status !== 'active' || !canManagePolicy(eco, p, userId)) throw new UserError('No active policy of yours with that number.');
    const day = eco.currentDay();
    if (day - p.start_day < AVK_RULES.waitingPeriodDays) throw new UserError(`New policies have a waiting period of ${AVK_RULES.waitingPeriodDays} economic days before claims are accepted.`);
    const ref = String(incidentRef ?? '').trim();
    if (ref.length < 3 || ref.length > 40) throw new UserError('Give the incident or report number (3-40 characters), e.g. the police or Brandwehr report ID.');
    const desc = String(description ?? '').trim();
    const ev = String(evidence ?? '').trim();
    if (desc.length < 10) throw new UserError('Describe what happened (at least 10 characters).');
    if (ev.length < 5) throw new UserError('Provide evidence: a screenshot link or the official report reference.');
    const remaining = p.coverage_limit - p.paid_out_total;
    if (amount > remaining) throw new UserError(`The remaining coverage on this policy is ${formatKGD(remaining)}.`);
    if (eco.db.prepare('SELECT 1 FROM insurance_claims WHERE policy_id = ? AND incident_ref = ?').get(policyId, ref)) {
      throw new UserError('A claim for this incident has already been filed on this policy.');
    }
    const res = eco.db.prepare(`INSERT INTO insurance_claims (policy_id, claimant_id, incident_ref, amount_claimed, description, evidence, status, created_day)
      VALUES (?, ?, ?, ?, ?, ?, 'submitted', ?)`).run(policyId, userId, ref, amount, desc.slice(0, 500), ev.slice(0, 300), day);
    touchCitizen(eco, userId);
    return { id: Number(res.lastInsertRowid), maxPayout: Math.max(0, Math.min(amount, remaining) - p.deductible) };
  });
}

export function openClaims(eco) {
  return eco.db.prepare(`SELECT c.*, p.product, p.holder_type, p.holder_id, p.coverage_limit, p.paid_out_total, p.deductible
    FROM insurance_claims c JOIN insurance_policies p ON p.id = c.policy_id WHERE c.status = 'submitted' ORDER BY c.id`).all();
}

// AVK officer decision. A claim can be paid exactly once.
export function decideClaim(eco, { claimId, actor, approve, payout = null, reason }) {
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  return eco.tx(() => {
    const c = eco.db.prepare('SELECT * FROM insurance_claims WHERE id = ?').get(claimId);
    if (!c || c.status !== 'submitted') throw new UserError('No open claim with that number.');
    const p = eco.db.prepare('SELECT * FROM insurance_policies WHERE id = ?').get(c.policy_id);
    if (c.claimant_id === actor || canManagePolicy(eco, p, actor)) throw new PermissionError('You cannot decide a claim on your own policy.');
    const day = eco.currentDay();
    if (!approve) {
      eco.db.prepare("UPDATE insurance_claims SET status = 'denied', decided_by = ?, decided_day = ?, decision_reason = ? WHERE id = ? AND status = 'submitted'").run(actor, day, reason, claimId);
      audit(eco, { actor, action: 'avk.claim.deny', target: `claim:${claimId}`, amount: c.amount_claimed, reason });
      return { status: 'denied', claim: c };
    }
    const max = Math.max(0, Math.min(c.amount_claimed, p.coverage_limit - p.paid_out_total) - p.deductible);
    const amount = payout === null ? max : payout;
    if (!Number.isInteger(amount) || amount <= 0) throw new UserError(`Nothing can be paid on this claim (deductible ${formatKGD(p.deductible)}).`);
    if (amount > max) throw new UserError(`The maximum payout is ${formatKGD(max)} (claimed amount, remaining coverage and deductible).`);
    const changed = eco.db.prepare("UPDATE insurance_claims SET status = 'paid', decided_by = ?, decided_day = ?, payout = ?, decision_reason = ? WHERE id = ? AND status = 'submitted'")
      .run(actor, day, amount, reason, claimId).changes;
    if (!changed) throw new UserError('This claim was already decided.');
    eco.db.prepare('UPDATE insurance_policies SET paid_out_total = paid_out_total + ? WHERE id = ?').run(amount, p.id);
    const payTo = getAccount(eco, p.pay_account_id);
    transfer(eco, { from: systemAccountId(eco, 'avk'), to: payTo.id, amount, actor, category: 'insurance_payout',
      memo: `AVK payout on claim #${claimId}`, refType: 'claim', refId: claimId, key: `claimpay:${claimId}` });
    audit(eco, { actor, action: 'avk.claim.pay', target: `claim:${claimId}`, amount, reason });
    return { status: 'paid', claim: c, payout: amount };
  });
}

// Daily premium collection. Policies lapse after several unpaid days.
export function processPremiums(eco, day, { late = false } = {}) {
  const out = { collected: 0, missed: 0, lapsed: 0 };
  const avk = systemAccountId(eco, 'avk');
  const policies = eco.db.prepare("SELECT * FROM insurance_policies WHERE status = 'active' AND start_day < ? ORDER BY id").all(day);
  for (const p of policies) {
    const ok = tryTransfer(eco, { from: p.pay_account_id, to: avk, amount: p.daily_premium, system: true, day, category: 'insurance_premium',
      memo: `AVK premium, policy #${p.id}`, refType: 'policy', refId: p.id, key: `premium:${day}:${p.id}` });
    if (ok) {
      out.collected += p.daily_premium;
      if (p.unpaid_days) eco.db.prepare('UPDATE insurance_policies SET unpaid_days = 0 WHERE id = ?').run(p.id);
      continue;
    }
    out.missed += 1;
    if (late) continue;
    const unpaid = p.unpaid_days + 1;
    if (unpaid >= AVK_RULES.lapseAfterUnpaidDays) {
      eco.db.prepare("UPDATE insurance_policies SET status = 'lapsed', unpaid_days = ?, end_day = ? WHERE id = ?").run(unpaid, day, p.id);
      out.lapsed += 1;
    } else {
      eco.db.prepare('UPDATE insurance_policies SET unpaid_days = ? WHERE id = ?').run(unpaid, p.id);
    }
  }
  return out;
}
