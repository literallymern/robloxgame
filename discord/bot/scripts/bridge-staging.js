// Staging bridge for Roblox Studio tests. Runs NEXT TO the normal bot, never instead of it.
//
//   npm run bridge-staging
//
// - Uses its own database (data/staging.db by default), never the live economy database.
// - Does not log in to Discord. The "Discord side" of linking is simulated in this console
//   (type: confirm ABCD-EFGH), always for the Owner's Discord ID from .env.
// - Listens only on this computer (127.0.0.1, port 8788 by default) with its own staging key,
//   stored in data/bridge-staging.key. That key goes into Roblox Studio's Local Secrets.
// - Test operations (the small test cash transfer) are switched on here, and only here.
import { createInterface } from 'node:readline';
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import { config } from '../src/config.js';
import { createEconomy } from '../src/economy/index.js';
import { ensureCitizen, personalAccounts } from '../src/economy/citizens.js';
import { accountTransactions } from '../src/economy/payments.js';
import { confirmLink, activeLinkByDiscord, staffRemoveLink } from '../src/economy/links.js';
import { createBridgeServer } from '../src/bridge/server.js';
import { formatKGD } from '../src/economy/money.js';
import { UserError } from '../src/economy/errors.js';

const dbPath = resolve(config.root, process.env.STAGING_DATABASE_PATH || 'data/staging.db');
if (dbPath === config.databasePath) {
  console.error('STAGING_DATABASE_PATH points to the live database. Use a separate file, e.g. data/staging.db.');
  process.exit(1);
}
const port = Number(process.env.BRIDGE_STAGING_PORT || 8788);
const keyFile = resolve(config.root, 'data', 'bridge-staging.key');
let apiKey = process.env.BRIDGE_STAGING_API_KEY || null;
const keySource = apiKey ? 'BRIDGE_STAGING_API_KEY in .env' : `the file ${keyFile}`;
if (!apiKey) {
  if (!existsSync(keyFile)) {
    mkdirSync(dirname(keyFile), { recursive: true });
    writeFileSync(keyFile, `${randomBytes(32).toString('base64url')}\n`, { mode: 0o600 });
  }
  apiKey = readFileSync(keyFile, 'utf8').trim();
}
if (apiKey === config.bridge.apiKey) {
  console.error('The staging key must be different from BRIDGE_API_KEY (the live key).');
  process.exit(1);
}

const log = {
  info: (...a) => console.log('[staging]', ...a),
  warn: (...a) => console.warn('[staging]', ...a),
  error: (...a) => console.error('[staging]', ...a),
};
const eco = createEconomy({ dbPath, timeZone: config.timeZone, logger: log });
const discordId = config.ownerUserId || 'staging-owner';
const displayName = 'Staging Owner';

const server = createBridgeServer({ eco, apiKey, testOperations: true, memberRoleKeys: async () => ['verified'], log });
server.on('error', (err) => {
  console.error(`Could not start the staging bridge on port ${port}: ${err.message}`);
  process.exit(1);
});
server.listen(port, '127.0.0.1', () => {
  console.log('');
  console.log('Ro-Nation STAGING bridge is running (test data only, not the live economy).');
  console.log(`  Address for Roblox Studio: http://localhost:${port}`);
  console.log(`  Staging key: ${keySource}`);
  console.log(`  Database:    ${dbPath}`);
  console.log('Type "help" for commands. Keep this window open while you test in Studio.');
  console.log('');
  rl.prompt();
});

function balances() {
  const accs = personalAccounts(eco, discordId);
  if (!accs.length) return 'No staging account yet. It is opened by "confirm".';
  const get = (kind) => accs.find((a) => a.kind === kind);
  return `Bank ${formatKGD(get('personal_bank').balance)} · Cash ${formatKGD(get('personal_cash').balance)}`;
}

const commands = {
  help() {
    console.log('  confirm ABCD-EFGH  link the Roblox account that requested this code (like /link confirm in Discord)');
    console.log('  status             show the staging link');
    console.log('  balance            show the staging balances (like /bank balance)');
    console.log('  history            show the last 10 bank and cash transactions (like /bank transactions)');
    console.log('  unlink             remove the staging link at once');
    console.log('  quit               stop the staging bridge');
  },
  confirm(code) {
    // Same order as /link confirm: open the citizen record with the Discord rules, then link.
    const { grantPaid } = ensureCitizen(eco, { userId: discordId, displayName, grantEligible: true });
    const link = confirmLink(eco, { discordId, code });
    console.log(`  Linked to Roblox ${link.roblox_name ?? 'user'} (ID ${link.roblox_user_id}).${grantPaid ? ` Starting balance paid once: ${formatKGD(grantPaid)}.` : ''}`);
    console.log(`  ${balances()}`);
  },
  status() {
    const link = activeLinkByDiscord(eco, discordId);
    console.log(link ? `  Linked to Roblox ${link.roblox_name ?? 'user'} (ID ${link.roblox_user_id}) since ${link.linked_at}.` : '  Not linked.');
  },
  balance() {
    console.log(`  ${balances()}`);
  },
  history() {
    for (const acc of personalAccounts(eco, discordId).filter((a) => ['personal_bank', 'personal_cash'].includes(a.kind))) {
      console.log(`  ${acc.kind === 'personal_bank' ? 'Bank' : 'Cash'}:`);
      const rows = accountTransactions(eco, acc.id, { limit: 10 });
      if (!rows.length) console.log('    (none)');
      for (const t of rows) {
        const incoming = Number(t.to_account) === Number(acc.id);
        console.log(`    #${t.id} ${incoming ? '+' : '-'}${formatKGD(t.amount)} ${t.category}${t.idempotency_key ? ` [${t.idempotency_key}]` : ''}`);
      }
    }
  },
  unlink() {
    staffRemoveLink(eco, { actor: discordId, discordId, reason: 'Staging console: unlink' });
    console.log('  Link removed.');
  },
  quit() {
    shutdown();
  },
};

const rl = createInterface({ input: process.stdin, output: process.stdout, prompt: 'staging> ' });
rl.on('line', (line) => {
  const [cmd, ...args] = line.trim().split(/\s+/);
  if (cmd) {
    const fn = commands[cmd.toLowerCase()];
    try {
      if (fn) fn(args.join(' '));
      else console.log('  Unknown command. Type "help".');
    } catch (err) {
      console.log(`  ${err instanceof UserError ? err.message : `Error: ${err.message}`}`);
    }
  }
  rl.prompt();
});
rl.on('close', () => shutdown());

let stopping = false;
function shutdown() {
  if (stopping) return;
  stopping = true;
  server.close(() => {
    try { eco.close(); } catch { /* already closed */ }
    process.exit(0);
  });
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
