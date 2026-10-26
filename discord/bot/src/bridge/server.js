// HTTP bridge between the Ro-Nation Roblox game servers and the economy.
//
// - Only Roblox game servers call it, with an API key (never Roblox clients).
// - It uses Node's built-in http module and the existing economy functions; it has no economy
//   rules of its own and never pays a starting grant.
// - Reads are allowed during maintenance; writes are not (answer 503, nothing stored, retry later).
// - Every write is processed exactly once per operation ID (see operations.js).
//
// API version 1 (all answers are JSON; amounts are integers in minor units, 100 = 1.00 KGD):
//   GET  /v1/health
//   POST /v1/links/start                       { robloxUserId, robloxName }
//   GET  /v1/players/:robloxUserId/summary
//   GET  /v1/players/:robloxUserId/transactions?account=bank|cash&page=1
//   POST /v1/operations/test-cash-transfer     { operationId, robloxUserId, direction, amount }  (staging only)
//   POST /v1/operations/:operationId/resolve
import { createServer } from 'node:http';
import { createHash, timingSafeEqual } from 'node:crypto';
import { UserError } from '../economy/errors.js';
import { isMaintenance } from '../economy/admin.js';
import { lastCompletedDay } from '../economy/tick.js';
import { getCitizen, personalAccounts } from '../economy/citizens.js';
import { accountTransactions, withdrawCash, depositCash } from '../economy/payments.js';
import { createLinkCode, activeLinkByRoblox, isRobloxUserId, removalEffectiveAt } from '../economy/links.js';
import { isOperationId, runOperation, resolveOperation } from './operations.js';

export const BRIDGE_API_VERSION = 1;
export const MIN_API_KEY_LENGTH = 32;
export const TEST_TRANSFER_MAX = 10000; // 100.00 KGD
const MAX_BODY_BYTES = 8 * 1024;

const DEFAULT_LIMITS = { perKeyPerMinute: 600, perPlayerPerMinute: 60 };

class HttpError extends Error {
  constructor(status, error, message) {
    super(message);
    this.status = status;
    this.error = error;
  }
}

const digest = (value) => createHash('sha256').update(String(value)).digest();

// Sliding one-minute windows kept in memory (reset on restart, which is fine for abuse protection).
function createRateLimiter() {
  const hits = new Map();
  return (key, limit) => {
    const now = Date.now();
    const list = (hits.get(key) ?? []).filter((t) => now - t < 60_000);
    if (list.length >= limit) {
      hits.set(key, list);
      return false;
    }
    list.push(now);
    hits.set(key, list);
    if (hits.size > 10_000) for (const [k, v] of hits) if (!v.some((t) => now - t < 60_000)) hits.delete(k);
    return true;
  };
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        reject(new HttpError(413, 'too_large', 'Request body too large.'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

async function readJson(req) {
  if (!String(req.headers['content-type'] ?? '').toLowerCase().startsWith('application/json')) {
    throw new HttpError(415, 'unsupported_media_type', 'Send JSON with Content-Type: application/json.');
  }
  const text = await readBody(req);
  try {
    const value = JSON.parse(text || '{}');
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('not an object');
    return value;
  } catch {
    throw new HttpError(400, 'bad_json', 'The request body is not a valid JSON object.');
  }
}

function requireRobloxId(value) {
  const id = typeof value === 'number' && Number.isSafeInteger(value) ? String(value) : value;
  if (!isRobloxUserId(id)) throw new HttpError(400, 'bad_request', 'Invalid Roblox user ID.');
  return id;
}

function requireLink(eco, robloxUserId) {
  const link = activeLinkByRoblox(eco, robloxUserId);
  if (!link) throw new UserError('This Roblox account is not linked to a Discord account yet.');
  return link;
}

function accountView(acc) {
  return acc ? { balance: Number(acc.balance), frozen: !!acc.frozen } : null;
}

// Creates the HTTP server (not yet listening). Options:
//   eco             economy context
//   apiKey          shared secret; requests must send it as "Authorization: Bearer <key>" or "X-Api-Key: <key>"
//   testOperations  true only on staging: enables /v1/operations/test-cash-transfer
//   memberRoleKeys  async (discordId) => string[] | null, the member's current Discord role keys
//   log             { info, warn, error }
export function createBridgeServer({ eco, apiKey, testOperations = false, memberRoleKeys = async () => null, log = console, limits = DEFAULT_LIMITS }) {
  if (!apiKey || String(apiKey).length < MIN_API_KEY_LENGTH) {
    throw new Error(`The bridge API key must be at least ${MIN_API_KEY_LENGTH} characters long.`);
  }
  const expected = digest(apiKey);
  const allow = createRateLimiter();
  let lastAuthWarning = 0;

  function authorised(req) {
    const header = String(req.headers.authorization ?? '');
    const provided = header.toLowerCase().startsWith('bearer ') ? header.slice(7).trim() : String(req.headers['x-api-key'] ?? '').trim();
    if (!provided) return false;
    return timingSafeEqual(digest(provided), expected);
  }

  function writesAllowed() {
    if (isMaintenance(eco)) throw new HttpError(503, 'maintenance', 'The economy is in maintenance mode. Please try again later.');
  }

  function playerLimit(robloxUserId) {
    if (!allow(`player:${robloxUserId}`, limits.perPlayerPerMinute)) throw new HttpError(429, 'rate_limited', 'Too many requests for this player. Please wait a moment.');
  }

  const routes = [
    {
      method: 'GET', pattern: /^\/v1\/health$/,
      handler: async () => ({
        status: 200,
        body: {
          ok: true, service: 'ro-nation-bridge', apiVersion: BRIDGE_API_VERSION, maintenance: isMaintenance(eco),
          econDay: eco.currentDay(), lastCompletedDay: lastCompletedDay(eco), testOperations: !!testOperations, time: eco.clock.isoNow(),
        },
      }),
    },
    {
      method: 'POST', pattern: /^\/v1\/links\/start$/,
      handler: async (req) => {
        const body = await readJson(req);
        const robloxUserId = requireRobloxId(body.robloxUserId);
        playerLimit(robloxUserId);
        writesAllowed();
        const res = createLinkCode(eco, { robloxUserId, robloxName: body.robloxName ?? null });
        if (res.status === 'linked') return { status: 200, body: { ok: true, status: 'linked', robloxUserId } };
        return { status: 200, body: { ok: true, status: 'code', code: res.code, expiresAt: res.expiresAt, command: '/link confirm' } };
      },
    },
    {
      method: 'GET', pattern: /^\/v1\/players\/([0-9]{1,16})\/summary$/,
      handler: async (req, [id]) => {
        const robloxUserId = requireRobloxId(id);
        playerLimit(robloxUserId);
        const link = activeLinkByRoblox(eco, robloxUserId);
        const base = { ok: true, robloxUserId, econDay: eco.currentDay(), maintenance: isMaintenance(eco), asOf: eco.clock.isoNow() };
        if (!link) return { status: 200, body: { ...base, linked: false } };
        const citizen = getCitizen(eco, link.discord_id);
        const accounts = citizen ? personalAccounts(eco, link.discord_id) : [];
        let roles = null;
        try {
          roles = await memberRoleKeys(link.discord_id);
        } catch (err) {
          log.warn('Bridge: could not read Discord roles:', err.message);
        }
        return {
          status: 200,
          body: {
            ...base,
            linked: true,
            discord: { displayName: citizen?.display_name ?? null, removalEffectiveAt: removalEffectiveAt(link) },
            citizen: !!citizen,
            accounts: {
              bank: accountView(accounts.find((a) => a.kind === 'personal_bank')),
              cash: accountView(accounts.find((a) => a.kind === 'personal_cash')),
            },
            creditScore: citizen ? Number(citizen.credit_score) : null,
            roles,
          },
        };
      },
    },
    {
      method: 'GET', pattern: /^\/v1\/players\/([0-9]{1,16})\/transactions$/,
      handler: async (req, [id], url) => {
        const robloxUserId = requireRobloxId(id);
        playerLimit(robloxUserId);
        const which = url.searchParams.get('account') ?? 'bank';
        if (!['bank', 'cash'].includes(which)) throw new HttpError(400, 'bad_request', 'account must be "bank" or "cash".');
        const page = Number(url.searchParams.get('page') ?? 1);
        if (!Number.isInteger(page) || page < 1 || page > 50) throw new HttpError(400, 'bad_request', 'page must be 1-50.');
        const link = requireLink(eco, robloxUserId);
        const acc = personalAccounts(eco, link.discord_id).find((a) => a.kind === (which === 'cash' ? 'personal_cash' : 'personal_bank'));
        if (!acc) return { status: 200, body: { ok: true, account: which, page, items: [] } };
        const items = accountTransactions(eco, acc.id, { limit: 10, offset: (page - 1) * 10 }).map((t) => {
          const incoming = Number(t.to_account) === Number(acc.id);
          return {
            id: Number(t.id), day: Number(t.econ_day), createdAt: t.created_at, direction: incoming ? 'in' : 'out', amount: Number(t.amount),
            counterparty: incoming ? t.from_name : t.to_name, category: t.category, memo: t.memo ?? null,
          };
        });
        return { status: 200, body: { ok: true, account: which, page, balance: Number(acc.balance), items } };
      },
    },
    {
      method: 'POST', pattern: /^\/v1\/operations\/test-cash-transfer$/,
      handler: async (req) => {
        if (!testOperations) throw new HttpError(404, 'not_found', 'Unknown endpoint.');
        const body = await readJson(req);
        const robloxUserId = requireRobloxId(body.robloxUserId);
        if (!isOperationId(body.operationId)) throw new HttpError(400, 'bad_request', 'Invalid operation ID.');
        if (!['withdraw', 'deposit'].includes(body.direction)) throw new HttpError(400, 'bad_request', 'direction must be "withdraw" or "deposit".');
        if (!Number.isSafeInteger(body.amount) || body.amount < 1 || body.amount > TEST_TRANSFER_MAX) {
          throw new HttpError(400, 'bad_request', `amount must be a whole number of minor units between 1 and ${TEST_TRANSFER_MAX}.`);
        }
        playerLimit(robloxUserId);
        writesAllowed();
        const link = activeLinkByRoblox(eco, robloxUserId);
        const payload = { direction: body.direction, amount: body.amount };
        return runOperation(eco, {
          operationId: body.operationId, kind: 'test_cash_transfer', robloxUserId, discordId: link?.discord_id ?? null, payload,
          execute: () => {
            if (!link) throw new UserError('This Roblox account is not linked to a Discord account yet.');
            if (!getCitizen(eco, link.discord_id)) throw new UserError('Open your Kagundi bank account in Discord first with /bank balance.');
            const fn = body.direction === 'withdraw' ? withdrawCash : depositCash;
            const transactionId = fn(eco, {
              userId: link.discord_id, amount: body.amount, key: `bridge:${body.operationId}`,
              memo: `Roblox test ${body.direction} (operation ${body.operationId})`,
            });
            const accs = personalAccounts(eco, link.discord_id);
            return {
              transactionId,
              accounts: {
                bank: accountView(accs.find((a) => a.kind === 'personal_bank')),
                cash: accountView(accs.find((a) => a.kind === 'personal_cash')),
              },
            };
          },
        });
      },
    },
    {
      method: 'POST', pattern: /^\/v1\/operations\/([A-Za-z0-9-]{8,64})\/resolve$/,
      handler: async (req, [operationId]) => resolveOperation(eco, { operationId }),
    },
  ];

  async function handle(req, res) {
    const url = new URL(req.url ?? '/', 'http://bridge.local');
    if (!authorised(req)) {
      if (Date.now() - lastAuthWarning > 60_000) {
        lastAuthWarning = Date.now();
        log.warn(`Bridge: refused a request without a valid API key (${req.method} ${url.pathname}).`);
      }
      throw new HttpError(401, 'unauthorised', 'Missing or invalid API key.');
    }
    if (!allow('key', limits.perKeyPerMinute)) throw new HttpError(429, 'rate_limited', 'Too many requests. Please slow down.');
    const matches = routes.filter((r) => r.pattern.test(url.pathname));
    if (!matches.length) throw new HttpError(404, 'not_found', 'Unknown endpoint.');
    const route = matches.find((r) => r.method === req.method);
    if (!route) throw new HttpError(405, 'method_not_allowed', `Use ${matches.map((r) => r.method).join(' or ')}.`);
    const params = url.pathname.match(route.pattern).slice(1);
    return route.handler(req, params, url);
  }

  return createServer((req, res) => {
    const send = (status, body) => {
      if (res.headersSent) return;
      const text = JSON.stringify(body);
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'Content-Length': Buffer.byteLength(text) });
      res.end(text);
    };
    handle(req, res)
      .then(({ status, body }) => send(status, body))
      .catch((err) => {
        if (err instanceof HttpError) return send(err.status, { ok: false, error: err.error, message: err.message });
        if (err instanceof UserError) return send(422, { ok: false, error: 'refused', message: err.message });
        log.error('Bridge request failed:', err);
        return send(500, { ok: false, error: 'internal_error', message: 'Something went wrong in the economy. Nothing was changed.' });
      });
  });
}

// Starts the bridge if it is switched on. Returns the server, or null if it is off or misconfigured.
export function startBridge({ eco, config, memberRoleKeys, log = console }) {
  const b = config.bridge;
  if (!b?.enabled) return null;
  let server;
  try {
    server = createBridgeServer({ eco, apiKey: b.apiKey, testOperations: b.testOperations, memberRoleKeys, log });
  } catch (err) {
    log.error(`Roblox bridge not started: ${err.message} Set BRIDGE_API_KEY in .env.`);
    return null;
  }
  server.on('error', (err) => log.error('Roblox bridge error:', err.message));
  server.listen(b.port, b.host, () => {
    log.info(`Roblox bridge listening on ${b.host}:${b.port}${b.testOperations ? ' (test operations ON - staging only)' : ''}.`);
  });
  return server;
}
