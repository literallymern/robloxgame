// Discord <-> Roblox account links for the Ro-Nation Roblox game.
//
// How a link is made (both sides take part):
//   1. The Roblox game server asks the bridge for a code for a Roblox user (createLinkCode).
//   2. The player types that code in Discord with /link confirm (confirmLink).
// Roblox authenticates the Roblox account, Discord authenticates the Discord account; the link only
// exists when both halves meet. One Discord account <-> one Roblox account.
//
// Linking never moves money. The Discord command opens the citizen record with the normal Discord
// rules before confirming, so the starting grant still follows the Discord rules only.
import { createHash, randomInt } from 'node:crypto';
import { UserError } from './errors.js';
import { audit } from './audit.js';

export const LINK_RULES = {
  codeLength: 8,
  codeTtlMinutes: 10,
  maxCodesPerWindow: 5, // codes one Roblox account may request ...
  codeWindowMinutes: 10, // ... within this many minutes
  maxFailedConfirms: 5, // wrong codes one Discord account may enter ...
  failedWindowMinutes: 10, // ... within this many minutes
  removalCoolingHours: 24, // a self-requested removal takes effect after this delay
};

// No 0/O, 1/I/L: codes are typed by hand.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const ROBLOX_ID = /^[1-9][0-9]{0,15}$/;
const ROBLOX_NAME = /^[A-Za-z0-9_]{3,20}$/;

export function isRobloxUserId(value) {
  return typeof value === 'string' && ROBLOX_ID.test(value);
}

function cleanRobloxName(name) {
  return typeof name === 'string' && ROBLOX_NAME.test(name) ? name : null;
}

const minutesAgo = (eco, minutes) => new Date(eco.clock.now().getTime() - minutes * 60_000).toISOString();
const minutesAhead = (eco, minutes) => new Date(eco.clock.now().getTime() + minutes * 60_000).toISOString();

// "abcd efgh" / "ABCD-EFGH" -> "ABCDEFGH", or null if it cannot be a code.
export function normalizeCode(input) {
  const code = String(input ?? '').toUpperCase().replace(/[\s-]/g, '');
  if (code.length !== LINK_RULES.codeLength) return null;
  for (const ch of code) if (!CODE_ALPHABET.includes(ch)) return null;
  return code;
}

export function formatCode(code) {
  return `${code.slice(0, 4)}-${code.slice(4)}`;
}

function hashCode(code) {
  return createHash('sha256').update(`ro-nation-link:${code}`).digest('hex');
}

function newCode() {
  let code = '';
  for (let i = 0; i < LINK_RULES.codeLength; i += 1) code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  return code;
}

export function removalEffectiveAt(link) {
  if (!link?.removal_requested_at) return null;
  return new Date(new Date(link.removal_requested_at).getTime() + LINK_RULES.removalCoolingHours * 3_600_000).toISOString();
}

// Finishes self-requested removals whose cooling-off period has passed.
export function applyDueRemovals(eco) {
  const cutoff = new Date(eco.clock.now().getTime() - LINK_RULES.removalCoolingHours * 3_600_000).toISOString();
  const due = eco.db.prepare("SELECT * FROM account_links WHERE status = 'active' AND removal_requested_at IS NOT NULL AND removal_requested_at <= ?").all(cutoff);
  if (!due.length) return 0;
  eco.tx(() => {
    for (const l of due) {
      eco.db.prepare("UPDATE account_links SET status = 'removed', removed_at = ?, removed_by = ?, removed_reason = ? WHERE id = ? AND status = 'active'")
        .run(eco.clock.isoNow(), l.discord_id, 'Removal requested by the member (cooling-off period over)', l.id);
      audit(eco, { actor: l.discord_id, action: 'link.removed', target: `roblox:${l.roblox_user_id}`, reason: 'Self-requested removal after the cooling-off period' });
    }
  });
  return due.length;
}

export function activeLinkByDiscord(eco, discordId) {
  applyDueRemovals(eco);
  return eco.db.prepare("SELECT * FROM account_links WHERE discord_id = ? AND status = 'active'").get(discordId) ?? null;
}

export function activeLinkByRoblox(eco, robloxUserId) {
  applyDueRemovals(eco);
  return eco.db.prepare("SELECT * FROM account_links WHERE roblox_user_id = ? AND status = 'active'").get(String(robloxUserId)) ?? null;
}

// Step 1 (Roblox side): a new single-use code for this Roblox account.
// Earlier open codes of the same account stop working.
export function createLinkCode(eco, { robloxUserId, robloxName = null }) {
  if (!isRobloxUserId(robloxUserId)) throw new UserError('Invalid Roblox user ID.');
  const existing = activeLinkByRoblox(eco, robloxUserId);
  if (existing) return { status: 'linked', link: existing };
  return eco.tx(() => {
    const recent = eco.db.prepare('SELECT COUNT(*) AS n FROM link_codes WHERE roblox_user_id = ? AND created_at >= ?')
      .get(robloxUserId, minutesAgo(eco, LINK_RULES.codeWindowMinutes)).n;
    if (recent >= LINK_RULES.maxCodesPerWindow) {
      throw new UserError(`Too many link codes requested. Please wait ${LINK_RULES.codeWindowMinutes} minutes and try again.`);
    }
    const now = eco.clock.isoNow();
    eco.db.prepare('UPDATE link_codes SET revoked_at = ? WHERE roblox_user_id = ? AND used_at IS NULL AND revoked_at IS NULL').run(now, robloxUserId);
    let code;
    for (let attempt = 0; ; attempt += 1) {
      code = newCode();
      if (!eco.db.prepare('SELECT 1 FROM link_codes WHERE code_hash = ?').get(hashCode(code))) break;
      if (attempt > 20) throw new Error('Could not create a unique link code');
    }
    const expiresAt = minutesAhead(eco, LINK_RULES.codeTtlMinutes);
    eco.db.prepare('INSERT INTO link_codes (code_hash, roblox_user_id, roblox_name, created_at, expires_at) VALUES (?, ?, ?, ?, ?)')
      .run(hashCode(code), robloxUserId, cleanRobloxName(robloxName), now, expiresAt);
    audit(eco, { actor: `roblox:${robloxUserId}`, action: 'link.code_issued', target: `roblox:${robloxUserId}` });
    return { status: 'code', code: formatCode(code), expiresAt };
  });
}

function recordFailedConfirm(eco, discordId, reason) {
  eco.tx(() => audit(eco, { actor: discordId, action: 'link.confirm_failed', reason }));
}

// Step 2 (Discord side): the member enters the code. Returns the new link.
export function confirmLink(eco, { discordId, code: input }) {
  applyDueRemovals(eco);
  const failures = eco.db.prepare("SELECT COUNT(*) AS n FROM audit_log WHERE action = 'link.confirm_failed' AND actor_id = ? AND created_at >= ?")
    .get(discordId, minutesAgo(eco, LINK_RULES.failedWindowMinutes)).n;
  if (failures >= LINK_RULES.maxFailedConfirms) {
    throw new UserError(`Too many wrong codes. Please wait ${LINK_RULES.failedWindowMinutes} minutes, then request a new code in the game.`);
  }
  const code = normalizeCode(input);
  const row = code
    ? eco.db.prepare('SELECT * FROM link_codes WHERE code_hash = ? AND used_at IS NULL AND revoked_at IS NULL AND expires_at > ?').get(hashCode(code), eco.clock.isoNow())
    : null;
  if (!row) {
    recordFailedConfirm(eco, discordId, code ? 'unknown or expired code' : 'malformed code');
    throw new UserError('This code is wrong or has expired. Request a new code in the Ro-Nation game and try again.');
  }
  return eco.tx(() => {
    const mine = eco.db.prepare("SELECT * FROM account_links WHERE discord_id = ? AND status = 'active'").get(discordId);
    if (mine) {
      throw new UserError(`Your Discord account is already linked to the Roblox account ${mine.roblox_name ?? mine.roblox_user_id}. Remove that link first with /link remove.`);
    }
    const taken = eco.db.prepare("SELECT * FROM account_links WHERE roblox_user_id = ? AND status = 'active'").get(row.roblox_user_id);
    if (taken) {
      eco.db.prepare('UPDATE link_codes SET revoked_at = ? WHERE id = ?').run(eco.clock.isoNow(), row.id);
      throw new UserError('This Roblox account is already linked to another Discord account. If this is wrong, open a support ticket.');
    }
    const now = eco.clock.isoNow();
    eco.db.prepare('UPDATE link_codes SET used_at = ?, used_by = ? WHERE id = ?').run(now, discordId, row.id);
    const res = eco.db.prepare(`INSERT INTO account_links (discord_id, roblox_user_id, roblox_name, status, linked_at, linked_day)
      VALUES (?, ?, ?, 'active', ?, ?)`).run(discordId, row.roblox_user_id, row.roblox_name, now, eco.currentDay());
    audit(eco, { actor: discordId, action: 'link.created', target: `roblox:${row.roblox_user_id}`, newValue: row.roblox_name ?? row.roblox_user_id });
    return eco.db.prepare('SELECT * FROM account_links WHERE id = ?').get(res.lastInsertRowid);
  });
}

// /link remove: takes effect after the cooling-off period, so a stolen Discord session cannot
// move an identity at once. Repeating the request keeps the original time.
export function requestLinkRemoval(eco, { discordId }) {
  return eco.tx(() => {
    const link = activeLinkByDiscord(eco, discordId);
    if (!link) throw new UserError('Your Discord account is not linked to a Roblox account.');
    if (!link.removal_requested_at) {
      eco.db.prepare('UPDATE account_links SET removal_requested_at = ? WHERE id = ?').run(eco.clock.isoNow(), link.id);
      audit(eco, { actor: discordId, action: 'link.removal_requested', target: `roblox:${link.roblox_user_id}` });
    }
    const updated = eco.db.prepare('SELECT * FROM account_links WHERE id = ?').get(link.id);
    return { link: updated, effectiveAt: removalEffectiveAt(updated) };
  });
}

export function cancelLinkRemoval(eco, { discordId }) {
  return eco.tx(() => {
    const link = activeLinkByDiscord(eco, discordId);
    if (!link?.removal_requested_at) throw new UserError('There is no link removal to cancel.');
    eco.db.prepare('UPDATE account_links SET removal_requested_at = NULL WHERE id = ?').run(link.id);
    audit(eco, { actor: discordId, action: 'link.removal_cancelled', target: `roblox:${link.roblox_user_id}` });
    return link;
  });
}

// Staff recovery (e.g. a lost Discord account): removes a link at once. Audited with a reason.
export function staffRemoveLink(eco, { actor, discordId = null, robloxUserId = null, reason }) {
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  if (!!discordId === !!robloxUserId) throw new UserError('Choose exactly one: user or Roblox ID.');
  if (robloxUserId && !isRobloxUserId(robloxUserId)) throw new UserError('Invalid Roblox user ID.');
  return eco.tx(() => {
    const link = discordId ? activeLinkByDiscord(eco, discordId) : activeLinkByRoblox(eco, robloxUserId);
    if (!link) throw new UserError('No active link found.');
    eco.db.prepare("UPDATE account_links SET status = 'removed', removed_at = ?, removed_by = ?, removed_reason = ? WHERE id = ?")
      .run(eco.clock.isoNow(), actor, reason, link.id);
    audit(eco, { actor, action: 'link.removed_by_staff', target: `roblox:${link.roblox_user_id}`, oldValue: link.discord_id, reason });
    return link;
  });
}
