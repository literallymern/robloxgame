// Businesses: registration, accounts, managers, inventory, production, imports and exports.
import {
  INDUSTRIES, COMMODITIES, PARTNERS, MAX_PRODUCTION_SHIFTS_PER_BUSINESS, BUSINESS_RULES,
} from './constants.js';
import { createAccount, transfer, tryTransfer, systemAccountId, getAccount } from './ledger.js';
import { personalAccountId, requireCitizen, touchCitizen } from './citizens.js';
import { getPolicy } from './policy.js';
import { applyBp, formatKGD } from './money.js';
import { exportQuote, importQuote, pricesForDay, marketStateFor } from './market.js';
import { UserError, PermissionError } from './errors.js';
import { audit } from './audit.js';

const MAX_BUSINESSES_PER_OWNER = 2;
const MAX_MANAGERS = 5;
const NAME_PATTERN = /^[A-Za-z0-9][A-Za-z0-9 &'.,-]{1,38}[A-Za-z0-9.]$/;

export function getBusiness(eco, id) {
  return eco.db.prepare('SELECT * FROM businesses WHERE id = ?').get(id) ?? null;
}

export function requireBusiness(eco, id) {
  const b = getBusiness(eco, id);
  if (!b) throw new UserError('Business not found.');
  return b;
}

export function isManager(eco, businessId, userId) {
  return !!eco.db.prepare('SELECT 1 FROM business_managers WHERE business_id = ? AND user_id = ?').get(businessId, userId);
}

// level 'owner' = only the owner; 'manager' = owner or an authorised manager.
export function requireBusinessAccess(eco, businessId, userId, level = 'manager', { allowSuspended = true } = {}) {
  const b = requireBusiness(eco, businessId);
  const ok = b.owner_id === userId || (level === 'manager' && isManager(eco, businessId, userId));
  if (!ok) throw new PermissionError(level === 'owner' ? `Only the owner of ${b.name} can do this.` : `You are not authorised to manage ${b.name}.`);
  if (b.status === 'pending') throw new UserError(`${b.name} has not been approved by the business registry yet.`);
  if (b.status === 'rejected' || b.status === 'closed') throw new UserError(`${b.name} is ${b.status}.`);
  if (b.status === 'suspended' && !allowSuspended) throw new UserError(`${b.name} is suspended: ${b.suspended_reason ?? 'see the business registry'}.`);
  return b;
}

// Businesses a user owns or manages (for autocomplete and /business status).
export function businessesForUser(eco, userId, { includePending = false } = {}) {
  const statuses = includePending ? "('pending','active','suspended')" : "('active','suspended')";
  return eco.db.prepare(`SELECT b.*, CASE WHEN b.owner_id = ? THEN 'owner' ELSE 'manager' END AS access FROM businesses b
    WHERE b.status IN ${statuses} AND (b.owner_id = ? OR b.id IN (SELECT business_id FROM business_managers WHERE user_id = ?))
    ORDER BY b.name`).all(userId, userId, userId);
}

export function searchBusinesses(eco, text, limit = 25) {
  return eco.db.prepare(`SELECT id, name, industry FROM businesses WHERE status IN ('active','suspended') AND name LIKE ? ORDER BY name LIMIT ?`)
    .all(`%${text}%`, limit);
}

export function registerBusiness(eco, { ownerId, name, industry, output = null, description = null }) {
  const ind = INDUSTRIES[industry];
  if (!ind) throw new UserError('Unknown industry.');
  const cleanName = String(name ?? '').trim().replace(/\s+/g, ' ');
  if (!NAME_PATTERN.test(cleanName)) throw new UserError('Business names must be 3-40 characters: letters, numbers, spaces and & \' . , -');
  let primary = null;
  if (ind.outputs.length === 1) primary = ind.outputs[0];
  if (ind.outputs.length > 1) {
    if (!output || !ind.outputs.includes(output)) throw new UserError(`Choose what the business produces: ${ind.outputs.join(', ')}.`);
    primary = output;
  }
  return eco.tx(() => {
    requireCitizen(eco, ownerId, 'You');
    const count = eco.db.prepare("SELECT COUNT(*) AS n FROM businesses WHERE owner_id = ? AND status IN ('pending','active','suspended')").get(ownerId).n;
    if (count >= MAX_BUSINESSES_PER_OWNER) throw new UserError(`You can own at most ${MAX_BUSINESSES_PER_OWNER} businesses.`);
    if (eco.db.prepare('SELECT 1 FROM businesses WHERE name = ?').get(cleanName)) throw new UserError('A business with this name already exists.');
    const fee = getPolicy(eco, 'registration_fee');
    const bank = getAccount(eco, personalAccountId(eco, ownerId, 'bank'));
    if (bank.balance < fee) throw new UserError(`The registration fee is ${formatKGD(fee)} and is charged when the registry approves your application. Your bank balance is ${formatKGD(bank.balance)}.`);
    const res = eco.db.prepare(`INSERT INTO businesses (name, industry, primary_output, owner_id, status, description, applied_day)
      VALUES (?, ?, ?, ?, 'pending', ?, ?)`).run(cleanName, industry, primary, ownerId, description ? String(description).slice(0, 300) : null, eco.currentDay());
    touchCitizen(eco, ownerId);
    return { id: Number(res.lastInsertRowid), name: cleanName, fee };
  });
}

export function pendingBusinesses(eco) {
  return eco.db.prepare("SELECT * FROM businesses WHERE status = 'pending' ORDER BY id").all();
}

export function approveBusiness(eco, { id, actor, reason = 'Approved', stateShareBp = 0 }) {
  return eco.tx(() => {
    const b = requireBusiness(eco, id);
    if (b.status !== 'pending') throw new UserError('This application is not pending.');
    if (b.owner_id === actor) throw new PermissionError('You cannot approve your own business application.');
    if (!(Number.isInteger(stateShareBp) && stateShareBp >= 0 && stateShareBp <= 10000)) throw new UserError('State share must be between 0% and 100%.');
    const fee = getPolicy(eco, 'registration_fee');
    if (fee > 0) {
      transfer(eco, { from: personalAccountId(eco, b.owner_id, 'bank'), to: systemAccountId(eco, 'treasury'), amount: fee, actor,
        category: 'business_registration_fee', memo: `Registration of ${b.name}`, refType: 'business', refId: id, key: `regfee:${id}` });
    }
    const accountId = createAccount(eco, { kind: 'business', ownerType: 'business', ownerId: String(id), name: `${b.name} (business account)`, inMoneySupply: true });
    eco.db.prepare(`UPDATE businesses SET status = 'active', account_id = ?, decided_day = ?, decided_by = ?, decision_reason = ?, state_share_bp = ? WHERE id = ?`)
      .run(accountId, eco.currentDay(), actor, reason, stateShareBp, id);
    audit(eco, { actor, action: 'business.approve', target: `business:${id}`, amount: fee, newValue: { stateShareBp }, reason });
    return { ...getBusiness(eco, id), fee };
  });
}

export function rejectBusiness(eco, { id, actor, reason }) {
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  return eco.tx(() => {
    const b = requireBusiness(eco, id);
    if (b.status !== 'pending') throw new UserError('This application is not pending.');
    eco.db.prepare("UPDATE businesses SET status = 'rejected', decided_day = ?, decided_by = ?, decision_reason = ? WHERE id = ?").run(eco.currentDay(), actor, reason, id);
    audit(eco, { actor, action: 'business.reject', target: `business:${id}`, reason });
    return b;
  });
}

export function suspendBusiness(eco, { id, actor, reason }) {
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  return eco.tx(() => {
    const b = requireBusiness(eco, id);
    if (b.status !== 'active') throw new UserError('Only active businesses can be suspended.');
    eco.db.prepare("UPDATE businesses SET status = 'suspended', suspended_reason = ? WHERE id = ?").run(reason, id);
    audit(eco, { actor, action: 'business.suspend', target: `business:${id}`, reason });
    return b;
  });
}

export function reinstateBusiness(eco, { id, actor, reason }) {
  return eco.tx(() => {
    const b = requireBusiness(eco, id);
    if (b.status !== 'suspended') throw new UserError('This business is not suspended.');
    if (b.license_arrears > 0) throw new UserError(`The business still owes ${formatKGD(b.license_arrears)} in licence fees.`);
    eco.db.prepare("UPDATE businesses SET status = 'active', suspended_reason = NULL WHERE id = ?").run(id);
    audit(eco, { actor, action: 'business.reinstate', target: `business:${id}`, reason });
    return b;
  });
}

export function addManager(eco, { businessId, actor, userId }) {
  return eco.tx(() => {
    const b = requireBusinessAccess(eco, businessId, actor, 'owner');
    if (userId === b.owner_id) throw new UserError('The owner is already in charge of the business.');
    requireCitizen(eco, userId, 'That person');
    const n = eco.db.prepare('SELECT COUNT(*) AS n FROM business_managers WHERE business_id = ?').get(businessId).n;
    if (n >= MAX_MANAGERS) throw new UserError(`A business can have at most ${MAX_MANAGERS} managers.`);
    eco.db.prepare('INSERT OR IGNORE INTO business_managers (business_id, user_id, added_by, added_day) VALUES (?, ?, ?, ?)').run(businessId, userId, actor, eco.currentDay());
    return b;
  });
}

export function removeManager(eco, { businessId, actor, userId }) {
  return eco.tx(() => {
    const b = requireBusinessAccess(eco, businessId, actor, 'owner');
    const res = eco.db.prepare('DELETE FROM business_managers WHERE business_id = ? AND user_id = ?').run(businessId, userId);
    if (!res.changes) throw new UserError('That person is not a manager of this business.');
    return b;
  });
}

export function managersOf(eco, businessId) {
  return eco.db.prepare('SELECT user_id FROM business_managers WHERE business_id = ?').all(businessId).map((r) => r.user_id);
}

// Owner or manager moves personal money into the business (capital, not turnover).
export function depositToBusiness(eco, { businessId, userId, amount }) {
  return eco.tx(() => {
    const b = requireBusinessAccess(eco, businessId, userId, 'manager');
    const id = transfer(eco, { from: personalAccountId(eco, userId, 'bank'), to: b.account_id, amount, actor: userId,
      category: 'business_capital', memo: `Capital deposit into ${b.name}`, refType: 'business', refId: businessId });
    tryPayLicenseArrears(eco, getBusiness(eco, businessId));
    return id;
  });
}

// Owner takes money out of the business. This is a profit distribution: the state receives its
// ownership share, distribution tax is withheld, and the rest goes to the owner's bank account.
export function withdrawFromBusiness(eco, { businessId, userId, amount }) {
  return eco.tx(() => {
    const b = requireBusinessAccess(eco, businessId, userId, 'owner');
    const acc = getAccount(eco, b.account_id);
    if (acc.balance < amount) throw new UserError(`${b.name} only has ${formatKGD(acc.balance)}.`);
    return distribute(eco, b, amount, userId);
  });
}

function distribute(eco, b, amount, actor) {
  const treasury = systemAccountId(eco, 'treasury');
  const stateShare = applyBp(amount, b.state_share_bp);
  const afterState = amount - stateShare;
  const tax = applyBp(afterState, getPolicy(eco, 'distribution_tax_bp'));
  const net = afterState - tax;
  if (stateShare > 0) transfer(eco, { from: b.account_id, to: treasury, amount: stateShare, actor, category: 'state_dividend', memo: `State share of distribution from ${b.name}`, refType: 'business', refId: b.id });
  if (tax > 0) transfer(eco, { from: b.account_id, to: treasury, amount: tax, actor, category: 'distribution_tax', memo: `Distribution tax, ${b.name}`, refType: 'business', refId: b.id });
  if (net > 0) transfer(eco, { from: b.account_id, to: personalAccountId(eco, b.owner_id, 'bank'), amount: net, actor, category: 'business_distribution', memo: `Distribution from ${b.name}`, refType: 'business', refId: b.id });
  return { amount, stateShare, tax, net };
}

export function closeBusiness(eco, { businessId, userId }) {
  return eco.tx(() => {
    const b = requireBusinessAccess(eco, businessId, userId, 'owner');
    const activeCredit = eco.db.prepare(`SELECT 1 FROM credit_facilities WHERE borrower_type = 'business' AND borrower_id = ? AND status IN ('pending','active','defaulted')`).get(String(businessId));
    if (activeCredit) throw new UserError('Repay all business loans before closing the business.');
    const ownsProperty = eco.db.prepare("SELECT 1 FROM properties WHERE owner_type = 'business' AND owner_id = ?").get(String(businessId));
    if (ownsProperty) throw new UserError('Sell all properties owned by the business before closing it.');
    const day = eco.currentDay();
    eco.db.prepare("UPDATE employments SET status = 'ended', end_day = ?, end_reason = 'business closed' WHERE status = 'active' AND job_id IN (SELECT id FROM jobs WHERE business_id = ?)").run(day, businessId);
    eco.db.prepare("UPDATE jobs SET status = 'closed' WHERE business_id = ?").run(businessId);
    eco.db.prepare("UPDATE job_applications SET status = 'withdrawn' WHERE status = 'pending' AND job_id IN (SELECT id FROM jobs WHERE business_id = ?)").run(businessId);
    eco.db.prepare("UPDATE invoices SET status = 'cancelled' WHERE status = 'open' AND (issuer_business_id = ? OR (payer_type = 'business' AND payer_id = ?))").run(businessId, String(businessId));
    eco.db.prepare("UPDATE insurance_policies SET status = 'cancelled', end_day = ? WHERE status = 'active' AND holder_type = 'business' AND holder_id = ?").run(day, String(businessId));
    eco.db.prepare("UPDATE properties SET tenant_type = NULL, tenant_id = NULL, lease_start_day = NULL, rent_missed = 0 WHERE tenant_type = 'business' AND tenant_id = ?").run(String(businessId));
    for (const inv of inventoryOf(eco, businessId)) {
      if (inv.quantity > 0) adjustInventory(eco, businessId, inv.commodity, -inv.quantity, 'forfeited at closure');
    }
    const acc = getAccount(eco, b.account_id);
    let payout = null;
    if (acc.balance > 0) payout = distribute(eco, b, acc.balance, userId);
    eco.db.prepare("UPDATE businesses SET status = 'closed', closed_day = ? WHERE id = ?").run(day, businessId);
    audit(eco, { actor: userId, action: 'business.close', target: `business:${businessId}`, amount: acc.balance, result: payout });
    return { business: b, payout };
  });
}

// ---------- Inventory ----------

export function inventoryOf(eco, businessId) {
  return eco.db.prepare('SELECT commodity, quantity FROM inventories WHERE business_id = ? ORDER BY commodity').all(businessId);
}

export function inventoryQty(eco, businessId, commodity) {
  return Number(eco.db.prepare('SELECT quantity FROM inventories WHERE business_id = ? AND commodity = ?').get(businessId, commodity)?.quantity ?? 0);
}

export function adjustInventory(eco, businessId, commodity, delta, reason, refType = null, refId = null) {
  if (!Number.isInteger(delta) || delta === 0) return;
  eco.db.prepare(`INSERT INTO inventories (business_id, commodity, quantity) VALUES (?, ?, 0) ON CONFLICT DO NOTHING`).run(businessId, commodity);
  const current = inventoryQty(eco, businessId, commodity);
  if (current + delta < 0) throw new UserError(`Not enough ${COMMODITIES[commodity]?.name ?? commodity} in stock (have ${current}, need ${-delta}).`);
  eco.db.prepare('UPDATE inventories SET quantity = quantity + ? WHERE business_id = ? AND commodity = ?').run(delta, businessId, commodity);
  eco.db.prepare(`INSERT INTO inventory_movements (econ_day, business_id, commodity, delta, reason, ref_type, ref_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`)
    .run(eco.currentDay(), businessId, commodity, delta, reason, refType, refId == null ? null : String(refId), eco.clock.isoNow());
}

// ---------- Trade ----------

export function sellExport(eco, { businessId, userId, commodity, quantity, partner }) {
  const c = COMMODITIES[commodity];
  if (!c || c.tradable !== 'export') throw new UserError('That commodity cannot be exported.');
  if (!PARTNERS[partner]) throw new UserError('Unknown trading partner.');
  if (!Number.isInteger(quantity) || quantity <= 0) throw new UserError('Quantity must be a whole number above zero.');
  return eco.tx(() => {
    const b = requireBusinessAccess(eco, businessId, userId, 'manager', { allowSuspended: false });
    if (getPolicy(eco, 'export_ban')[commodity]) throw new UserError(`Exports of ${c.name} are currently banned by the government.`);
    const unit = exportQuote(eco, commodity, partner);
    const gross = unit * quantity;
    const dutyBp = getPolicy(eco, 'export_duty_bp')[commodity] ?? 0;
    const duty = applyBp(gross, dutyBp);
    adjustInventory(eco, businessId, commodity, -quantity, `export to ${PARTNERS[partner].name}`);
    const txId = transfer(eco, { from: systemAccountId(eco, 'rest_of_world'), to: b.account_id, amount: gross, actor: userId,
      category: 'export_sale', memo: `Export of ${quantity} ${c.unit} ${c.name} to ${PARTNERS[partner].name}`, partner, commodity, quantity });
    if (duty > 0) transfer(eco, { from: b.account_id, to: systemAccountId(eco, 'treasury'), amount: duty, actor: userId, category: 'export_duty',
      memo: `Export duty on transaction #${txId}`, refType: 'transaction', refId: txId, commodity, partner });
    touchCitizen(eco, userId);
    return { unit, gross, duty, net: gross - duty, business: b };
  });
}

export function buyImport(eco, { businessId, userId, commodity, quantity, partner }) {
  const c = COMMODITIES[commodity];
  if (!c || c.tradable !== 'import') throw new UserError('That commodity cannot be imported. Kagundi produces it domestically.');
  if (!PARTNERS[partner]) throw new UserError('Unknown trading partner.');
  if (!Number.isInteger(quantity) || quantity <= 0) throw new UserError('Quantity must be a whole number above zero.');
  return eco.tx(() => {
    const b = requireBusinessAccess(eco, businessId, userId, 'manager', { allowSuspended: false });
    const unit = importQuote(eco, commodity, partner);
    const cost = unit * quantity;
    const tariff = applyBp(cost, getPolicy(eco, 'import_tariff_bp')[commodity] ?? 0);
    const acc = getAccount(eco, b.account_id);
    if (acc.balance < cost + tariff) throw new UserError(`${b.name} needs ${formatKGD(cost + tariff)} (goods ${formatKGD(cost)} + tariff ${formatKGD(tariff)}) but has ${formatKGD(acc.balance)}.`);
    transfer(eco, { from: b.account_id, to: systemAccountId(eco, 'rest_of_world'), amount: cost, actor: userId, category: 'import_purchase',
      memo: `Import of ${quantity} ${c.unit} ${c.name} from ${PARTNERS[partner].name}`, partner, commodity, quantity });
    if (tariff > 0) transfer(eco, { from: b.account_id, to: systemAccountId(eco, 'treasury'), amount: tariff, actor: userId, category: 'import_tariff',
      memo: `Import tariff on ${c.name}`, commodity, partner });
    adjustInventory(eco, businessId, commodity, quantity, `import from ${PARTNERS[partner].name}`);
    touchCitizen(eco, userId);
    return { unit, cost, tariff, total: cost + tariff, business: b };
  });
}

// ---------- Daily processing (called by the tick) ----------

// Turns the shifts worked at producing businesses on `day` into output.
export function processProduction(eco, day, effects) {
  const results = [];
  const rows = eco.db.prepare(`SELECT s.business_id, COUNT(*) AS shifts FROM shifts s JOIN businesses b ON b.id = s.business_id
    WHERE s.econ_day = ? AND s.status <> 'void' AND b.status = 'active' AND b.primary_output IS NOT NULL GROUP BY s.business_id ORDER BY s.business_id`).all(day);
  const prices = pricesForDay(eco, day);
  for (const row of rows) {
    if (eco.db.prepare('SELECT 1 FROM production_log WHERE econ_day = ? AND business_id = ?').get(day, row.business_id)) continue;
    const b = getBusiness(eco, row.business_id);
    const c = COMMODITIES[b.primary_output];
    const ind = INDUSTRIES[b.industry];
    const shifts = Math.min(Number(row.shifts), MAX_PRODUCTION_SHIFTS_PER_BUSINESS);
    const planned = Math.floor(shifts * c.outputPerShift * effects.productionMultiplier(c.key, b.industry));
    if (planned <= 0) continue;
    const costMult = effects.costMultiplier(b.industry);
    const fx = marketStateFor(eco, day).fx;
    const unitCost = Math.round(c.unitCostEur * fx * 100 * costMult);
    const fuelCost = Math.round(shifts * (ind.fuelPerShift ?? 0) * prices.fuel.landed_kgd * costMult);
    const balance = getAccount(eco, b.account_id).balance;
    // Produce as much as the business can pay for.
    let quantity = planned;
    const totalCost = (q) => q * unitCost + Math.round(fuelCost * (q / planned));
    if (totalCost(quantity) > balance) quantity = Math.max(0, Math.floor((balance / totalCost(planned)) * planned));
    while (quantity > 0 && totalCost(quantity) > balance) quantity -= 1;
    const cost = quantity > 0 ? totalCost(quantity) : 0;
    if (cost > 0) {
      transfer(eco, { from: b.account_id, to: systemAccountId(eco, 'rest_of_world'), amount: cost, category: 'production_cost', system: true, day,
        memo: `Extraction, equipment and fuel costs for ${quantity} ${c.unit} ${c.name}`, refType: 'business', refId: b.id, commodity: c.key, quantity, key: `prodcost:${day}:${b.id}` });
    }
    if (quantity > 0) adjustInventory(eco, b.id, c.key, quantity, 'production', 'day', day);
    eco.db.prepare('INSERT INTO production_log (econ_day, business_id, commodity, shifts, quantity, cost) VALUES (?, ?, ?, ?, ?, ?)').run(day, b.id, c.key, shifts, quantity, cost);
    results.push({ businessId: b.id, commodity: c.key, shifts, planned, quantity, cost });
  }
  return results;
}

function tryPayLicenseArrears(eco, b, day = eco.currentDay()) {
  if (!b.license_arrears) return true;
  const ok = tryTransfer(eco, { from: b.account_id, to: systemAccountId(eco, 'treasury'), amount: b.license_arrears, category: 'business_license_fee', system: true, day,
    memo: `Outstanding licence fees, ${b.name}`, refType: 'business', refId: b.id });
  if (ok) {
    eco.db.prepare('UPDATE businesses SET license_arrears = 0, license_unpaid_days = 0 WHERE id = ?').run(b.id);
    if (b.status === 'suspended' && b.suspended_reason === 'Unpaid licence fees') {
      eco.db.prepare("UPDATE businesses SET status = 'active', suspended_reason = NULL WHERE id = ?").run(b.id);
    }
  }
  return !!ok;
}

// Daily operating licence fee for every active or suspended business.
export function processLicenseFees(eco, day, { late = false } = {}) {
  const out = { charged: 0, missed: 0, suspended: [] };
  const rows = eco.db.prepare("SELECT * FROM businesses WHERE status IN ('active','suspended') AND decided_day < ? ORDER BY id").all(day);
  for (const b of rows) {
    const fee = INDUSTRIES[b.industry]?.licenseFeeDaily ?? 0;
    if (fee <= 0) continue;
    tryPayLicenseArrears(eco, b, day);
    const fresh = getBusiness(eco, b.id);
    const ok = tryTransfer(eco, { from: b.account_id, to: systemAccountId(eco, 'treasury'), amount: fee, category: 'business_license_fee', system: true, day,
      memo: `Daily operating licence, ${b.name}`, refType: 'business', refId: b.id, key: `license:${day}:${b.id}` });
    if (ok) {
      out.charged += fee;
      continue;
    }
    out.missed += 1;
    const unpaid = late ? fresh.license_unpaid_days : fresh.license_unpaid_days + 1;
    eco.db.prepare('UPDATE businesses SET license_arrears = license_arrears + ?, license_unpaid_days = ? WHERE id = ?').run(fee, unpaid, b.id);
    if (fresh.status === 'active' && unpaid >= BUSINESS_RULES.suspendAfterUnpaidLicenseDays) {
      eco.db.prepare("UPDATE businesses SET status = 'suspended', suspended_reason = 'Unpaid licence fees' WHERE id = ?").run(b.id);
      audit(eco, { actor: 'system', action: 'business.suspend', target: `business:${b.id}`, reason: 'Unpaid licence fees' });
      out.suspended.push(b.id);
    }
  }
  return out;
}

export function businessSummary(eco, businessId) {
  const b = requireBusiness(eco, businessId);
  const acc = b.account_id ? getAccount(eco, b.account_id) : null;
  const employees = eco.db.prepare(`SELECT e.user_id, j.title, j.daily_wage FROM employments e JOIN jobs j ON j.id = e.job_id
    WHERE e.status = 'active' AND j.business_id = ? ORDER BY j.title`).all(businessId);
  const jobs = eco.db.prepare("SELECT * FROM jobs WHERE business_id = ? AND status = 'open' ORDER BY id").all(businessId);
  const day = eco.currentDay();
  const flows = acc ? eco.db.prepare(`SELECT
      COALESCE(SUM(CASE WHEN to_account = ? THEN amount END), 0) AS inflow,
      COALESCE(SUM(CASE WHEN from_account = ? THEN amount END), 0) AS outflow
    FROM transactions WHERE (to_account = ? OR from_account = ?) AND econ_day > ?`).get(acc.id, acc.id, acc.id, acc.id, day - 7) : { inflow: 0, outflow: 0 };
  const unpaidWages = eco.db.prepare("SELECT COUNT(*) AS n, COALESCE(SUM(gross), 0) AS total FROM shifts WHERE business_id = ? AND status = 'unpaid'").get(businessId);
  return {
    business: b, account: acc, employees, jobs, managers: managersOf(eco, businessId), inventory: inventoryOf(eco, businessId),
    flows7d: { inflow: Number(flows.inflow), outflow: Number(flows.outflow) }, unpaidWages: { count: Number(unpaidWages.n), total: Number(unpaidWages.total) },
  };
}

export function publicBusinessList(eco) {
  return eco.db.prepare(`SELECT b.id, b.name, b.industry, b.primary_output, b.owner_id, b.status,
      (SELECT COUNT(*) FROM employments e JOIN jobs j ON j.id = e.job_id WHERE j.business_id = b.id AND e.status = 'active') AS employees,
      (SELECT COUNT(*) FROM jobs j WHERE j.business_id = b.id AND j.status = 'open') AS open_jobs
    FROM businesses b WHERE b.status IN ('active','suspended') ORDER BY b.name`).all();
}
