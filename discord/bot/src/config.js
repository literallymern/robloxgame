// Configuration from environment variables (.env file next to package.json).
// Secrets such as the bot token are never stored in the repository.
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const envFile = resolve(root, '.env');
if (existsSync(envFile)) process.loadEnvFile(envFile);

const str = (name, fallback = null) => {
  const v = process.env[name];
  return v === undefined || v === '' ? fallback : v.trim();
};
const num = (name, fallback) => {
  const v = str(name);
  if (v === null) return fallback;
  const n = Number(v);
  if (!Number.isFinite(n)) throw new Error(`${name} must be a number`);
  return n;
};
const bool = (name, fallback) => {
  const v = str(name);
  return v === null ? fallback : ['1', 'true', 'yes', 'on'].includes(v.toLowerCase());
};

export const config = {
  root,
  token: str('DISCORD_TOKEN'),
  clientId: str('DISCORD_CLIENT_ID'),
  guildId: str('DISCORD_GUILD_ID'),
  ownerUserId: str('OWNER_USER_ID'),
  timeZone: str('TIMEZONE', 'Europe/Berlin'),
  databasePath: resolve(root, str('DATABASE_PATH', 'data/economy.db')),
  backupDir: resolve(root, str('BACKUP_DIR', 'data/backups')),
  backupKeep: num('BACKUP_KEEP', 30),
  idsFile: resolve(root, str('IDS_FILE', 'data/guild-ids.json')),
  minAccountAgeDays: num('MIN_ACCOUNT_AGE_DAYS', 7),
  grantMinAccountAgeDays: num('GRANT_MIN_ACCOUNT_AGE_DAYS', 14),
  newMemberDays: num('NEW_MEMBER_DAYS', 7),
  catchUpPublishAll: bool('CATCHUP_PUBLISH_ALL', false),
  schedulerIntervalSeconds: num('SCHEDULER_INTERVAL_SECONDS', 30),
  commandCooldownSeconds: num('COMMAND_COOLDOWN_SECONDS', 3),
  // Roblox bridge (off unless BRIDGE_ENABLED=true). See docs/game/05-economy-integration.md in the repository.
  bridge: {
    enabled: bool('BRIDGE_ENABLED', false),
    host: str('BRIDGE_HOST', '127.0.0.1'),
    port: num('BRIDGE_PORT', 8787),
    apiKey: str('BRIDGE_API_KEY'),
    testOperations: bool('BRIDGE_TEST_OPERATIONS', false),
  },
};

export function requireDiscordConfig() {
  const missing = ['DISCORD_TOKEN', 'DISCORD_CLIENT_ID', 'DISCORD_GUILD_ID', 'OWNER_USER_ID'].filter((k) => !str(k));
  if (missing.length) {
    throw new Error(`Missing settings in .env: ${missing.join(', ')}. Copy .env.example to .env and fill it in (see docs/07-setup-guide.md).`);
  }
}
