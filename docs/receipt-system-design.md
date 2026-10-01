# Digital Receipt System — Design Document

## 1. How the pieces fit together

- **ESP32 device** — sits at the register, shows the QR code and handles the NFC tap. Already built, controlled via your JSON command layer.
- **Cashier Agent (.NET, on the POS PC)** — bridges the POS software, the ESP32, and your backend API.
- **Backend API (.NET)** — owns all writes: creating receipts, issuing claim tokens, assigning receipts to customers.
- **Supabase (Postgres + Auth + Realtime)** — the database, plus customer authentication.
- **Cloudflare R2** — stores the actual receipt files (PDF/image); the database only stores the object key/path.
- **Flutter app** — customer-facing. Logs in via Supabase Auth, scans QR / arms NFC, views assigned receipts.

The core idea: **QR and NFC are the same mechanism** — a short-lived, single-use "claim token" — just filled in from opposite ends:

| | Created by | At creation | Filled in later by |
|---|---|---|---|
| **QR** | Backend, when receipt is made | `receipt_id` set, `customer_id` empty | App, on scan → sets `customer_id` |
| **NFC** | Backend, when customer taps "Ready" | `customer_id` set, `receipt_id` empty | Agent, after the tap → sets `receipt_id` |

Either way, once both `receipt_id` and `customer_id` are present and the token is marked `consumed`, the receipt itself is updated to `status = assigned`.

## 2. Architecture

```mermaid
flowchart TB
    subgraph Store["Store / Point of Sale"]
        POS[POS / Cash Register Software]
        Agent["Cashier Agent (.NET local service)"]
        ESP["ESP32 Device (NFC reader + QR display)"]
        POS --> Agent
        Agent <--> ESP
    end

    subgraph Customer["Customer"]
        App["Flutter App"]
    end

    subgraph Cloud["Backend Infrastructure"]
        API[".NET Backend API"]
        DB[("Supabase — Postgres + Auth + Realtime")]
        R2[("Cloudflare R2 — receipt files")]
    end

    Agent -- "REST/JSON: create receipt, assign" --> API
    App -- "REST/JSON: auth, request token, claim QR" --> API
    App -. "NFC tap" .-> ESP
    App -. "scan QR" .-> ESP
    API --> DB
    API --> R2
    App -. "Auth + Realtime (read-only, RLS-scoped)" .-> DB
```

## 3. Entity-relationship diagram

```mermaid
erDiagram
    MERCHANTS ||--o{ STORES : owns
    STORES ||--o{ POS_TERMINALS : has
    STORES ||--o{ CASHIERS : employs
    POS_TERMINALS ||--o{ DEVICES : hosts
    POS_TERMINALS ||--o{ TERMINAL_API_KEYS : authenticates
    STORES ||--o{ RECEIPTS : issues
    POS_TERMINALS ||--o{ RECEIPTS : "generated at"
    CASHIERS ||--o{ RECEIPTS : "processed by"
    DEVICES ||--o{ RECEIPTS : "displayed via"
    CUSTOMERS ||--o{ RECEIPTS : owns
    RECEIPTS ||--o{ RECEIPT_ITEMS : contains
    RECEIPTS ||--o| RECEIPT_CLAIM_TOKENS : "claimed by"
    CUSTOMERS ||--o{ RECEIPT_CLAIM_TOKENS : requests
    DEVICES ||--o{ RECEIPT_CLAIM_TOKENS : reads

    MERCHANTS {
        uuid id PK
        text name
    }
    STORES {
        uuid id PK
        uuid merchant_id FK
        text name
    }
    POS_TERMINALS {
        uuid id PK
        uuid store_id FK
        text label
    }
    DEVICES {
        uuid id PK
        uuid terminal_id FK
        text device_serial
        text status
    }
    CASHIERS {
        uuid id PK
        uuid store_id FK
        text full_name
    }
    CUSTOMERS {
        uuid id PK
        text full_name
        text email
    }
    RECEIPTS {
        uuid id PK
        uuid store_id FK
        uuid customer_id FK
        numeric total_amount
        text status
        text file_path
        text assignment_method
    }
    RECEIPT_ITEMS {
        uuid id PK
        uuid receipt_id FK
        text name
        numeric quantity
        numeric unit_price
    }
    RECEIPT_CLAIM_TOKENS {
        uuid id PK
        text code
        text type
        uuid receipt_id FK
        uuid customer_id FK
        text status
        timestamptz expires_at
    }
```

## 4. QR flow (sequence)

```mermaid
sequenceDiagram
    participant POS as POS Software
    participant Agent as Cashier Agent (.NET)
    participant API as Backend API (.NET)
    participant DB as Supabase
    participant R2 as Cloudflare R2
    participant ESP as ESP32
    participant App as Customer App

    POS->>Agent: Sale finalized (total, items, file)
    Agent->>API: POST /receipts
    API->>R2: Upload receipt file
    R2-->>API: file_path
    API->>DB: INSERT receipts (status = unassigned)
    DB-->>API: receipt_id
    API->>DB: INSERT receipt_claim_tokens (type=qr, receipt_id, status=pending)
    DB-->>API: code
    API-->>Agent: { receipt_id, code }
    Agent->>ESP: { "cmd": "show_qr", "code": "..." }
    App->>ESP: Scan QR
    App->>API: POST /claims/{code}/scan (customer auth token)
    API->>DB: Validate token (pending, not expired)
    API->>DB: UPDATE token SET customer_id, status=consumed
    API->>DB: UPDATE receipt SET customer_id, status=assigned, assignment_method=qr
    API-->>App: Receipt details
```

## 5. NFC flow (sequence)

```mermaid
sequenceDiagram
    participant App as Customer App
    participant API as Backend API (.NET)
    participant DB as Supabase
    participant POS as POS Software
    participant Agent as Cashier Agent (.NET)
    participant ESP as ESP32

    App->>API: POST /claims (type=nfc, customer auth token)
    API->>DB: INSERT receipt_claim_tokens (type=nfc, customer_id, status=pending, expires ~60s)
    DB-->>API: code / token
    API-->>App: { token }
    App->>App: Arm NFC (HCE broadcasts token)

    POS->>Agent: Sale finalized (total, items, file)
    Agent->>API: POST /receipts
    API-->>Agent: { receipt_id, status=unassigned }

    App->>ESP: Tap phone → transmits token
    ESP->>Agent: { "event": "nfc_token", "token": "..." }
    Agent->>API: POST /receipts/{receipt_id}/assign { token }
    API->>DB: Validate token (pending, not expired)
    API->>DB: UPDATE token SET receipt_id, status=consumed
    API->>DB: UPDATE receipt SET customer_id (from token), status=assigned, assignment_method=nfc
    API-->>Agent: OK
    Agent->>ESP: { "cmd": "show_success" }
    API-->>App: Push/poll: receipt assigned
```

## 6. State diagrams

**Claim token**
```mermaid
stateDiagram-v2
    [*] --> pending: token created
    pending --> consumed: successfully matched
    pending --> expired: TTL elapsed
    pending --> cancelled: cashier/customer cancels
    consumed --> [*]
    expired --> [*]
    cancelled --> [*]
```

**Receipt**
```mermaid
stateDiagram-v2
    [*] --> unassigned: uploaded by agent
    unassigned --> assigned: claim token consumed
    unassigned --> expired: no claim within TTL
    unassigned --> void: cashier voids sale
    assigned --> void: refund/void after assignment
    expired --> [*]
    void --> [*]
    assigned --> [*]
```

## 7. Suggested backend endpoints

| Endpoint | Caller | Purpose |
|---|---|---|
| `POST /api/receipts` | Agent | Upload receipt file to R2, insert receipt (+ QR claim token if applicable) |
| `POST /api/claims` | App | Request an NFC token before tapping |
| `POST /api/claims/{code}/scan` | App | Claim a receipt by scanning its QR |
| `POST /api/receipts/{id}/assign` | Agent | Complete NFC assignment using the tapped token |
| `GET /api/customers/me/receipts` | App | List the logged-in customer's receipts |
| `GET /api/receipts/{id}/file` | App | Get a short-lived signed R2 URL for the receipt file |

## 8. Security notes

- **Token codes**: generate with a cryptographically random source (not sequential), e.g. 8–10 char base32. Enforce uniqueness at the DB level (already done via `unique` on `code`).
- **TTL**: keep it short — a few minutes for QR (customer has to walk up and scan), ~30–60s for NFC (tap happens almost immediately after arming).
- **Single-use**: the `status` transition `pending → consumed` should happen inside one DB transaction so two near-simultaneous claims on the same code can't both succeed.
- **Service role key**: only the .NET backend holds it. The Flutter app talks to Supabase with the anon/authenticated key, scoped by the RLS policies in `schema.sql`, and never writes receipts or tokens directly.
- **R2 files**: keep the bucket private; the backend issues short-lived signed URLs when the app requests a receipt's file, rather than storing public URLs.
- **Terminal auth**: the Agent (and by extension the ESP32 behind it) authenticates to the backend using the `terminal_api_keys` table — a compromised register shouldn't be able to act as an arbitrary terminal.

## 9. Open questions worth deciding early

- Do you want a hard **cap on unclaimed receipts** (e.g. auto-void after N hours) for storage/cleanup?
- Should a customer be able to **cancel** an armed NFC session from the app (before tapping)?
- Do you need **partial refunds/voids** reflected on an already-assigned receipt, or is void always all-or-nothing?
