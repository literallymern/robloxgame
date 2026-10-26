// Player-facing payments: transfers between citizens and businesses, cash handling.
import { transfer, getAccount, systemAccountId } from './ledger.js';
import { personalAccountId, requireCitizen, touchCitizen } from './citizens.js';
import { getPolicy } from './policy.js';
import { applyBp } from './money.js';
import { UserError } from './errors.js';

// Pays `amount` from one account to another. If the receiver is a business account, the payment
// counts as business turnover (booked as businessCategory) and turnover tax is withheld from the
// business for the treasury.
// Returns { txId, tax }.
export function payAccount(eco, { fromAccount, toAccount, amount, actor, memo, category = 'payment', businessCategory = 'business_income', refType, refId, commodity, quantity, system = false, key = null, day }) {
  return eco.tx(() => {
    const to = getAccount(eco, toAccount);
    const isBusinessIncome = to.kind === 'business';
    const txId = transfer(eco, {
      from: fromAccount, to: toAccount, amount, actor, memo, system, key, day,
      category: isBusinessIncome ? businessCategory : category, refType, refId, commodity, quantity,
    });
    let tax = 0;
    if (isBusinessIncome) {
      tax = applyBp(amount, getPolicy(eco, 'turnover_tax_bp'));
      if (tax > 0) {
        transfer(eco, { from: toAccount, to: systemAccountId(eco, 'treasury'), amount: tax, actor: 'system', system: true, day,
          key: key ? `${key}:tax` : null, category: 'turnover_tax', memo: `Turnover tax on transaction #${txId}`, refType: 'transaction', refId: txId });
      }
    }
    return { txId, tax };
  });
}

export function businessAccountId(eco, businessId) {
  const b = eco.db.prepare('SELECT account_id, status, name FROM businesses WHERE id = ?').get(businessId);
  if (!b || !b.account_id) throw new UserError('That business does not exist or is not active.');
  if (b.status === 'closed') throw new UserError(`${b.name} is closed.`);
  return Number(b.account_id);
}

// /bank pay: a citizen pays another citizen or a business from bank, cash or credit card.
export function citizenPay(eco, { userId, source = 'bank', toUserId = null, toBusinessId = null, amount, memo }) {
  if (!toUserId && !toBusinessId) throw new UserError('Choose a person or a business to pay.');
  if (toUserId && toBusinessId) throw new UserError('Choose either a person or a business, not both.');
  if (toUserId === userId) throw new UserError('You cannot pay yourself.');
  return eco.tx(() => {
    requireCitizen(eco, userId, 'You');
    let toAccount;
    if (toUserId) {
      requireCitizen(eco, toUserId, 'The recipient');
      toAccount = personalAccountId(eco, toUserId, source === 'cash' ? 'cash' : 'bank');
    } else {
      toAccount = businessAccountId(eco, toBusinessId);
    }
    let fromAccount;
    if (source === 'card') {
      if (!toBusinessId) throw new UserError('Credit cards can only be used to pay businesses.');
      fromAccount = cardAccountForSpending(eco, userId, amount);
    } else {
      fromAccount = personalAccountId(eco, userId, source === 'cash' ? 'cash' : 'bank');
    }
    const result = payAccount(eco, {
      fromAccount, toAccount, amount, actor: userId, memo,
      category: source === 'cash' ? 'cash_payment' : 'payment',
    });
    touchCitizen(eco, userId);
    return result;
  });
}

// Returns the card account if the purchase fits within the approved limit.
function cardAccountForSpending(eco, userId, amount) {
  const card = eco.db.prepare(`SELECT f.*, a.balance, a.frozen FROM credit_facilities f JOIN accounts a ON a.id = f.account_id
    WHERE f.type = 'card' AND f.borrower_type = 'citizen' AND f.borrower_id = ? AND f.status = 'active'`).get(userId);
  if (!card) throw new UserError('You do not have an active credit card. Apply with /card apply.');
  const outstanding = -Number(card.balance);
  if (outstanding + amount > card.principal) {
    throw new UserError(`This purchase would exceed your card limit (available ${((card.principal - outstanding) / 100).toFixed(2)} KGD).`);
  }
  return Number(card.account_id);
}

export function withdrawCash(eco, { userId, amount }) {
  return transfer(eco, { from: personalAccountId(eco, userId, 'bank'), to: personalAccountId(eco, userId, 'cash'), amount, actor: userId, category: 'cash_withdrawal' });
}

export function depositCash(eco, { userId, amount }) {
  return transfer(eco, { from: personalAccountId(eco, userId, 'cash'), to: personalAccountId(eco, userId, 'bank'), amount, actor: userId, category: 'cash_deposit' });
}

// Transaction history for accounts the caller is allowed to see (checked by the caller).
export function accountTransactions(eco, accountId, { limit = 10, offset = 0 } = {}) {
  return eco.db.prepare(`SELECT t.*, fa.name AS from_name, ta.name AS to_name FROM transactions t
    JOIN accounts fa ON fa.id = t.from_account JOIN accounts ta ON ta.id = t.to_account
    WHERE t.from_account = ? OR t.to_account = ? ORDER BY t.id DESC LIMIT ? OFFSET ?`).all(accountId, accountId, limit, offset);
}
