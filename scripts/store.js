#!/usr/bin/env node
// store.js — Claude Forge instinct store (SQLite via better-sqlite3)
//
// Usage:
//   node store.js init
//   echo '<json>' | node store.js append-event
//   echo '<json>' | node store.js append-failure
//   node store.js query <query-name> [args...]
//   node store.js cleanup [--max-age-days 90] [--max-rows 50000]
//   node store.js aggregate [date]
//   node store.js export [--format json|csv] [--since YYYY-MM-DD]
//   node store.js migrate
//
// Environment:
//   CLAUDE_PROJECT_ROOT — override project root (default: git rev-parse --show-toplevel)

const path = require('path');
const { execSync } = require('child_process');

function projectRoot() {
  if (process.env.CLAUDE_PROJECT_ROOT) return process.env.CLAUDE_PROJECT_ROOT;
  try {
    return execSync('git rev-parse --show-toplevel', { encoding: 'utf8' }).trim();
  } catch {
    return process.cwd();
  }
}

const DB_PATH = path.join(projectRoot(), '.claude', 'store.db');
const MAX_PAYLOAD_BYTES = 10240; // 10KB

let Database;
try {
  Database = require('better-sqlite3');
} catch {
  console.error('better-sqlite3 not installed. Run: cd .claude/scripts && npm install');
  process.exit(2);
}

// ── Schema Migrations ──────────────────────────────────────────

const MIGRATIONS = [
  {
    version: 1,
    description: 'Initial events table',
    up: `
      CREATE TABLE IF NOT EXISTS events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        date TEXT NOT NULL,
        event_type TEXT NOT NULL,
        tool TEXT,
        file TEXT,
        prettier_result TEXT,
        eslint_result TEXT,
        typecheck_result TEXT,
        test_result TEXT,
        error_message TEXT,
        raw_json TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_events_date ON events(date);
      CREATE INDEX IF NOT EXISTS idx_events_file ON events(file);
      CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
    `,
  },
  {
    version: 2,
    description: 'Daily summary + schema_version tables',
    up: `
      CREATE TABLE IF NOT EXISTS daily_summary (
        date TEXT PRIMARY KEY,
        total_events INTEGER DEFAULT 0,
        all_pass INTEGER DEFAULT 0,
        ts_fails INTEGER DEFAULT 0,
        test_fails INTEGER DEFAULT 0,
        eslint_fails INTEGER DEFAULT 0,
        prettier_fails INTEGER DEFAULT 0,
        unique_files INTEGER DEFAULT 0,
        tool_failures INTEGER DEFAULT 0,
        computed_at TEXT
      );
    `,
  },
  {
    version: 3,
    description: 'Error classification fields (Hermes Agent pattern)',
    up: `
      ALTER TABLE events ADD COLUMN error_class TEXT;
      ALTER TABLE events ADD COLUMN retryable INTEGER;
      ALTER TABLE events ADD COLUMN recovery TEXT;
      CREATE INDEX IF NOT EXISTS idx_events_error_class ON events(error_class);
    `,
  },
];

function applyMigrations(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS schema_version (
      version INTEGER PRIMARY KEY,
      description TEXT,
      applied_at TEXT DEFAULT (datetime('now'))
    );
  `);

  const applied = new Set(
    db.prepare('SELECT version FROM schema_version').all().map(r => r.version)
  );

  for (const m of MIGRATIONS) {
    if (applied.has(m.version)) continue;
    db.transaction(() => {
      db.exec(m.up);
      db.prepare('INSERT INTO schema_version (version, description) VALUES (?, ?)').run(m.version, m.description);
    })();
  }
}

// ── DB Open ────────────────────────────────────────────────────

function openDb() {
  const db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');
  db.pragma('synchronous = NORMAL');
  db.pragma('busy_timeout = 5000');
  db.pragma('cache_size = 1000');
  db.pragma('temp_store = memory');
  db.pragma('auto_vacuum = INCREMENTAL');
  applyMigrations(db);
  return db;
}

// ── Helpers ────────────────────────────────────────────────────

function truncatePayload(raw) {
  if (!raw || raw.length <= MAX_PAYLOAD_BYTES) return raw;
  return raw.substring(0, MAX_PAYLOAD_BYTES) + '...[truncated]';
}

function readStdin() {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (c) => { data += c; });
    process.stdin.on('end', () => resolve(data.trim()));
  });
}

// ── Write Commands ─────────────────────────────────────────────

async function appendEvent() {
  const raw = await readStdin();
  if (!raw) return;
  const e = JSON.parse(raw);
  const date = (e.timestamp || '').substring(0, 10);
  const db = openDb();
  db.prepare(
    `INSERT INTO events (timestamp, date, event_type, tool, file,
      prettier_result, eslint_result, typecheck_result, test_result, raw_json)
     VALUES (?, ?, 'tool_result', ?, ?, ?, ?, ?, ?, ?)`
  ).run(
    e.timestamp, date, e.tool || null, e.file || null,
    e.results?.prettier || null, e.results?.eslint || null,
    e.results?.typecheck || null, e.results?.test || null,
    truncatePayload(raw)
  );
  db.close();
}

async function appendFailure() {
  const raw = await readStdin();
  if (!raw) return;
  const e = JSON.parse(raw);
  const date = (e.timestamp || '').substring(0, 10);
  const db = openDb();
  db.prepare(
    `INSERT INTO events (timestamp, date, event_type, tool, error_message,
      error_class, retryable, recovery, raw_json)
     VALUES (?, ?, 'tool_failure', ?, ?, ?, ?, ?, ?)`
  ).run(
    e.timestamp, date, e.tool || null, e.error || null,
    e.error_class || null, e.retryable ? 1 : 0, e.recovery || null,
    truncatePayload(raw)
  );
  db.close();
}

// ── Cleanup ────────────────────────────────────────────────────

function cleanup(args) {
  let maxAgeDays = 90;
  let maxRows = 50000;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--max-age-days' && args[i + 1]) maxAgeDays = Number(args[i + 1]);
    if (args[i] === '--max-rows' && args[i + 1]) maxRows = Number(args[i + 1]);
  }

  const db = openDb();
  const before = db.prepare('SELECT COUNT(*) AS cnt FROM events').get().cnt;

  // 1. Time-based retention
  const timeDeleted = db.prepare(
    `DELETE FROM events WHERE date < date('now', ?)`
  ).run(`-${maxAgeDays} days`).changes;

  // 2. Capacity-based retention (keep newest maxRows)
  const remaining = db.prepare('SELECT COUNT(*) AS cnt FROM events').get().cnt;
  let capDeleted = 0;
  if (remaining > maxRows) {
    capDeleted = db.prepare(
      `DELETE FROM events WHERE id NOT IN (SELECT id FROM events ORDER BY id DESC LIMIT ?)`
    ).run(maxRows).changes;
  }

  // 3. Incremental vacuum
  db.pragma('incremental_vacuum(500)');

  const after = db.prepare('SELECT COUNT(*) AS cnt FROM events').get().cnt;
  db.close();

  console.log(JSON.stringify({
    before, after,
    deleted: { by_age: timeDeleted, by_capacity: capDeleted },
    config: { maxAgeDays, maxRows },
  }, null, 2));
}

// ── Aggregate ──────────────────────────────────────────────────

function aggregate(targetDate) {
  const date = targetDate || new Date().toISOString().substring(0, 10);
  const db = openDb();

  const row = db.prepare(`
    SELECT
      COUNT(*) AS total_events,
      SUM(CASE WHEN prettier_result='pass' AND eslint_result='pass'
               AND typecheck_result='pass' AND test_result='pass' THEN 1 ELSE 0 END) AS all_pass,
      SUM(CASE WHEN typecheck_result='fail' THEN 1 ELSE 0 END) AS ts_fails,
      SUM(CASE WHEN test_result='fail' THEN 1 ELSE 0 END) AS test_fails,
      SUM(CASE WHEN eslint_result='fail' THEN 1 ELSE 0 END) AS eslint_fails,
      SUM(CASE WHEN prettier_result='fail' THEN 1 ELSE 0 END) AS prettier_fails,
      COUNT(DISTINCT file) AS unique_files
    FROM events WHERE date = ? AND event_type = 'tool_result'
  `).get(date);

  const failures = db.prepare(
    `SELECT COUNT(*) AS cnt FROM events WHERE date = ? AND event_type = 'tool_failure'`
  ).get(date);

  db.prepare(`
    INSERT OR REPLACE INTO daily_summary
      (date, total_events, all_pass, ts_fails, test_fails, eslint_fails, prettier_fails, unique_files, tool_failures, computed_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
  `).run(
    date, row.total_events, row.all_pass, row.ts_fails, row.test_fails,
    row.eslint_fails, row.prettier_fails, row.unique_files, failures.cnt
  );

  db.close();
  console.log(JSON.stringify({ date, ...row, tool_failures: failures.cnt }));
}

// ── Export ──────────────────────────────────────────────────────

function exportData(args) {
  let format = 'json';
  let since = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--format' && args[i + 1]) format = args[i + 1];
    if (args[i] === '--since' && args[i + 1]) since = args[i + 1];
  }

  const db = openDb();
  let rows;
  if (since) {
    rows = db.prepare('SELECT * FROM events WHERE date >= ? ORDER BY id').all(since);
  } else {
    rows = db.prepare('SELECT * FROM events ORDER BY id').all();
  }
  db.close();

  if (format === 'csv') {
    if (rows.length === 0) { console.log('(no data)'); return; }
    const cols = Object.keys(rows[0]).filter(k => k !== 'raw_json');
    console.log(cols.join(','));
    for (const r of rows) {
      console.log(cols.map(c => `"${String(r[c] || '').replace(/"/g, '""')}"`).join(','));
    }
  } else {
    console.log(JSON.stringify(rows, null, 2));
  }
}

// ── Queries ────────────────────────────────────────────────────

const QUERIES = {
  'top-failures': (days = 7) => ({
    sql: `
      SELECT file,
             SUM(CASE WHEN typecheck_result='fail' THEN 1 ELSE 0 END) AS typecheck_fails,
             SUM(CASE WHEN test_result='fail' THEN 1 ELSE 0 END) AS test_fails,
             SUM(CASE WHEN eslint_result='fail' THEN 1 ELSE 0 END) AS eslint_fails,
             COUNT(*) AS total_events
      FROM events
      WHERE date >= date('now', ?) AND file IS NOT NULL AND event_type='tool_result'
      GROUP BY file
      HAVING typecheck_fails + test_fails + eslint_fails > 0
      ORDER BY typecheck_fails + test_fails + eslint_fails DESC
      LIMIT 10`,
    params: [`-${Number(days)} days`],
  }),
  'hot-files': (days = 30) => ({
    sql: `
      SELECT file, COUNT(*) AS modifications
      FROM events
      WHERE date >= date('now', ?) AND event_type='tool_result' AND file IS NOT NULL
      GROUP BY file ORDER BY modifications DESC LIMIT 10`,
    params: [`-${Number(days)} days`],
  }),
  'pass-rate': (days = 30) => ({
    sql: `
      SELECT date,
             COUNT(*) AS total,
             SUM(CASE WHEN prettier_result='pass' AND eslint_result='pass'
                      AND typecheck_result='pass' AND test_result='pass'
                 THEN 1 ELSE 0 END) AS all_pass
      FROM events
      WHERE date >= date('now', ?) AND event_type='tool_result'
      GROUP BY date ORDER BY date DESC`,
    params: [`-${Number(days)} days`],
  }),
  'weekly-trend': (weeks = 4) => ({
    sql: `
      SELECT strftime('%Y-W%W', date) AS week,
             COUNT(*) AS total,
             SUM(CASE WHEN prettier_result='pass' AND eslint_result='pass'
                      AND typecheck_result='pass' AND test_result='pass'
                 THEN 1 ELSE 0 END) AS all_pass,
             ROUND(SUM(CASE WHEN prettier_result='pass' AND eslint_result='pass'
                      AND typecheck_result='pass' AND test_result='pass'
                 THEN 1.0 ELSE 0 END) * 100 / COUNT(*), 1) AS pass_pct
      FROM events
      WHERE date >= date('now', ?) AND event_type='tool_result'
      GROUP BY week ORDER BY week`,
    params: [`-${Number(weeks) * 7} days`],
  }),
  'failure-trend': (days = 14) => ({
    sql: `
      SELECT date,
             SUM(CASE WHEN typecheck_result='fail' THEN 1 ELSE 0 END) AS ts_fails,
             SUM(CASE WHEN test_result='fail' THEN 1 ELSE 0 END) AS test_fails,
             SUM(CASE WHEN eslint_result='fail' THEN 1 ELSE 0 END) AS eslint_fails
      FROM events
      WHERE date >= date('now', ?) AND event_type='tool_result'
      GROUP BY date ORDER BY date`,
    params: [`-${Number(days)} days`],
  }),
  'recent-errors': (n = 20) => ({
    sql: `
      SELECT timestamp, tool, error_message
      FROM events WHERE event_type='tool_failure'
      ORDER BY timestamp DESC LIMIT ?`,
    params: [Number(n)],
  }),
  summary: () => ({
    sql: `
      SELECT
        COUNT(*) AS total_events,
        SUM(CASE WHEN event_type='tool_failure' THEN 1 ELSE 0 END) AS failures,
        SUM(CASE WHEN event_type='tool_result' AND prettier_result='pass'
                 AND eslint_result='pass' AND typecheck_result='pass' AND test_result='pass'
                 THEN 1 ELSE 0 END) AS all_pass,
        COUNT(DISTINCT file) AS unique_files,
        COUNT(DISTINCT date) AS days_active,
        MIN(date) AS first_date,
        MAX(date) AS last_date
      FROM events`,
    params: [],
  }),
  today: () => ({
    sql: `
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN prettier_result='pass' AND eslint_result='pass'
                 AND typecheck_result='pass' AND test_result='pass'
            THEN 1 ELSE 0 END) AS all_pass,
        SUM(CASE WHEN typecheck_result='fail' THEN 1 ELSE 0 END) AS ts_fail,
        SUM(CASE WHEN test_result='fail' THEN 1 ELSE 0 END) AS test_fail
      FROM events
      WHERE date = date('now') AND event_type='tool_result'`,
    params: [],
  }),
  'error-classes': (days = 30) => ({
    sql: `
      SELECT error_class, COUNT(*) AS count,
             SUM(CASE WHEN retryable = 1 THEN 1 ELSE 0 END) AS retryable_count
      FROM events
      WHERE date >= date('now', ?) AND event_type='tool_failure' AND error_class IS NOT NULL
      GROUP BY error_class ORDER BY count DESC`,
    params: [`-${Number(days)} days`],
  }),
  'retryable-errors': (days = 7) => ({
    sql: `
      SELECT date, error_class, tool, error_message
      FROM events
      WHERE date >= date('now', ?) AND event_type='tool_failure' AND retryable = 1
      ORDER BY timestamp DESC LIMIT 20`,
    params: [`-${Number(days)} days`],
  }),
  health: () => ({
    sql: `
      SELECT
        (SELECT COUNT(*) FROM events) AS total_rows,
        (SELECT COUNT(*) FROM events WHERE event_type='tool_failure') AS failure_rows,
        (SELECT MIN(date) FROM events) AS oldest_date,
        (SELECT MAX(date) FROM events) AS newest_date,
        (SELECT COUNT(DISTINCT date) FROM events) AS days_active,
        (SELECT MAX(version) FROM schema_version) AS schema_version`,
    params: [],
  }),
};

function runQuery(name, ...args) {
  const q = QUERIES[name];
  if (!q) {
    console.error(`Unknown query: ${name}. Available: ${Object.keys(QUERIES).join(', ')}`);
    process.exit(1);
  }
  const { sql, params } = q(...args);
  const db = openDb();
  const rows = db.prepare(sql).all(...params);
  db.close();
  console.log(JSON.stringify(rows, null, 2));
}

// ── Main ───────────────────────────────────────────────────────

(async () => {
  const [cmd, ...args] = process.argv.slice(2);
  try {
    switch (cmd) {
      case 'init':
        openDb().close();
        console.log('ok');
        break;
      case 'append-event':
        await appendEvent();
        break;
      case 'append-failure':
        await appendFailure();
        break;
      case 'query':
        runQuery(args[0], ...args.slice(1));
        break;
      case 'cleanup':
        cleanup(args);
        break;
      case 'aggregate':
        aggregate(args[0]);
        break;
      case 'export':
        exportData(args);
        break;
      case 'migrate':
        openDb().close();
        console.log('Migrations applied successfully');
        break;
      default:
        console.error('Usage: node store.js <init|append-event|append-failure|query|cleanup|aggregate|export|migrate> [args]');
        process.exit(1);
    }
  } catch (e) {
    console.error(`store.js error: ${e.message}`);
    process.exit(1);
  }
})();
