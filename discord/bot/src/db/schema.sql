-- Ro-Nation economy database (SQLite).
-- Money columns are INTEGER minor units (100 = 1.00 KGD). Days are economic day numbers (day 1 = launch day).
-- This file is applied once to a new database. Later changes are added as numbered migrations in database.js.

CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- Kagundi citizens = Discord users that have used the economy.
CREATE TABLE citizens (
  user_id             TEXT PRIMARY KEY,
  display_name        TEXT NOT NULL,
  registered_day      INTEGER NOT NULL,
  registered_at       TEXT NOT NULL,
  last_active_day     INTEGER NOT NULL,
  credit_score        INTEGER NOT NULL DEFAULT 600 CHECK (credit_score BETWEEN 300 AND 850),
  starting_grant_paid INTEGER NOT NULL DEFAULT 0
);

-- Every balance in the economy lives in exactly one account.
-- credit_limit NULL = may go negative without limit (system accounts and loan accounts only).
-- credit_limit 0    = can never go below zero (all normal accounts).
CREATE TABLE accounts (
  id              INTEGER PRIMARY KEY,
  kind            TEXT NOT NULL CHECK (kind IN ('personal_bank','personal_cash','business','treasury','avk','central_bank','rest_of_world','loan','credit_card')),
  owner_type      TEXT NOT NULL CHECK (owner_type IN ('citizen','business','state','external')),
  owner_id        TEXT,
  system_key      TEXT UNIQUE,
  name            TEXT NOT NULL,
  balance         INTEGER NOT NULL DEFAULT 0,
  credit_limit    INTEGER,
  in_money_supply INTEGER NOT NULL CHECK (in_money_supply IN (0,1)),
  frozen          INTEGER NOT NULL DEFAULT 0,
  frozen_reason   TEXT,
  created_day     INTEGER NOT NULL,
  CHECK (credit_limit IS NULL OR balance >= -credit_limit)
);
CREATE UNIQUE INDEX ux_accounts_personal ON accounts(kind, owner_id) WHERE kind IN ('personal_bank','personal_cash','business');
CREATE INDEX ix_accounts_owner ON accounts(owner_type, owner_id);

-- The ledger. Every money movement is one row; nothing changes a balance without a row here.
-- flow: transfer (money stock unchanged), creation (enters the money stock),
--       removal (leaves the money stock), internal (between non-money accounts).
CREATE TABLE transactions (
  id              INTEGER PRIMARY KEY,
  econ_day        INTEGER NOT NULL,
  created_at      TEXT NOT NULL,
  from_account    INTEGER NOT NULL REFERENCES accounts(id),
  to_account      INTEGER NOT NULL REFERENCES accounts(id),
  amount          INTEGER NOT NULL CHECK (amount > 0),
  category        TEXT NOT NULL,
  flow            TEXT NOT NULL CHECK (flow IN ('transfer','creation','removal','internal')),
  memo            TEXT,
  actor_id        TEXT NOT NULL,
  ref_type        TEXT,
  ref_id          TEXT,
  partner         TEXT,
  commodity       TEXT,
  quantity        INTEGER,
  idempotency_key TEXT UNIQUE,
  CHECK (from_account <> to_account)
);
CREATE INDEX ix_tx_day ON transactions(econ_day);
CREATE INDEX ix_tx_from ON transactions(from_account, id);
CREATE INDEX ix_tx_to ON transactions(to_account, id);
CREATE INDEX ix_tx_category ON transactions(category, econ_day);

CREATE TABLE businesses (
  id                   INTEGER PRIMARY KEY,
  name                 TEXT NOT NULL UNIQUE COLLATE NOCASE,
  industry             TEXT NOT NULL,
  primary_output       TEXT,
  owner_id             TEXT NOT NULL REFERENCES citizens(user_id),
  status               TEXT NOT NULL CHECK (status IN ('pending','active','suspended','closed','rejected')),
  account_id           INTEGER REFERENCES accounts(id),
  description          TEXT,
  state_share_bp       INTEGER NOT NULL DEFAULT 0 CHECK (state_share_bp BETWEEN 0 AND 10000),
  applied_day          INTEGER NOT NULL,
  decided_day          INTEGER,
  decided_by           TEXT,
  decision_reason      TEXT,
  closed_day           INTEGER,
  license_unpaid_days  INTEGER NOT NULL DEFAULT 0,
  license_arrears      INTEGER NOT NULL DEFAULT 0,
  suspended_reason     TEXT
);
CREATE INDEX ix_business_owner ON businesses(owner_id);

CREATE TABLE business_managers (
  business_id INTEGER NOT NULL REFERENCES businesses(id),
  user_id     TEXT NOT NULL,
  added_by    TEXT NOT NULL,
  added_day   INTEGER NOT NULL,
  PRIMARY KEY (business_id, user_id)
);

CREATE TABLE inventories (
  business_id INTEGER NOT NULL REFERENCES businesses(id),
  commodity   TEXT NOT NULL,
  quantity    INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  PRIMARY KEY (business_id, commodity)
);

CREATE TABLE inventory_movements (
  id          INTEGER PRIMARY KEY,
  econ_day    INTEGER NOT NULL,
  business_id INTEGER NOT NULL,
  commodity   TEXT NOT NULL,
  delta       INTEGER NOT NULL,
  reason      TEXT NOT NULL,
  ref_type    TEXT,
  ref_id      TEXT,
  created_at  TEXT NOT NULL
);
CREATE INDEX ix_invmov_business ON inventory_movements(business_id, id);

-- Jobs. employer_type 'state' = public-sector job linked to a Discord role key (department).
CREATE TABLE jobs (
  id            INTEGER PRIMARY KEY,
  employer_type TEXT NOT NULL CHECK (employer_type IN ('business','state')),
  business_id   INTEGER REFERENCES businesses(id),
  department    TEXT UNIQUE,
  budget        TEXT,
  title         TEXT NOT NULL,
  daily_wage    INTEGER NOT NULL CHECK (daily_wage > 0),
  slots         INTEGER,
  status        TEXT NOT NULL CHECK (status IN ('open','closed')),
  created_by    TEXT NOT NULL,
  created_day   INTEGER NOT NULL
);

CREATE TABLE employments (
  id         INTEGER PRIMARY KEY,
  job_id     INTEGER NOT NULL REFERENCES jobs(id),
  user_id    TEXT NOT NULL,
  status     TEXT NOT NULL CHECK (status IN ('active','ended')),
  start_day  INTEGER NOT NULL,
  end_day    INTEGER,
  end_reason TEXT
);
CREATE UNIQUE INDEX ux_employment_active ON employments(job_id, user_id) WHERE status = 'active';

CREATE TABLE job_applications (
  id          INTEGER PRIMARY KEY,
  job_id      INTEGER NOT NULL REFERENCES jobs(id),
  user_id     TEXT NOT NULL,
  message     TEXT,
  status      TEXT NOT NULL CHECK (status IN ('pending','accepted','rejected','withdrawn')),
  created_day INTEGER NOT NULL,
  decided_by  TEXT,
  decided_day INTEGER
);
CREATE UNIQUE INDEX ux_application_pending ON job_applications(job_id, user_id) WHERE status = 'pending';

-- One shift per citizen per economic day. Wages are paid by the daily tick.
CREATE TABLE shifts (
  id          INTEGER PRIMARY KEY,
  econ_day    INTEGER NOT NULL,
  user_id     TEXT NOT NULL,
  job_id      INTEGER NOT NULL REFERENCES jobs(id),
  business_id INTEGER REFERENCES businesses(id),
  gross       INTEGER NOT NULL,
  tax         INTEGER NOT NULL DEFAULT 0,
  net         INTEGER NOT NULL DEFAULT 0,
  status      TEXT NOT NULL CHECK (status IN ('pending','paid','unpaid','void')),
  paid_day    INTEGER,
  created_at  TEXT NOT NULL,
  UNIQUE (econ_day, user_id)
);
CREATE INDEX ix_shifts_status ON shifts(status, econ_day);

CREATE TABLE production_log (
  id          INTEGER PRIMARY KEY,
  econ_day    INTEGER NOT NULL,
  business_id INTEGER NOT NULL REFERENCES businesses(id),
  commodity   TEXT NOT NULL,
  shifts      INTEGER NOT NULL,
  quantity    INTEGER NOT NULL,
  cost        INTEGER NOT NULL,
  UNIQUE (econ_day, business_id)
);

-- Prices that apply during a given economic day (computed by the tick of the previous day).
CREATE TABLE market_prices (
  day           INTEGER NOT NULL,
  commodity     TEXT NOT NULL,
  world_eur     REAL NOT NULL,
  price_kgd     INTEGER NOT NULL,   -- world price converted to KGD (minor units per unit)
  landed_kgd    INTEGER NOT NULL,   -- import price incl. transport, before tariff
  PRIMARY KEY (day, commodity)
);

CREATE TABLE market_state (
  day             INTEGER PRIMARY KEY,
  fx              REAL NOT NULL,     -- KGD per EUR
  partner_demand  TEXT NOT NULL,     -- JSON {partner: index}
  cpi             REAL NOT NULL,
  rent_index      REAL NOT NULL
);

CREATE TABLE event_instances (
  id          INTEGER PRIMARY KEY,
  event_key   TEXT NOT NULL,
  name        TEXT NOT NULL,
  start_day   INTEGER NOT NULL,
  end_day     INTEGER NOT NULL,      -- last day the event is active
  status      TEXT NOT NULL CHECK (status IN ('scheduled','active','ended','cancelled')),
  source      TEXT NOT NULL CHECK (source IN ('random','admin')),
  created_by  TEXT NOT NULL,
  reason      TEXT,
  effects     TEXT NOT NULL,         -- JSON copy of the effects at creation time
  created_day INTEGER NOT NULL
);

-- Loans and credit cards share one table ("credit facilities").
CREATE TABLE credit_facilities (
  id                  INTEGER PRIMARY KEY,
  type                TEXT NOT NULL CHECK (type IN ('loan','card')),
  borrower_type       TEXT NOT NULL CHECK (borrower_type IN ('citizen','business')),
  borrower_id         TEXT NOT NULL,
  applicant_id        TEXT NOT NULL,
  account_id          INTEGER REFERENCES accounts(id),
  repay_account_id    INTEGER REFERENCES accounts(id),
  principal           INTEGER NOT NULL,     -- loan principal or approved card limit
  annual_rate_bp      INTEGER NOT NULL,
  term_weeks          INTEGER,
  installment         INTEGER,
  status              TEXT NOT NULL CHECK (status IN ('pending','active','repaid','defaulted','rejected','closed')),
  purpose             TEXT,
  applied_day         INTEGER NOT NULL,
  decided_day         INTEGER,
  decided_by          TEXT,
  decision_reason     TEXT,
  start_day           INTEGER,
  consecutive_missed  INTEGER NOT NULL DEFAULT 0,
  total_missed        INTEGER NOT NULL DEFAULT 0,
  closed_day          INTEGER
);
CREATE INDEX ix_credit_borrower ON credit_facilities(borrower_type, borrower_id, status);

CREATE TABLE credit_events (
  id        INTEGER PRIMARY KEY,
  user_id   TEXT NOT NULL,
  econ_day  INTEGER NOT NULL,
  type      TEXT NOT NULL CHECK (type IN ('on_time','missed','default','repaid','eviction','fine_overdue')),
  ref_type  TEXT,
  ref_id    TEXT,
  detail    TEXT
);
CREATE INDEX ix_credit_events_user ON credit_events(user_id, econ_day);

CREATE TABLE insurance_policies (
  id             INTEGER PRIMARY KEY,
  holder_type    TEXT NOT NULL CHECK (holder_type IN ('citizen','business')),
  holder_id      TEXT NOT NULL,
  product        TEXT NOT NULL,
  insured_ref    TEXT,           -- property id / business id / free text (vehicle)
  insured_value  INTEGER NOT NULL,
  coverage_limit INTEGER NOT NULL,
  daily_premium  INTEGER NOT NULL,
  deductible     INTEGER NOT NULL,
  status         TEXT NOT NULL CHECK (status IN ('active','lapsed','cancelled')),
  start_day      INTEGER NOT NULL,
  end_day        INTEGER,
  unpaid_days    INTEGER NOT NULL DEFAULT 0,
  paid_out_total INTEGER NOT NULL DEFAULT 0,
  pay_account_id INTEGER NOT NULL REFERENCES accounts(id)
);

CREATE TABLE insurance_claims (
  id              INTEGER PRIMARY KEY,
  policy_id       INTEGER NOT NULL REFERENCES insurance_policies(id),
  claimant_id     TEXT NOT NULL,
  incident_ref    TEXT NOT NULL,
  amount_claimed  INTEGER NOT NULL CHECK (amount_claimed > 0),
  description     TEXT NOT NULL,
  evidence        TEXT NOT NULL,
  status          TEXT NOT NULL CHECK (status IN ('submitted','paid','denied')),
  created_day     INTEGER NOT NULL,
  decided_by      TEXT,
  decided_day     INTEGER,
  payout          INTEGER,
  decision_reason TEXT,
  UNIQUE (policy_id, incident_ref)
);

CREATE TABLE properties (
  id              INTEGER PRIMARY KEY,
  name            TEXT NOT NULL UNIQUE COLLATE NOCASE,
  city            TEXT NOT NULL,
  type            TEXT NOT NULL,
  value           INTEGER NOT NULL CHECK (value > 0),
  daily_rent      INTEGER NOT NULL CHECK (daily_rent >= 0),
  owner_type      TEXT NOT NULL CHECK (owner_type IN ('state','citizen','business')),
  owner_id        TEXT,
  for_sale        INTEGER NOT NULL DEFAULT 0,
  sale_price      INTEGER,
  for_rent        INTEGER NOT NULL DEFAULT 1,
  tenant_type     TEXT CHECK (tenant_type IN ('citizen','business')),
  tenant_id       TEXT,
  lease_start_day INTEGER,
  rent_missed     INTEGER NOT NULL DEFAULT 0,
  tax_arrears     INTEGER NOT NULL DEFAULT 0,
  created_by      TEXT NOT NULL,
  created_day     INTEGER NOT NULL
);

CREATE TABLE fines (
  id          INTEGER PRIMARY KEY,
  user_id     TEXT NOT NULL,
  amount      INTEGER NOT NULL CHECK (amount > 0),
  reason      TEXT NOT NULL,
  case_ref    TEXT,
  issued_by   TEXT NOT NULL,
  authority   TEXT NOT NULL,
  issued_day  INTEGER NOT NULL,
  due_day     INTEGER NOT NULL,
  status      TEXT NOT NULL CHECK (status IN ('unpaid','overdue','paid','cancelled')),
  paid_day    INTEGER,
  cancelled_by TEXT,
  cancel_reason TEXT
);

CREATE TABLE invoices (
  id                 INTEGER PRIMARY KEY,
  issuer_business_id INTEGER NOT NULL REFERENCES businesses(id),
  payer_type         TEXT NOT NULL CHECK (payer_type IN ('citizen','business','state')),
  payer_id           TEXT,
  amount             INTEGER NOT NULL CHECK (amount > 0),
  memo               TEXT NOT NULL,
  commodity          TEXT,
  quantity           INTEGER,
  status             TEXT NOT NULL CHECK (status IN ('open','paid','cancelled','expired')),
  created_by         TEXT NOT NULL,
  created_day        INTEGER NOT NULL,
  due_day            INTEGER NOT NULL,
  paid_day           INTEGER,
  paid_by            TEXT
);

CREATE TABLE spending_requests (
  id           INTEGER PRIMARY KEY,
  requested_by TEXT NOT NULL,
  payee_account INTEGER NOT NULL REFERENCES accounts(id),
  amount       INTEGER NOT NULL CHECK (amount > 0),
  category     TEXT NOT NULL,
  reason       TEXT NOT NULL,
  invoice_id   INTEGER REFERENCES invoices(id),
  status       TEXT NOT NULL CHECK (status IN ('pending','executed','rejected','failed')),
  created_day  INTEGER NOT NULL,
  decided_by   TEXT,
  decided_day  INTEGER,
  note         TEXT
);

CREATE TABLE budget_lines (
  period    INTEGER NOT NULL,
  category  TEXT NOT NULL,
  allocated INTEGER NOT NULL CHECK (allocated >= 0),
  set_by    TEXT NOT NULL,
  set_day   INTEGER NOT NULL,
  PRIMARY KEY (period, category)
);

CREATE TABLE policy (
  key         TEXT PRIMARY KEY,
  value       TEXT NOT NULL,   -- JSON
  updated_day INTEGER NOT NULL,
  updated_by  TEXT NOT NULL
);

-- One row per processed economic day. A day is only marked completed inside the same
-- database transaction that applied all of its effects, so it can never run twice.
CREATE TABLE econ_days (
  day           INTEGER PRIMARY KEY,
  calendar_date TEXT NOT NULL,
  status        TEXT NOT NULL CHECK (status IN ('completed')),
  completed_at  TEXT NOT NULL,
  late          INTEGER NOT NULL DEFAULT 0,
  duration_ms   INTEGER
);

CREATE TABLE tick_failures (
  id        INTEGER PRIMARY KEY,
  day       INTEGER NOT NULL,
  failed_at TEXT NOT NULL,
  error     TEXT NOT NULL
);

CREATE TABLE daily_snapshots (
  day  INTEGER PRIMARY KEY,
  data TEXT NOT NULL
);

CREATE TABLE reports (
  day              INTEGER PRIMARY KEY,
  generated_at     TEXT NOT NULL,
  content          TEXT NOT NULL,     -- JSON report object
  suppressed       INTEGER NOT NULL DEFAULT 0,
  published_at     TEXT,
  channel_id       TEXT,
  message_id       TEXT,
  publish_attempts INTEGER NOT NULL DEFAULT 0,
  last_error       TEXT
);

CREATE TABLE audit_log (
  id         INTEGER PRIMARY KEY,
  created_at TEXT NOT NULL,
  econ_day   INTEGER NOT NULL,
  actor_id   TEXT NOT NULL,
  action     TEXT NOT NULL,
  target     TEXT,
  amount     INTEGER,
  old_value  TEXT,
  new_value  TEXT,
  reason     TEXT,
  result     TEXT,
  mirrored   INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX ix_audit_actor ON audit_log(actor_id, id);

-- Discord-side records (verification, tickets).
CREATE TABLE member_verifications (
  user_id      TEXT PRIMARY KEY,
  verified_at  TEXT NOT NULL,
  graduated_at TEXT
);

CREATE TABLE tickets (
  channel_id TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL,
  type       TEXT NOT NULL,
  status     TEXT NOT NULL CHECK (status IN ('open','closed','deleted')),
  created_at TEXT NOT NULL,
  closed_at  TEXT,
  closed_by  TEXT
);
CREATE INDEX ix_tickets_user ON tickets(user_id, type, status);

-- Roles removed by /mod restrict, restored by /mod unrestrict.
CREATE TABLE restrictions (
  user_id     TEXT PRIMARY KEY,
  roles       TEXT NOT NULL,      -- JSON array of role keys
  reason      TEXT NOT NULL,
  restricted_by TEXT NOT NULL,
  created_at  TEXT NOT NULL
);
