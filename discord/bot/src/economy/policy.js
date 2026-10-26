// Economic policy parameters (tax rates, fees, interest rate). Stored in the database so that
// changes survive restarts, and every change is written to the audit log.
import { POLICY_DEFAULTS, POLICY_LIMITS, COMMODITIES } from './constants.js';
import { UserError } from './errors.js';
import { audit } from './audit.js';

export function initPolicy(eco) {
  const insert = eco.db.prepare('INSERT OR IGNORE INTO policy (key, value, updated_day, updated_by) VALUES (?, ?, ?, ?)');
  for (const [key, value] of Object.entries(POLICY_DEFAULTS)) insert.run(key, JSON.stringify(value), eco.currentDay(), 'genesis');
}

export function getPolicy(eco, key) {
  const row = eco.db.prepare('SELECT value FROM policy WHERE key = ?').get(key);
  if (!row) {
    if (key in POLICY_DEFAULTS) return structuredClone(POLICY_DEFAULTS[key]);
    throw new Error(`Unknown policy key ${key}`);
  }
  return JSON.parse(row.value);
}

export function allPolicy(eco) {
  const out = {};
  for (const key of Object.keys(POLICY_DEFAULTS)) out[key] = getPolicy(eco, key);
  return out;
}

function checkRange(key, value) {
  const [min, max] = POLICY_LIMITS[key] ?? [null, null];
  if (!Number.isInteger(value)) throw new UserError('Policy values must be whole numbers.');
  if (min !== null && (value < min || value > max)) throw new UserError(`Value out of the permitted range for ${key} (${min} to ${max}).`);
}

// Sets a scalar policy value. Changes take effect immediately for new transactions.
export function setPolicy(eco, { key, value, actor, reason }) {
  if (!(key in POLICY_DEFAULTS) || typeof POLICY_DEFAULTS[key] === 'object') throw new UserError(`Unknown policy setting: ${key}`);
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  checkRange(key, value);
  return eco.tx(() => {
    const old = getPolicy(eco, key);
    eco.db.prepare('UPDATE policy SET value = ?, updated_day = ?, updated_by = ? WHERE key = ?').run(JSON.stringify(value), eco.currentDay(), actor, key);
    audit(eco, { actor, action: 'policy.set', target: key, oldValue: old, newValue: value, reason });
    return { key, old, value };
  });
}

// Sets one commodity entry of a per-commodity policy (import tariffs, export duties, export bans).
export function setCommodityPolicy(eco, { key, commodity, value, actor, reason }) {
  if (!['import_tariff_bp', 'export_duty_bp', 'export_ban'].includes(key)) throw new UserError('Unknown commodity policy.');
  const c = COMMODITIES[commodity];
  if (!c) throw new UserError('Unknown commodity.');
  if (key === 'import_tariff_bp' && c.tradable !== 'import') throw new UserError(`${c.name} is not an import commodity.`);
  if (key !== 'import_tariff_bp' && c.tradable !== 'export') throw new UserError(`${c.name} is not an export commodity.`);
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  if (key === 'export_ban') {
    if (typeof value !== 'boolean') throw new Error('export_ban needs a boolean');
  } else {
    checkRange(key, value);
  }
  return eco.tx(() => {
    const map = getPolicy(eco, key);
    const old = map[commodity] ?? (key === 'export_ban' ? false : 0);
    if (key === 'export_ban' && !value) delete map[commodity];
    else map[commodity] = value;
    eco.db.prepare('UPDATE policy SET value = ?, updated_day = ?, updated_by = ? WHERE key = ?').run(JSON.stringify(map), eco.currentDay(), actor, key);
    audit(eco, { actor, action: 'policy.set', target: `${key}.${commodity}`, oldValue: old, newValue: value, reason });
    return { key, commodity, old, value };
  });
}

// Policy changes made on a given day (used by the daily report).
export function policyChangesOnDay(eco, day) {
  return eco.db.prepare("SELECT * FROM audit_log WHERE action = 'policy.set' AND econ_day = ? ORDER BY id").all(day);
}
