// Invoices: how businesses sell goods and services to citizens, other businesses and the state.
// An invoice with goods moves them out of the seller's inventory when it is paid.
import { COMMODITIES, INVOICE_RULES } from './constants.js';
import { personalAccountId, requireCitizen, touchCitizen } from './citizens.js';
import { requireBusinessAccess, requireBusiness, inventoryQty, adjustInventory } from './businesses.js';
import { payAccount } from './payments.js';
import { formatKGD } from './money.js';
import { UserError, PermissionError } from './errors.js';

export function getInvoice(eco, id) {
  const inv = eco.db.prepare('SELECT * FROM invoices WHERE id = ?').get(id);
  if (!inv) throw new UserError('Invoice not found.');
  return inv;
}

export function createInvoice(eco, { businessId, actor, payerType, payerId = null, amount, memo, commodity = null, quantity = null }) {
  const m = String(memo ?? '').trim();
  if (m.length < 3) throw new UserError('Describe what the invoice is for (at least 3 characters).');
  if (amount > INVOICE_RULES.maxAmount) throw new UserError(`Invoices are limited to ${formatKGD(INVOICE_RULES.maxAmount)}.`);
  if ((commodity && !quantity) || (!commodity && quantity)) throw new UserError('Goods need both a commodity and a quantity.');
  if (commodity && !COMMODITIES[commodity]) throw new UserError('Unknown commodity.');
  if (quantity !== null && (!Number.isInteger(quantity) || quantity <= 0)) throw new UserError('Quantity must be a whole number above zero.');
  return eco.tx(() => {
    const b = requireBusinessAccess(eco, businessId, actor, 'manager', { allowSuspended: false });
    if (payerType === 'citizen') {
      requireCitizen(eco, payerId, 'The customer');
    } else if (payerType === 'business') {
      const pb = requireBusiness(eco, Number(payerId));
      if (pb.id === b.id) throw new UserError('A business cannot invoice itself.');
      if (pb.status !== 'active') throw new UserError('The customer business is not active.');
    } else if (payerType !== 'state') {
      throw new UserError('Choose who should pay the invoice.');
    }
    if (commodity && inventoryQty(eco, b.id, commodity) < quantity) throw new UserError(`${b.name} does not have ${quantity} ${COMMODITIES[commodity].unit} of ${COMMODITIES[commodity].name} in stock.`);
    const day = eco.currentDay();
    const res = eco.db.prepare(`INSERT INTO invoices (issuer_business_id, payer_type, payer_id, amount, memo, commodity, quantity, status, created_by, created_day, due_day)
      VALUES (?, ?, ?, ?, ?, ?, ?, 'open', ?, ?, ?)`).run(b.id, payerType, payerId == null ? null : String(payerId), amount, m.slice(0, 200), commodity, quantity, actor, day, day + INVOICE_RULES.expireAfterDays);
    return { id: Number(res.lastInsertRowid), business: b, dueDay: day + INVOICE_RULES.expireAfterDays };
  });
}

// Pays an invoice from a personal bank account or from a business the actor manages.
// The state pays through the treasury module (spending rules apply there).
export function payInvoice(eco, { invoiceId, actor, fromAccount = null }) {
  return eco.tx(() => {
    const inv = getInvoice(eco, invoiceId);
    if (inv.status !== 'open') throw new UserError(`This invoice is ${inv.status}.`);
    let from = fromAccount;
    if (!from) {
      if (inv.payer_type === 'citizen') {
        if (inv.payer_id !== actor) throw new PermissionError('This invoice is not addressed to you.');
        from = personalAccountId(eco, actor, 'bank');
      } else if (inv.payer_type === 'business') {
        from = requireBusinessAccess(eco, Number(inv.payer_id), actor, 'manager', { allowSuspended: false }).account_id;
      } else {
        throw new PermissionError('Invoices to the state are paid with /treasury pay-invoice.');
      }
    }
    const issuer = requireBusiness(eco, inv.issuer_business_id);
    if (issuer.status !== 'active') throw new UserError('The issuing business is not active, so the invoice cannot be paid.');
    if (inv.commodity) {
      adjustInventory(eco, issuer.id, inv.commodity, -inv.quantity, `sold on invoice #${inv.id}`, 'invoice', inv.id);
      if (inv.payer_type === 'business') adjustInventory(eco, Number(inv.payer_id), inv.commodity, inv.quantity, `bought on invoice #${inv.id}`, 'invoice', inv.id);
    }
    const result = payAccount(eco, { fromAccount: from, toAccount: issuer.account_id, amount: inv.amount, actor,
      memo: `Invoice #${inv.id}: ${inv.memo}`, refType: 'invoice', refId: inv.id, commodity: inv.commodity, quantity: inv.quantity, key: `invoice:${inv.id}` });
    eco.db.prepare("UPDATE invoices SET status = 'paid', paid_day = ?, paid_by = ? WHERE id = ?").run(eco.currentDay(), actor, inv.id);
    touchCitizen(eco, actor);
    return { invoice: inv, ...result };
  });
}

export function cancelInvoice(eco, { invoiceId, actor }) {
  return eco.tx(() => {
    const inv = getInvoice(eco, invoiceId);
    if (inv.status !== 'open') throw new UserError(`This invoice is ${inv.status}.`);
    let allowed = false;
    try { requireBusinessAccess(eco, inv.issuer_business_id, actor, 'manager'); allowed = true; } catch { /* not the issuer */ }
    if (!allowed && inv.payer_type === 'citizen' && inv.payer_id === actor) allowed = true;
    if (!allowed && inv.payer_type === 'business') {
      try { requireBusinessAccess(eco, Number(inv.payer_id), actor, 'manager'); allowed = true; } catch { /* not the payer */ }
    }
    if (!allowed) throw new PermissionError('Only the issuer or the recipient can cancel this invoice.');
    eco.db.prepare("UPDATE invoices SET status = 'cancelled' WHERE id = ?").run(inv.id);
    return inv;
  });
}

export function invoicesForUser(eco, userId) {
  const businessIds = eco.db.prepare(`SELECT id FROM businesses WHERE owner_id = ? UNION SELECT business_id FROM business_managers WHERE user_id = ?`).all(userId, userId).map((r) => r.id);
  const ph = businessIds.map(() => '?').join(',') || 'NULL';
  const toPay = eco.db.prepare(`SELECT * FROM invoices WHERE status = 'open' AND ((payer_type = 'citizen' AND payer_id = ?)
    OR (payer_type = 'business' AND CAST(payer_id AS INTEGER) IN (${ph}))) ORDER BY id`).all(userId, ...businessIds);
  const issued = eco.db.prepare(`SELECT * FROM invoices WHERE status = 'open' AND issuer_business_id IN (${ph}) ORDER BY id`).all(...businessIds);
  return { toPay, issued };
}

export function stateInvoices(eco) {
  return eco.db.prepare("SELECT * FROM invoices WHERE status = 'open' AND payer_type = 'state' ORDER BY id").all();
}

export function expireInvoices(eco, day) {
  return eco.db.prepare("UPDATE invoices SET status = 'expired' WHERE status = 'open' AND due_day < ?").run(day).changes;
}
