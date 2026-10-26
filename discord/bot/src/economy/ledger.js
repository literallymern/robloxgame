// The ledger is the only code that changes account balances.
// Every movement is written as a transaction row in the same database transaction.
import { InsufficientFundsError, UserError } from './errors.js';
import { formatKGD } from './money.js';

export function getAccount(eco, id) {
  const acc = eco.db.prepare('SELECT * FROM accounts WHERE id = ?').get(id);
  if (!acc) throw new Error(`Account ${id} does not exist`);
  return acc;
}

export function systemAccountId(eco, key) {
  if (!eco.cache.system[key]) {
    const row = eco.db.prepare('SELECT id FROM accounts WHERE system_key = ?').get(key);
    if (!row) throw new Error(`System account ${key} is missing`);
    eco.cache.system[key] = row.id;
  }
  return eco.cache.system[key];
}

export function createAccount(eco, { kind, ownerType, ownerId = null, systemKey = null, name, creditLimit = 0, inMoneySupply }) {
  const res = eco.db.prepare(`INSERT INTO accounts (kind, owner_type, owner_id, system_key, name, balance, credit_limit, in_money_supply, created_day)
    VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?)`).run(kind, ownerType, ownerId, systemKey, name, creditLimit, inMoneySupply ? 1 : 0, eco.currentDay());
  return Number(res.lastInsertRowid);
}

function classifyFlow(from, to) {
  if (from.in_money_supply && to.in_money_supply) return 'transfer';
  if (!from.in_money_supply && to.in_money_supply) return 'creation';
  if (from.in_money_supply && !to.in_money_supply) return 'removal';
  return 'internal';
}

// Moves `amount` minor units from one account to another.
// Options: category (required), actor, memo, refType, refId, partner, commodity, quantity,
// key (idempotency key: a second call with the same key does nothing and returns the first id),
// system (true = allowed even if the sending account is frozen; used for scheduled obligations),
// day (economic day to book on; defaults to today).
export function transfer(eco, o) {
  const amount = o.amount;
  if (!Number.isSafeInteger(amount) || amount <= 0) throw new Error(`Invalid transfer amount: ${amount}`);
  if (!o.category) throw new Error('Transfer needs a category');
  return eco.tx(() => {
    if (o.key) {
      const existing = eco.db.prepare('SELECT id FROM transactions WHERE idempotency_key = ?').get(o.key);
      if (existing) return Number(existing.id);
    }
    const from = getAccount(eco, o.from);
    const to = getAccount(eco, o.to);
    if (from.id === to.id) throw new UserError('You cannot transfer money to the same account.');
    if (from.frozen && !o.system) throw new UserError('This account is frozen. Please contact the economic administration.');
    if (from.credit_limit !== null && from.balance - amount < -from.credit_limit) {
      throw new InsufficientFundsError(`Insufficient funds in ${from.name}: available ${formatKGD(available(from))}, needed ${formatKGD(amount)}.`);
    }
    eco.db.prepare('UPDATE accounts SET balance = balance - ? WHERE id = ?').run(amount, from.id);
    eco.db.prepare('UPDATE accounts SET balance = balance + ? WHERE id = ?').run(amount, to.id);
    const res = eco.db.prepare(`INSERT INTO transactions
      (econ_day, created_at, from_account, to_account, amount, category, flow, memo, actor_id, ref_type, ref_id, partner, commodity, quantity, idempotency_key)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
      o.day ?? eco.currentDay(), eco.clock.isoNow(), from.id, to.id, amount, o.category, classifyFlow(from, to),
      o.memo ?? null, o.actor ?? 'system', o.refType ?? null, o.refId == null ? null : String(o.refId),
      o.partner ?? null, o.commodity ?? null, o.quantity ?? null, o.key ?? null,
    );
    return Number(res.lastInsertRowid);
  });
}

// Like transfer, but returns null instead of throwing when the sender cannot afford it.
export function tryTransfer(eco, o) {
  try {
    return transfer(eco, o);
  } catch (err) {
    if (err instanceof InsufficientFundsError) return null;
    throw err;
  }
}

export function available(acc) {
  if (acc.credit_limit === null) return Number.MAX_SAFE_INTEGER;
  return acc.balance + acc.credit_limit;
}

export function balance(eco, id) {
  return getAccount(eco, id).balance;
}

// Sum of all balances. Because every transfer moves money between two accounts,
// this must always be exactly zero. Used by tests and the daily integrity check.
export function ledgerSum(eco) {
  return Number(eco.db.prepare('SELECT COALESCE(SUM(balance), 0) AS s FROM accounts').get().s);
}

// Checks that every balance equals the sum of its ledger rows.
export function verifyLedger(eco) {
  const rows = eco.db.prepare(`
    SELECT a.id, a.balance,
      COALESCE((SELECT SUM(amount) FROM transactions WHERE to_account = a.id), 0)
      - COALESCE((SELECT SUM(amount) FROM transactions WHERE from_account = a.id), 0) AS computed
    FROM accounts a`).all();
  const mismatches = rows.filter((r) => Number(r.balance) !== Number(r.computed));
  return { ok: mismatches.length === 0 && ledgerSum(eco) === 0, mismatches, sum: ledgerSum(eco) };
}
