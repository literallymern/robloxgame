// Property market: renting, buying and selling. State properties are managed by authorised officials.
import { CITIES, PROPERTY_TYPES, RENT_RULES } from './constants.js';
import { transfer, tryTransfer, systemAccountId, getAccount } from './ledger.js';
import { personalAccountId, requireCitizen, touchCitizen } from './citizens.js';
import { requireBusinessAccess, getBusiness, isManager } from './businesses.js';
import { payAccount } from './payments.js';
import { recordCreditEvent } from './credit.js';
import { getPolicy } from './policy.js';
import { applyBp, formatKGD } from './money.js';
import { UserError, PermissionError } from './errors.js';
import { audit } from './audit.js';

const MAX_RENTALS_PER_TENANT = 2;

export function getProperty(eco, id) {
  const p = eco.db.prepare('SELECT * FROM properties WHERE id = ?').get(id);
  if (!p) throw new UserError('Property not found.');
  return p;
}

export function listProperties(eco, { city = null, available = true } = {}) {
  const where = [];
  const args = [];
  if (city) { where.push('city = ?'); args.push(city); }
  if (available) where.push('((for_rent = 1 AND tenant_id IS NULL) OR for_sale = 1)');
  return eco.db.prepare(`SELECT * FROM properties ${where.length ? `WHERE ${where.join(' AND ')}` : ''} ORDER BY city, name`).all(...args);
}

// Account that receives money for a property (rent, sale proceeds).
function ownerAccount(eco, p) {
  if (p.owner_type === 'state') return systemAccountId(eco, 'treasury');
  if (p.owner_type === 'citizen') return personalAccountId(eco, p.owner_id, 'bank');
  return getBusiness(eco, Number(p.owner_id)).account_id;
}

// Resolves who acts: the citizen personally, or a business they manage.
function party(eco, userId, businessId, level = 'manager') {
  if (businessId) {
    const b = requireBusinessAccess(eco, businessId, userId, level, { allowSuspended: false });
    return { type: 'business', id: String(b.id), account: b.account_id, label: b.name };
  }
  requireCitizen(eco, userId, 'You');
  return { type: 'citizen', id: userId, account: personalAccountId(eco, userId, 'bank'), label: 'you' };
}

function isOwner(eco, p, userId) {
  if (p.owner_type === 'citizen') return p.owner_id === userId;
  if (p.owner_type === 'business') {
    const b = getBusiness(eco, Number(p.owner_id));
    return !!b && b.owner_id === userId;
  }
  return false;
}

function isTenant(eco, p, userId) {
  if (p.tenant_type === 'citizen') return p.tenant_id === userId;
  if (p.tenant_type === 'business') {
    const b = getBusiness(eco, Number(p.tenant_id));
    return !!b && (b.owner_id === userId || isManager(eco, b.id, userId));
  }
  return false;
}

function collectRent(eco, p, fromAccount, day, actor, key, system = false) {
  const to = ownerAccount(eco, p);
  if (p.owner_type === 'state') {
    return transfer(eco, { from: fromAccount, to, amount: p.daily_rent, actor, system, day, category: 'state_rent', memo: `Rent: ${p.name}`, refType: 'property', refId: p.id, key });
  }
  if (p.owner_type === 'business') {
    return payAccount(eco, { fromAccount, toAccount: to, amount: p.daily_rent, actor, system, day, key, memo: `Rent: ${p.name}`, refType: 'property', refId: p.id }).txId;
  }
  return transfer(eco, { from: fromAccount, to, amount: p.daily_rent, actor, system, day, category: 'rent_income', memo: `Rent: ${p.name}`, refType: 'property', refId: p.id, key });
}

export function rentProperty(eco, { userId, propertyId, businessId = null }) {
  return eco.tx(() => {
    const p = getProperty(eco, propertyId);
    if (!p.for_rent || p.tenant_id) throw new UserError('This property is not available for rent.');
    const who = party(eco, userId, businessId);
    if (p.owner_type === who.type && p.owner_id === who.id) throw new UserError('You already own this property.');
    const count = eco.db.prepare('SELECT COUNT(*) AS n FROM properties WHERE tenant_type = ? AND tenant_id = ?').get(who.type, who.id).n;
    if (count >= MAX_RENTALS_PER_TENANT) throw new UserError(`A tenant can rent at most ${MAX_RENTALS_PER_TENANT} properties.`);
    const day = eco.currentDay();
    if (p.daily_rent > 0) collectRent(eco, p, who.account, day, userId, `rent:${day}:${p.id}:first`);
    eco.db.prepare('UPDATE properties SET tenant_type = ?, tenant_id = ?, lease_start_day = ?, rent_missed = 0 WHERE id = ?').run(who.type, who.id, day, p.id);
    touchCitizen(eco, userId);
    return { property: p, tenant: who };
  });
}

export function leaveProperty(eco, { userId, propertyId }) {
  return eco.tx(() => {
    const p = getProperty(eco, propertyId);
    if (!isTenant(eco, p, userId)) throw new PermissionError('You do not rent this property.');
    eco.db.prepare('UPDATE properties SET tenant_type = NULL, tenant_id = NULL, lease_start_day = NULL, rent_missed = 0 WHERE id = ?').run(p.id);
    return p;
  });
}

export function buyProperty(eco, { userId, propertyId, businessId = null }) {
  return eco.tx(() => {
    const p = getProperty(eco, propertyId);
    if (!p.for_sale || !p.sale_price) throw new UserError('This property is not for sale.');
    const buyer = party(eco, userId, businessId, 'owner');
    if (p.owner_type === buyer.type && p.owner_id === buyer.id) throw new UserError('You already own this property.');
    const taxAmount = applyBp(p.sale_price, getPolicy(eco, 'property_transfer_tax_bp'));
    const acc = getAccount(eco, buyer.account);
    if (acc.balance < p.sale_price + taxAmount) {
      throw new UserError(`The purchase needs ${formatKGD(p.sale_price + taxAmount)} (price ${formatKGD(p.sale_price)} + transfer tax ${formatKGD(taxAmount)}).`);
    }
    const seller = ownerAccount(eco, p);
    transfer(eco, { from: buyer.account, to: seller, amount: p.sale_price, actor: userId,
      category: p.owner_type === 'state' ? 'property_sale' : 'property_purchase', memo: `Purchase of ${p.name}`, refType: 'property', refId: p.id });
    if (taxAmount > 0) transfer(eco, { from: buyer.account, to: systemAccountId(eco, 'treasury'), amount: taxAmount, actor: userId,
      category: 'property_transfer_tax', memo: `Transfer tax: ${p.name}`, refType: 'property', refId: p.id });
    eco.db.prepare('UPDATE properties SET owner_type = ?, owner_id = ?, for_sale = 0, sale_price = NULL, tax_arrears = 0 WHERE id = ?').run(buyer.type, buyer.id, p.id);
    audit(eco, { actor: userId, action: 'property.sale', target: `property:${p.id}`, amount: p.sale_price, oldValue: { owner: `${p.owner_type}:${p.owner_id ?? ''}` }, newValue: { owner: `${buyer.type}:${buyer.id}` } });
    touchCitizen(eco, userId);
    return { property: p, price: p.sale_price, tax: taxAmount };
  });
}

function requireManageRights(eco, p, userId, canManageState) {
  if (p.owner_type === 'state') {
    if (!canManageState) throw new PermissionError('State property is managed by the Secretariat for Internal Affairs and Infrastructure.');
    return;
  }
  if (!isOwner(eco, p, userId)) throw new PermissionError('Only the owner can change this property.');
}

export function listForSale(eco, { userId, propertyId, price, canManageState = false }) {
  return eco.tx(() => {
    const p = getProperty(eco, propertyId);
    requireManageRights(eco, p, userId, canManageState);
    if (!Number.isInteger(price) || price <= 0) throw new UserError('Enter a valid price.');
    eco.db.prepare('UPDATE properties SET for_sale = 1, sale_price = ? WHERE id = ?').run(price, p.id);
    if (p.owner_type === 'state') audit(eco, { actor: userId, action: 'property.list_for_sale', target: `property:${p.id}`, amount: price });
    return p;
  });
}

export function unlist(eco, { userId, propertyId, canManageState = false }) {
  return eco.tx(() => {
    const p = getProperty(eco, propertyId);
    requireManageRights(eco, p, userId, canManageState);
    eco.db.prepare('UPDATE properties SET for_sale = 0, sale_price = NULL WHERE id = ?').run(p.id);
    return p;
  });
}

// Rent can only change while the property is vacant, so tenants are never surprised.
export function setRent(eco, { userId, propertyId, rent, forRent = true, canManageState = false }) {
  return eco.tx(() => {
    const p = getProperty(eco, propertyId);
    requireManageRights(eco, p, userId, canManageState);
    if (p.tenant_id) throw new UserError('Rent can only be changed while the property is vacant.');
    if (!Number.isInteger(rent) || rent < 0 || rent > 10000000) throw new UserError('Enter a valid daily rent.');
    eco.db.prepare('UPDATE properties SET daily_rent = ?, for_rent = ? WHERE id = ?').run(rent, forRent ? 1 : 0, p.id);
    if (p.owner_type === 'state') audit(eco, { actor: userId, action: 'property.set_rent', target: `property:${p.id}`, oldValue: p.daily_rent, newValue: rent });
    return p;
  });
}

export function createStateProperty(eco, { actor, name, city, type, value, rent, forSale = false, salePrice = null }) {
  if (!CITIES.includes(city)) throw new UserError(`City must be one of: ${CITIES.join(', ')}.`);
  if (!PROPERTY_TYPES.includes(type)) throw new UserError(`Type must be one of: ${PROPERTY_TYPES.join(', ')}.`);
  const n = String(name ?? '').trim();
  if (n.length < 5 || n.length > 60) throw new UserError('Property names must be 5-60 characters.');
  return eco.tx(() => {
    if (eco.db.prepare('SELECT 1 FROM properties WHERE name = ?').get(n)) throw new UserError('A property with this name already exists.');
    const res = eco.db.prepare(`INSERT INTO properties (name, city, type, value, daily_rent, owner_type, for_sale, sale_price, for_rent, created_by, created_day)
      VALUES (?, ?, ?, ?, ?, 'state', ?, ?, 1, ?, ?)`).run(n, city, type, value, rent, forSale ? 1 : 0, forSale ? (salePrice ?? value) : null, actor, eco.currentDay());
    const id = Number(res.lastInsertRowid);
    audit(eco, { actor, action: 'property.create', target: `property:${id}`, amount: value, newValue: { name: n, city, type, rent } });
    return getProperty(eco, id);
  });
}

export function propertiesOfUser(eco, userId) {
  const businessIds = eco.db.prepare(`SELECT CAST(id AS TEXT) AS id FROM businesses WHERE owner_id = ? AND status IN ('active','suspended')
    UNION SELECT CAST(business_id AS TEXT) FROM business_managers WHERE user_id = ?`).all(userId, userId).map((r) => r.id);
  const all = eco.db.prepare('SELECT * FROM properties ORDER BY id').all();
  const mine = (type, id) => (type === 'citizen' && id === userId) || (type === 'business' && businessIds.includes(id));
  return {
    owned: all.filter((p) => mine(p.owner_type, p.owner_id)),
    rented: all.filter((p) => mine(p.tenant_type, p.tenant_id)),
  };
}

function tenantAccount(eco, p) {
  if (p.tenant_type === 'citizen') return personalAccountId(eco, p.tenant_id, 'bank');
  return getBusiness(eco, Number(p.tenant_id))?.account_id ?? null;
}

function tenantUserId(eco, p) {
  if (p.tenant_type === 'citizen') return p.tenant_id;
  return getBusiness(eco, Number(p.tenant_id))?.owner_id ?? null;
}

// Daily rent collection with eviction after repeated missed payments.
export function processRent(eco, day, { late = false } = {}) {
  const out = { collected: 0, missed: 0, evictions: [] };
  const rows = eco.db.prepare('SELECT * FROM properties WHERE tenant_id IS NOT NULL AND lease_start_day < ? AND daily_rent > 0 ORDER BY id').all(day);
  for (const p of rows) {
    const from = tenantAccount(eco, p);
    let paid = null;
    if (from) {
      const acc = getAccount(eco, from);
      if (acc.balance >= p.daily_rent) {
        paid = tryTransferRent(eco, p, from, day);
      }
    }
    if (paid) {
      out.collected += p.daily_rent;
      if (p.rent_missed) eco.db.prepare('UPDATE properties SET rent_missed = 0 WHERE id = ?').run(p.id);
      continue;
    }
    out.missed += 1;
    if (late) continue;
    const missed = p.rent_missed + 1;
    const userId = tenantUserId(eco, p);
    recordCreditEvent(eco, userId, day, 'missed', 'property', p.id, 'rent');
    if (missed >= RENT_RULES.evictAfterMissedDays) {
      eco.db.prepare('UPDATE properties SET tenant_type = NULL, tenant_id = NULL, lease_start_day = NULL, rent_missed = 0 WHERE id = ?').run(p.id);
      recordCreditEvent(eco, userId, day, 'eviction', 'property', p.id);
      audit(eco, { actor: 'system', action: 'property.eviction', target: `property:${p.id}`, reason: `${missed} days of unpaid rent`, oldValue: { tenant: `${p.tenant_type}:${p.tenant_id}` } });
      out.evictions.push(p.id);
    } else {
      eco.db.prepare('UPDATE properties SET rent_missed = ? WHERE id = ?').run(missed, p.id);
    }
  }
  return out;
}

function tryTransferRent(eco, p, from, day) {
  try {
    return collectRent(eco, p, from, day, 'system', `rent:${day}:${p.id}`, true);
  } catch (err) {
    if (err.name === 'InsufficientFundsError') return null;
    throw err;
  }
}

// Daily property tax on privately owned property. Unpaid tax accumulates as arrears.
export function processPropertyTax(eco, day) {
  const out = { collected: 0, arrears: 0 };
  const rate = getPolicy(eco, 'property_tax_annual_bp');
  const treasury = systemAccountId(eco, 'treasury');
  const rows = eco.db.prepare("SELECT * FROM properties WHERE owner_type <> 'state' ORDER BY id").all();
  for (const p of rows) {
    const tax = Math.round((p.value * rate) / 10000 / 365);
    const due = tax + p.tax_arrears;
    if (due <= 0) continue;
    const from = ownerAccount(eco, p);
    const ok = tryTransfer(eco, { from, to: treasury, amount: due, system: true, day, category: 'property_tax',
      memo: `Property tax: ${p.name}`, refType: 'property', refId: p.id, key: `proptax:${day}:${p.id}` });
    if (ok) {
      out.collected += due;
      if (p.tax_arrears) eco.db.prepare('UPDATE properties SET tax_arrears = 0 WHERE id = ?').run(p.id);
    } else {
      eco.db.prepare('UPDATE properties SET tax_arrears = ? WHERE id = ?').run(due, p.id);
      out.arrears += due;
    }
  }
  return out;
}
