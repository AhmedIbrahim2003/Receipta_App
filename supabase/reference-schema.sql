-- =====================================================================
-- Digital Receipt System — Supabase / Postgres Schema
-- =====================================================================
-- Covers: merchants, stores, POS terminals, ESP32 devices, cashiers,
-- customers, receipts, receipt line items, and the unified
-- "claim token" table that powers both the QR and NFC assignment flows.
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------
create type receipt_status  as enum ('unassigned', 'assigned', 'expired', 'void');
create type claim_type      as enum ('qr', 'nfc');
create type claim_status    as enum ('pending', 'consumed', 'expired', 'cancelled');
create type device_status   as enum ('active', 'offline', 'maintenance');

-- ---------------------------------------------------------------------
-- Merchants / Stores / Terminals / Devices / Cashiers
-- ---------------------------------------------------------------------
create table merchants (
    id              uuid primary key default gen_random_uuid(),
    name            text not null,
    contact_email   text,
    created_at      timestamptz not null default now()
);

create table stores (
    id              uuid primary key default gen_random_uuid(),
    merchant_id     uuid not null references merchants(id) on delete cascade,
    name            text not null,
    address         text,
    timezone        text default 'UTC',
    created_at      timestamptz not null default now()
);

create table pos_terminals (
    id              uuid primary key default gen_random_uuid(),
    store_id        uuid not null references stores(id) on delete cascade,
    label           text not null,               -- e.g. "Register 1"
    created_at      timestamptz not null default now()
);

-- One ESP32 unit per physical terminal
create table devices (
    id                  uuid primary key default gen_random_uuid(),
    terminal_id         uuid references pos_terminals(id) on delete set null,
    device_serial       text not null unique,     -- hardware chip id / MAC
    firmware_version    text,
    status              device_status not null default 'active',
    last_seen_at        timestamptz,
    created_at          timestamptz not null default now()
);

create table cashiers (
    id              uuid primary key default gen_random_uuid(),
    store_id        uuid not null references stores(id) on delete cascade,
    full_name       text not null,
    pin_code_hash   text,                          -- if cashiers log into the agent with a PIN
    created_at      timestamptz not null default now()
);

-- Per-terminal credentials so the Cashier Agent / ESP32 can authenticate
-- to the backend without customer-style auth.
create table terminal_api_keys (
    id              uuid primary key default gen_random_uuid(),
    terminal_id     uuid not null references pos_terminals(id) on delete cascade,
    key_hash        text not null,                 -- store a hash, never the raw key
    label           text,
    revoked_at      timestamptz,
    created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Customers (1:1 with Supabase auth.users)
-- ---------------------------------------------------------------------
create table customers (
    id              uuid primary key references auth.users(id) on delete cascade,
    full_name       text,
    email           text,
    phone           text,
    created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Receipts
-- ---------------------------------------------------------------------
create table receipts (
    id                  uuid primary key default gen_random_uuid(),
    store_id            uuid not null references stores(id),
    terminal_id         uuid references pos_terminals(id),
    cashier_id          uuid references cashiers(id),
    device_id           uuid references devices(id),
    receipt_number      text,                       -- human-readable / per-store sequence
    total_amount        numeric(12,2) not null,
    currency            text not null default 'USD',
    file_path           text,                       -- Cloudflare R2 object key
    status              receipt_status not null default 'unassigned',
    customer_id         uuid references customers(id),
    assignment_method   claim_type,                 -- 'qr' | 'nfc', set on assignment
    assigned_at         timestamptz,
    metadata            jsonb not null default '{}'::jsonb,   -- raw POS payload snapshot
    created_at          timestamptz not null default now()
);

create table receipt_items (
    id              uuid primary key default gen_random_uuid(),
    receipt_id      uuid not null references receipts(id) on delete cascade,
    sku             text,
    name            text not null,
    quantity        numeric(10,2) not null default 1,
    unit_price      numeric(12,2) not null,
    total_price     numeric(12,2) not null
);

-- ---------------------------------------------------------------------
-- Claim tokens — the single mechanism behind BOTH the QR and NFC flows.
--
--   QR flow:  created WITH receipt_id set, customer_id NULL.
--             App scan fills in customer_id and consumes it.
--
--   NFC flow: created WITH customer_id set, receipt_id NULL.
--             Agent's post-tap request fills in receipt_id and consumes it.
-- ---------------------------------------------------------------------
create table receipt_claim_tokens (
    id              uuid primary key default gen_random_uuid(),
    code            text not null unique,          -- short random string shown in QR / sent over NFC
    type            claim_type not null,
    receipt_id      uuid references receipts(id),
    customer_id     uuid references customers(id),
    device_id       uuid references devices(id),   -- which ESP32 is involved
    status          claim_status not null default 'pending',
    expires_at      timestamptz not null,
    consumed_at     timestamptz,
    created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------
create index idx_receipts_customer_id       on receipts (customer_id);
create index idx_receipts_status            on receipts (status);
create index idx_receipts_store_id          on receipts (store_id);
create index idx_claim_tokens_code          on receipt_claim_tokens (code);
create index idx_claim_tokens_status_exp    on receipt_claim_tokens (status, expires_at);
create index idx_claim_tokens_customer_id   on receipt_claim_tokens (customer_id);

-- ---------------------------------------------------------------------
-- Row Level Security
--
-- The .NET backend talks to Supabase with the service_role key for all
-- writes (receipt creation, assignment, token issuing) — that key
-- bypasses RLS entirely. RLS below only matters if/when the Flutter app
-- reads directly from Supabase (e.g. via the anon/authenticated key for
-- realtime updates or a "my receipts" list).
-- ---------------------------------------------------------------------
alter table customers               enable row level security;
alter table receipts                enable row level security;
alter table receipt_items           enable row level security;
alter table receipt_claim_tokens    enable row level security;

create policy "customers read own profile"
    on customers for select
    using (auth.uid() = id);

create policy "customers read own receipts"
    on receipts for select
    using (auth.uid() = customer_id);

create policy "customers read own receipt items"
    on receipt_items for select
    using (
        exists (
            select 1 from receipts r
            where r.id = receipt_items.receipt_id
              and r.customer_id = auth.uid()
        )
    );

create policy "customers read own claim tokens"
    on receipt_claim_tokens for select
    using (auth.uid() = customer_id);

-- No insert/update/delete policies for the authenticated/anon role:
-- all mutations go through the .NET backend using the service_role key,
-- so those actions stay validated, atomic, and auditable server-side.

-- ---------------------------------------------------------------------
-- Optional: housekeeping function to expire stale tokens.
-- Call this on a schedule (pg_cron, or a periodic job in your .NET API).
-- ---------------------------------------------------------------------
create or replace function expire_stale_claim_tokens()
returns void
language sql
as $$
    update receipt_claim_tokens
    set status = 'expired'
    where status = 'pending'
      and expires_at < now();
$$;
