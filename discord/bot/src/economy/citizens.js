// Citizens and their personal accounts (bank + cash wallet).
import { createAccount, systemAccountId, transfer } from './ledger.js';
import { getPolicy } from './policy.js';
import { UserError } from './errors.js';

export function getCitizen(eco, userId) {
  return eco.db.prepare('SELECT * FROM citizens WHERE user_id = ?').get(userId) ?? null;
}

export function requireCitizen(eco, userId, who = 'This person') {
  const c = getCitizen(eco, userId);
  if (!c) throw new UserError(`${who} has no Kagundi bank account yet. They can open one with /bank balance.`);
  return c;
}

// Creates the citizen record and accounts on first use and keeps the display name current.
// grantEligible: the Discord layer decides whether the one-time starting grant may be paid
// (verified member with a Discord account older than the configured minimum age).
export function ensureCitizen(eco, { userId, displayName, grantEligible = false }) {
  return eco.tx(() => {
    const day = eco.currentDay();
    let c = getCitizen(eco, userId);
    if (!c) {
      eco.db.prepare(`INSERT INTO citizens (user_id, display_name, registered_day, registered_at, last_active_day)
        VALUES (?, ?, ?, ?, ?)`).run(userId, displayName, day, eco.clock.isoNow(), day);
      createAccount(eco, { kind: 'personal_bank', ownerType: 'citizen', ownerId: userId, name: `Bank account of ${displayName}`, inMoneySupply: true });
      createAccount(eco, { kind: 'personal_cash', ownerType: 'citizen', ownerId: userId, name: `Cash of ${displayName}`, inMoneySupply: true });
    } else {
      eco.db.prepare('UPDATE citizens SET display_name = ?, last_active_day = ? WHERE user_id = ?').run(displayName, day, userId);
    }
    c = getCitizen(eco, userId);
    let grantPaid = 0;
    if (grantEligible && !c.starting_grant_paid) {
      const grant = getPolicy(eco, 'starting_grant');
      if (grant > 0) {
        transfer(eco, {
          from: systemAccountId(eco, 'central_bank'), to: personalAccountId(eco, userId, 'bank'), amount: grant,
          category: 'citizen_starting_grant', memo: 'One-time starting balance for new citizens', key: `grant:${userId}`,
        });
        grantPaid = grant;
      }
      eco.db.prepare('UPDATE citizens SET starting_grant_paid = 1 WHERE user_id = ?').run(userId);
      c = getCitizen(eco, userId);
    }
    return { citizen: c, grantPaid };
  });
}

export function touchCitizen(eco, userId) {
  eco.db.prepare('UPDATE citizens SET last_active_day = ? WHERE user_id = ?').run(eco.currentDay(), userId);
}

export function personalAccountId(eco, userId, which = 'bank') {
  const kind = which === 'cash' ? 'personal_cash' : 'personal_bank';
  const row = eco.db.prepare('SELECT id FROM accounts WHERE kind = ? AND owner_id = ?').get(kind, userId);
  if (!row) throw new UserError('No Kagundi bank account found. Use /bank balance to open one.');
  return Number(row.id);
}

export function personalAccounts(eco, userId) {
  return eco.db.prepare("SELECT * FROM accounts WHERE owner_type = 'citizen' AND owner_id = ? ORDER BY id").all(userId);
}
