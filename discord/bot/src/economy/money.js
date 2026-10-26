// Money helpers. All amounts are integers in minor units (100 = 1.00 KGD).
import { UserError } from './errors.js';

export function toMinor(kgd) {
  if (typeof kgd !== 'number' || !Number.isFinite(kgd)) throw new UserError('Please enter a valid amount.');
  const minor = Math.round(kgd * 100);
  if (Math.abs(minor - kgd * 100) > 1e-6) throw new UserError('Amounts can have at most two decimal places.');
  return minor;
}

// Parses a positive amount entered by a player (KGD) into minor units.
export function parseAmount(kgd, { max = 100_000_000_00 } = {}) {
  const minor = toMinor(kgd);
  if (minor <= 0) throw new UserError('The amount must be greater than zero.');
  if (minor > max) throw new UserError(`The amount is too large (maximum ${formatKGD(max)}).`);
  return minor;
}

export function formatKGD(minor, { sign = false } = {}) {
  const negative = minor < 0;
  const abs = Math.abs(Math.round(minor));
  const whole = Math.floor(abs / 100).toLocaleString('en-US');
  const cents = String(abs % 100).padStart(2, '0');
  const prefix = negative ? '-' : sign && minor > 0 ? '+' : '';
  return `${prefix}${whole}.${cents} KGD`;
}

// Short form for tables: 1.2M, 35.4K, 812.50
export function formatCompact(minor) {
  const kgd = minor / 100;
  const abs = Math.abs(kgd);
  if (abs >= 1e6) return `${(kgd / 1e6).toFixed(2)}M`;
  if (abs >= 1e4) return `${(kgd / 1e3).toFixed(1)}K`;
  return kgd.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

export function formatPct(value, { sign = true, digits = 2 } = {}) {
  if (value === null || value === undefined || !Number.isFinite(value)) return 'n/a';
  const s = (value * 100).toFixed(digits);
  return `${sign && value > 0 ? '+' : ''}${s}%`;
}

export function bpToPct(bp) {
  return `${(bp / 100).toFixed(2)}%`;
}

// Applies a basis-point rate to an amount, rounding half up. Never negative.
export function applyBp(amount, bp) {
  return Math.max(0, Math.round((amount * bp) / 10000));
}
