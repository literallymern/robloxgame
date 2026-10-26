// Audit log for consequential administrative and government actions.
export function audit(eco, { actor, action, target = null, amount = null, oldValue = null, newValue = null, reason = null, result = null }) {
  const enc = (v) => (v === null || v === undefined ? null : typeof v === 'string' ? v : JSON.stringify(v));
  const res = eco.db.prepare(`INSERT INTO audit_log (created_at, econ_day, actor_id, action, target, amount, old_value, new_value, reason, result)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
    eco.clock.isoNow(), eco.currentDay(), actor, action, target, amount, enc(oldValue), enc(newValue), reason, enc(result),
  );
  return Number(res.lastInsertRowid);
}

export function unmirroredAudit(eco, limit = 20) {
  return eco.db.prepare('SELECT * FROM audit_log WHERE mirrored = 0 ORDER BY id LIMIT ?').all(limit);
}

export function markMirrored(eco, id) {
  eco.db.prepare('UPDATE audit_log SET mirrored = 1 WHERE id = ?').run(id);
}

export function recentAudit(eco, { actor = null, target = null, limit = 15 } = {}) {
  if (actor) return eco.db.prepare('SELECT * FROM audit_log WHERE actor_id = ? ORDER BY id DESC LIMIT ?').all(actor, limit);
  if (target) return eco.db.prepare('SELECT * FROM audit_log WHERE target = ? ORDER BY id DESC LIMIT ?').all(target, limit);
  return eco.db.prepare('SELECT * FROM audit_log ORDER BY id DESC LIMIT ?').all(limit);
}
