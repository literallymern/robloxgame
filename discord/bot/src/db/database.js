import { DatabaseSync } from 'node:sqlite';
import { readFileSync, mkdirSync, existsSync, readdirSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const SCHEMA_VERSION = 1;

// Future schema changes go here as { version, sql }. They run once, in order, inside a transaction.
// Migrations only add things, so an older database keeps working exactly as before.
const MIGRATIONS = [
  {
    // Roblox integration: Discord <-> Roblox account links, one-time link codes and the
    // operation record of the Roblox bridge (exactly-once processing).
    version: 2,
    sql: `
      CREATE TABLE IF NOT EXISTS account_links (
        id                   INTEGER PRIMARY KEY,
        discord_id           TEXT NOT NULL,
        roblox_user_id       TEXT NOT NULL,
        roblox_name          TEXT,
        status               TEXT NOT NULL CHECK (status IN ('active','removed')),
        linked_at            TEXT NOT NULL,
        linked_day           INTEGER NOT NULL,
        removal_requested_at TEXT,
        removed_at           TEXT,
        removed_by           TEXT,
        removed_reason       TEXT
      );
      CREATE UNIQUE INDEX IF NOT EXISTS ux_links_discord_active ON account_links(discord_id) WHERE status = 'active';
      CREATE UNIQUE INDEX IF NOT EXISTS ux_links_roblox_active ON account_links(roblox_user_id) WHERE status = 'active';

      CREATE TABLE IF NOT EXISTS link_codes (
        id             INTEGER PRIMARY KEY,
        code_hash      TEXT NOT NULL UNIQUE,
        roblox_user_id TEXT NOT NULL,
        roblox_name    TEXT,
        created_at     TEXT NOT NULL,
        expires_at     TEXT NOT NULL,
        used_at        TEXT,
        used_by        TEXT,
        revoked_at     TEXT
      );
      CREATE INDEX IF NOT EXISTS ix_link_codes_roblox ON link_codes(roblox_user_id, created_at);

      CREATE TABLE IF NOT EXISTS bridge_operations (
        operation_id   TEXT PRIMARY KEY,
        kind           TEXT NOT NULL,
        roblox_user_id TEXT,
        discord_id     TEXT,
        payload_hash   TEXT NOT NULL,
        state          TEXT NOT NULL CHECK (state IN ('succeeded','refused','voided')),
        http_status    INTEGER NOT NULL,
        result         TEXT NOT NULL,
        created_at     TEXT NOT NULL,
        econ_day       INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS ix_bridge_ops_user ON bridge_operations(roblox_user_id, created_at);
    `,
  },
];

export function openDatabase(path) {
  if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });
  const db = new DatabaseSync(path);
  db.exec('PRAGMA foreign_keys = ON;');
  db.exec('PRAGMA busy_timeout = 5000;');
  if (path !== ':memory:') {
    db.exec('PRAGMA journal_mode = WAL;');
    db.exec('PRAGMA synchronous = FULL;');
  }

  const hasMeta = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='meta'").get();
  if (!hasMeta) {
    db.exec('BEGIN IMMEDIATE');
    try {
      db.exec(readFileSync(join(here, 'schema.sql'), 'utf8'));
      db.prepare('INSERT INTO meta(key, value) VALUES (?, ?)').run('schema_version', String(SCHEMA_VERSION));
      db.exec('COMMIT');
    } catch (err) {
      db.exec('ROLLBACK');
      throw err;
    }
  }
  runMigrations(db);
  return db;
}

function runMigrations(db) {
  const current = Number(db.prepare("SELECT value FROM meta WHERE key='schema_version'").get().value);
  for (const m of MIGRATIONS.filter((m) => m.version > current).sort((a, b) => a.version - b.version)) {
    db.exec('BEGIN IMMEDIATE');
    try {
      db.exec(m.sql);
      db.prepare("UPDATE meta SET value=? WHERE key='schema_version'").run(String(m.version));
      db.exec('COMMIT');
    } catch (err) {
      db.exec('ROLLBACK');
      throw err;
    }
  }
}

// Runs fn inside one database transaction. Nested calls join the outer transaction.
// If fn throws, every change made inside it is rolled back.
// (Tracked here instead of db.isTransaction, which only exists from Node.js 22.16.)
const openTransactions = new WeakSet();

export function transaction(db, fn) {
  if (openTransactions.has(db)) return fn();
  db.exec('BEGIN IMMEDIATE');
  openTransactions.add(db);
  try {
    const result = fn();
    db.exec('COMMIT');
    return result;
  } catch (err) {
    try { db.exec('ROLLBACK'); } catch { /* SQLite already rolled back */ }
    throw err;
  } finally {
    openTransactions.delete(db);
  }
}

// Writes a consistent copy of the database to backupDir and keeps the newest `keep` copies.
export function backupDatabase(db, backupDir, label, keep = 30) {
  mkdirSync(backupDir, { recursive: true });
  const safeLabel = String(label).replace(/[^a-zA-Z0-9_-]/g, '_');
  const target = join(backupDir, `economy-${safeLabel}.db`);
  if (existsSync(target)) rmSync(target);
  db.prepare('VACUUM INTO ?').run(target);
  const files = readdirSync(backupDir).filter((f) => /^economy-.*\.db$/.test(f)).sort();
  while (files.length > keep) {
    rmSync(join(backupDir, files.shift()));
  }
  return target;
}
