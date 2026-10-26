// Restricted administrative tools: verified corrections, account freezes, inspection, maintenance mode.
// Every action here is written to the audit log with the actor and the reason.
import { transfer, getAccount, systemAccountId } from './ledger.js';
import { getCitizen, personalAccounts } from './citizens.js';
import { getBusiness } from './businesses.js';
import { facilitiesForUser } from './credit.js';
import { policiesForUser } from './insurance.js';
import { finesOf } from './fines.js';
import { formatKGD } from './money.js';
import { UserError, PermissionError } from './errors.js';
import { audit } from './audit.js';

// Economic administrators may correct up to this amount; larger corrections need the Owner.
export const ADMIN_CORRECTION_LIMIT = 1000000; // 10,000.00 KGD

// Corrects a verified error. Positive amounts are issued by the Central Bank,
// negative amounts are returned to it. Balances can never become negative.
export function adjustBalance(eco, { actor, accountId, amount, reason, isOwner = false }) {
  if (!Number.isInteger(amount) || amount === 0) throw new UserError('Enter a non-zero amount.');
  if (!reason || reason.trim().length < 10) throw new UserError('Corrections need a detailed reason (at least 10 characters), e.g. the ticket or incident reference.');
  if (!isOwner && Math.abs(amount) > ADMIN_CORRECTION_LIMIT) throw new PermissionError(`Corrections above ${formatKGD(ADMIN_CORRECTION_LIMIT)} require the Owner.`);
  return eco.tx(() => {
    const acc = getAccount(eco, accountId);
    if (!['personal_bank', 'personal_cash', 'business', 'treasury', 'avk'].includes(acc.kind)) throw new UserError('This account type cannot be corrected directly.');
    const cb = systemAccountId(eco, 'central_bank');
    const txId = amount > 0
      ? transfer(eco, { from: cb, to: acc.id, amount, actor, category: 'admin_correction', memo: reason, system: true })
      : transfer(eco, { from: acc.id, to: cb, amount: -amount, actor, category: 'admin_correction', memo: reason, system: true });
    const after = getAccount(eco, acc.id).balance;
    audit(eco, { actor, action: 'admin.adjust', target: `account:${acc.id}`, amount, oldValue: acc.balance, newValue: after, reason, result: { transaction: txId, account: acc.name } });
    return { account: acc, before: acc.balance, after, txId };
  });
}

function accountsOfTarget(eco, { userId = null, businessId = null }) {
  if (userId) return personalAccounts(eco, userId).filter((a) => ['personal_bank', 'personal_cash'].includes(a.kind));
  const b = getBusiness(eco, businessId);
  if (!b?.account_id) throw new UserError('Business not found or not active.');
  return [getAccount(eco, b.account_id)];
}

export function setFrozen(eco, { actor, userId = null, businessId = null, frozen, reason }) {
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  return eco.tx(() => {
    const accounts = accountsOfTarget(eco, { userId, businessId });
    if (!accounts.length) throw new UserError('No accounts found.');
    for (const a of accounts) eco.db.prepare('UPDATE accounts SET frozen = ?, frozen_reason = ? WHERE id = ?').run(frozen ? 1 : 0, frozen ? reason : null, a.id);
    audit(eco, { actor, action: frozen ? 'admin.freeze' : 'admin.unfreeze', target: userId ? `citizen:${userId}` : `business:${businessId}`, reason });
    return accounts.length;
  });
}

// Full financial picture of one citizen. Viewing is itself audited.
export function inspectCitizen(eco, { actor, userId, reason }) {
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason for viewing private financial data (at least 5 characters).');
  const c = getCitizen(eco, userId);
  if (!c) throw new UserError('That person has no Kagundi accounts.');
  audit(eco, { actor, action: 'admin.inspect', target: `citizen:${userId}`, reason });
  return {
    citizen: c,
    accounts: personalAccounts(eco, userId),
    credit: facilitiesForUser(eco, userId),
    policies: policiesForUser(eco, userId),
    fines: finesOf(eco, userId),
    businesses: eco.db.prepare('SELECT id, name, status FROM businesses WHERE owner_id = ?').all(userId),
  };
}

export function isMaintenance(eco) {
  return eco.meta('maintenance') === '1';
}

export function setMaintenance(eco, { actor, on, reason }) {
  eco.tx(() => {
    eco.setMeta('maintenance', on ? '1' : '0');
    audit(eco, { actor, action: on ? 'admin.maintenance_on' : 'admin.maintenance_off', reason });
  });
}
