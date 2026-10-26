// Exactly-once processing for write operations sent by the Roblox game server.
//
// The game server creates an operation ID before its first attempt and reuses it on every retry.
// The first request with an ID is executed and its answer is stored in the same database
// transaction as its effects. A repeated request with the same ID and the same content gets the
// stored answer again; one with different content is refused. Money movements additionally use the
// ledger idempotency key "bridge:<operationId>".
import { createHash } from 'node:crypto';
import { UserError } from '../economy/errors.js';
import { audit } from '../economy/audit.js';

const OPERATION_ID = /^[A-Za-z0-9-]{8,64}$/;

export function isOperationId(value) {
  return typeof value === 'string' && OPERATION_ID.test(value);
}

// Stable JSON (sorted keys), so the same content always gives the same hash.
function stable(value) {
  if (Array.isArray(value)) return `[${value.map(stable).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((k) => `${JSON.stringify(k)}:${stable(value[k])}`).join(',')}}`;
  }
  return JSON.stringify(value ?? null);
}

export function payloadHash(kind, robloxUserId, payload) {
  return createHash('sha256').update(stable({ kind, robloxUserId, payload })).digest('hex');
}

function getOperation(eco, operationId) {
  return eco.db.prepare('SELECT * FROM bridge_operations WHERE operation_id = ?').get(operationId) ?? null;
}

function storedAnswer(row) {
  return { status: row.http_status, body: { ...JSON.parse(row.result), operationId: row.operation_id, state: row.state, replayed: true } };
}

// Runs `execute` once per operation ID. `execute` returns the success body (plain object) or throws
// a UserError (a refusal the player may see). Any other error rolls everything back, stores nothing
// and propagates, so the game server can retry the same operation later.
export function runOperation(eco, { operationId, kind, robloxUserId, discordId = null, payload, execute }) {
  const hash = payloadHash(kind, robloxUserId, payload);
  return eco.tx(() => {
    const existing = getOperation(eco, operationId);
    if (existing) {
      if (existing.payload_hash !== hash) {
        return { status: 409, body: { ok: false, error: 'operation_conflict', operationId, message: 'This operation ID was already used for a different request.' } };
      }
      return storedAnswer(existing);
    }
    let state;
    let status;
    let body;
    eco.db.exec('SAVEPOINT bridge_operation');
    try {
      body = { ok: true, ...execute() };
      eco.db.exec('RELEASE bridge_operation');
      state = 'succeeded';
      status = 200;
    } catch (err) {
      eco.db.exec('ROLLBACK TO bridge_operation');
      eco.db.exec('RELEASE bridge_operation');
      if (!(err instanceof UserError)) throw err;
      state = 'refused';
      status = 422;
      body = { ok: false, error: 'refused', message: err.message };
    }
    eco.db.prepare(`INSERT INTO bridge_operations (operation_id, kind, roblox_user_id, discord_id, payload_hash, state, http_status, result, created_at, econ_day)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(operationId, kind, robloxUserId, discordId, hash, state, status, JSON.stringify(body), eco.clock.isoNow(), eco.currentDay());
    audit(eco, {
      actor: discordId ?? `roblox:${robloxUserId}`, action: `bridge.${kind}.${state}`, target: `roblox:${robloxUserId}`,
      amount: Number.isInteger(payload?.amount) ? payload.amount : null, reason: state === 'refused' ? body.message : null,
      result: { operationId, transaction: body.transactionId ?? null },
    });
    return { status, body: { ...body, operationId, state, replayed: false } };
  });
}

// Used by the game server to settle an operation whose answer it never received:
// returns the stored answer, or marks the ID as void so a late copy of the request can never run.
export function resolveOperation(eco, { operationId }) {
  return eco.tx(() => {
    const existing = getOperation(eco, operationId);
    if (existing) return storedAnswer(existing);
    const body = { ok: false, error: 'voided', message: 'This operation never reached the economy and has been cancelled. Nothing was changed.' };
    eco.db.prepare(`INSERT INTO bridge_operations (operation_id, kind, roblox_user_id, discord_id, payload_hash, state, http_status, result, created_at, econ_day)
      VALUES (?, 'void', NULL, NULL, 'void', 'voided', 410, ?, ?, ?)`).run(operationId, JSON.stringify(body), eco.clock.isoNow(), eco.currentDay());
    return { status: 410, body: { ...body, operationId, state: 'voided', replayed: false } };
  });
}
