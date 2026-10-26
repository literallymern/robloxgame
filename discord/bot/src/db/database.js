import { DatabaseSync } from 'node:sqlite';
import { readFileSync, mkdirSync, existsSync, readdirSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const SCHEMA_VERSION = 1;

// Future schema changes go here as { version, sql }. They run once, in order, inside a transaction.
const MIGRATIONS = [];

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
export function transaction(db, fn) {
  if (db.isTransaction) return fn();
  db.exec('BEGIN IMMEDIATE');
  try {
    const result = fn();
    db.exec('COMMIT');
    return result;
  } catch (err) {
    if (db.isTransaction) db.exec('ROLLBACK');
    throw err;
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
