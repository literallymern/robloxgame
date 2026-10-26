// Economic events: bounded, time-limited changes to simulation variables.
import { EVENT_CATALOG, MAX_CONCURRENT_RANDOM_EVENTS } from './event-catalog.js';
import { COMMODITIES } from './constants.js';
import { UserError } from './errors.js';
import { audit } from './audit.js';

export function eventsActiveOn(eco, day) {
  return eco.db.prepare(`SELECT * FROM event_instances
    WHERE status <> 'cancelled' AND start_day <= ? AND end_day >= ? ORDER BY id`).all(day, day)
    .map((e) => ({ ...e, effects: JSON.parse(e.effects) }));
}

// Combined effect of all events active on `day`.
export function effectsForDay(eco, day) {
  const events = eventsActiveOn(eco, day);
  const drift = {};
  const production = [];
  const cost = [];
  const partner = {};
  for (const ev of events) {
    for (const e of ev.effects) {
      if (e.type === 'price_drift') drift[e.commodity] = (drift[e.commodity] ?? 0) + e.perDay;
      if (e.type === 'production') production.push(e);
      if (e.type === 'production_cost') cost.push(e);
      if (e.type === 'partner_demand') partner[e.partner] = (partner[e.partner] ?? 1) * e.multiplier;
    }
  }
  const matches = (target, commodity, industry) => target === 'all' || target === commodity || target === industry;
  return {
    events,
    drift: (commodity) => drift[commodity] ?? 0,
    productionMultiplier: (commodity, industry) => production.filter((e) => matches(e.target, commodity, industry)).reduce((m, e) => m * e.multiplier, 1),
    costMultiplier: (industry) => cost.filter((e) => matches(e.target, null, industry)).reduce((m, e) => m * e.multiplier, 1),
    partnerMultiplier: (p) => partner[p] ?? 1,
  };
}

export function startEvent(eco, { key, startDay, durationDays, source = 'admin', actor = 'system', reason = null }) {
  const def = EVENT_CATALOG[key];
  if (!def) throw new UserError('Unknown economic event.');
  const duration = durationDays ?? def.durationDays;
  if (!(Number.isInteger(duration) && duration >= 1 && duration <= 30)) throw new UserError('Duration must be between 1 and 30 days.');
  if (source === 'admin' && (!reason || reason.trim().length < 5)) throw new UserError('Please give a reason (at least 5 characters).');
  return eco.tx(() => {
    const endDay = startDay + duration - 1;
    const overlap = eco.db.prepare(`SELECT id FROM event_instances WHERE event_key = ? AND status <> 'cancelled'
      AND start_day <= ? AND end_day >= ?`).get(key, endDay, startDay);
    if (overlap) throw new UserError('This event is already active or scheduled for that period.');
    const res = eco.db.prepare(`INSERT INTO event_instances (event_key, name, start_day, end_day, status, source, created_by, reason, effects, created_day)
      VALUES (?, ?, ?, ?, 'active', ?, ?, ?, ?, ?)`).run(key, def.name, startDay, endDay, source, actor, reason, JSON.stringify(def.effects), eco.currentDay());
    const id = Number(res.lastInsertRowid);
    if (source === 'admin') audit(eco, { actor, action: 'event.start', target: `event:${id}`, newValue: { key, startDay, endDay }, reason });
    return { id, key, name: def.name, startDay, endDay };
  });
}

// Ends an event early. Days already processed keep their effects.
export function endEvent(eco, { id, actor, reason }) {
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  return eco.tx(() => {
    const ev = eco.db.prepare('SELECT * FROM event_instances WHERE id = ?').get(id);
    if (!ev || ev.status === 'cancelled') throw new UserError('No such active event.');
    const today = eco.currentDay();
    if (ev.end_day < today) throw new UserError('This event has already ended.');
    const newEnd = today - 1;
    if (newEnd < ev.start_day) {
      eco.db.prepare("UPDATE event_instances SET status = 'cancelled' WHERE id = ?").run(id);
    } else {
      eco.db.prepare("UPDATE event_instances SET status = 'ended', end_day = ? WHERE id = ?").run(newEnd, id);
    }
    audit(eco, { actor, action: 'event.end', target: `event:${id}`, oldValue: { endDay: ev.end_day }, newValue: { endDay: newEnd }, reason });
    return ev;
  });
}

// Called by the tick of `day`: may start random events that become active on day + 1.
export function rollRandomEvents(eco, day, rng) {
  const nextDay = day + 1;
  const activeRandom = eco.db.prepare(`SELECT COUNT(*) AS n FROM event_instances WHERE source = 'random'
    AND status <> 'cancelled' AND start_day <= ? AND end_day >= ?`).get(nextDay, nextDay).n;
  let slots = MAX_CONCURRENT_RANDOM_EVENTS - Number(activeRandom);
  const started = [];
  for (const [key, def] of Object.entries(EVENT_CATALOG)) {
    const roll = rng.next(); // always draw, so results do not depend on earlier outcomes
    if (slots <= 0 || !(def.probability > 0) || roll >= def.probability) continue;
    const recent = eco.db.prepare(`SELECT id FROM event_instances WHERE event_key = ? AND status <> 'cancelled'
      AND end_day >= ?`).get(key, nextDay - def.cooldownDays);
    if (recent) continue;
    started.push(startEvent(eco, { key, startDay: nextDay, source: 'random' }));
    slots -= 1;
  }
  return started;
}

export function describeEffect(e) {
  const pct = (m) => `${m >= 1 ? '+' : ''}${Math.round((m - 1) * 100)}%`;
  if (e.type === 'price_drift') return `${COMMODITIES[e.commodity]?.name ?? e.commodity} world price ${e.perDay >= 0 ? '+' : ''}${(e.perDay * 100).toFixed(1)}% per day`;
  if (e.type === 'production') return `output per shift (${e.target}) ${pct(e.multiplier)}`;
  if (e.type === 'production_cost') return `production costs (${e.target}) ${pct(e.multiplier)}`;
  if (e.type === 'partner_demand') return `prices offered by ${e.partner} ${pct(e.multiplier)}`;
  return e.type;
}
