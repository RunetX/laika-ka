# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Лайка** — a 1С:Предприятие 8 extension (v0.5) that integrates 1С "Комплексная автоматизация" with the IIKO restaurant POS system. It syncs master data (products, stores, users) and documents (invoices, orders) bidirectionally.

The system is split into two components:
- **laika-ka** (this repo) — 1С extension, thin client
- **laika-service** — Go web service: licensing, billing, document parsing, state tracking

## Development Environment

This is a **1С extension project** — there are no traditional build scripts or test runners. Development happens in **1С:Конфигуратор** (1C Enterprise IDE):

- Load the extension into Конфигуратор via *Файл → Открыть* (`.cfe`) or connect to a configuration database
- Source files are XML metadata + `.bsl` modules — edit either in Конфигуратор or directly in the file system
- The extension targets 1С:Предприятие **8.3.17+**
- Test by running scenarios in the 1С Enterprise client against a live IIKO server

## Architecture

### What runs where

| Component | Where | What it does |
|-----------|-------|-------------|
| **IIKO** | Customer LAN | Source of truth for products, stores, invoices, orders |
| **1С extension** | Customer LAN | Collects data from IIKO, parses XML locally, writes to 1С catalogs/documents |
| **Go service** | Cloud (`laika.ui99.ru`) | Licensing, billing, state tracking (revision), document parsing (invoices, orders) |

### Key design principle: split by data size

- **Entity sync (large XML, MBs)** — parsed **locally in 1С**. IIKO returns bulk entity data that stays in the LAN. Only a lightweight revision number is sent to the Go service.
- **Document parsing (small XML, KBs)** — parsed **in the Go service**. Invoices and orders are small, and keeping parsing in the service protects the license (1С code is open).

```
Entity sync (catalogs):
  IIKO (LAN) → XML → 1С parses XDTO → writes catalogs → POST /entities/persist {revision}
                                                            ↓
                                                        Go service saves revision

Document processing (invoices, orders):
  IIKO (LAN) → XML → 1С sends raw XML → POST /invoices/parse or /orders/parse
                                            ↓
                                        Go service parses, checks license → returns structured data
                                            ↓
                                        1С writes documents
```

### Module Responsibilities

| Module | Role |
|---|---|
| `like_CoreAPI` | **Single HTTP interface to Go service.** All requests go through here. Handles License-Key header, error codes (401/402/403). |
| `like_Adapter` | Dispatcher: detects config type (КА/УТ), delegates to `like_AdapterКА` or `like_AdapterУТ` |
| `like_AdapterКА` | КА-specific: `WriteEntities(upsertList)`, `CreateMobileOrder(order, settings)` |
| `like_EntitiesAtServer` | Delta sync: requests IIKO with `fromRevision`, parses XDTO locally, writes catalogs via Adapter, persists revision to service |
| `like_InvoicesAtServer` | Invoice sync: gets raw XML from IIKO, sends to service for parsing, writes documents |
| `like_Orders` | Production orders: raw XML → service → Adapter.CreateMobileOrder |
| `like_Common` | Utilities: GZIP decompression, XML attribute injection, translit |
| `like_CommonAtServer` | Low-level: SHA1 for IIKO auth, XDTO↔XML, HTTP to IIKO (`GetIikoObject`, `GetIikoRawXML`) |
| `like_ConnectionAtServer` | Connection catalog queries, entity version initialization |
| `like_HTTPConnector` | REST client library (external, Apache 2.0) |

### Go Service API (laika-service)

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Health check |
| `GET /api/v1/entities/revision` | Current sync revision for license |
| `POST /api/v1/entities/persist` | Save revision + object metadata after local sync |
| `POST /api/v1/invoices/parse-list` | Parse IIKO invoice list XML |
| `POST /api/v1/invoices/parse` | Parse single IIKO invoice XML |
| `POST /api/v1/orders/parse` | Parse IIKO production order XML |
| `GET /api/v1/license/status` | License plan, expiry, features |
| `POST /api/v1/billing/payment` | Create SBP payment (YuKassa) |
| `GET /api/v1/billing/payment/{id}/status` | Poll payment status |
| `POST /api/v1/demo/activate` | Activate 14-day demo (no auth) |
| `POST /webhook/yukassa` | YuKassa payment callback |

### BSL Reserved Words

1С reserves many English keywords. Avoid these as variable/function names in `.bsl`:
- `Execute` → use `DoExecute`
- `Activate` → use `DoActivate`
- `Key` → use `licKey`, `fieldName`, etc.
- `Value`, `Type`, `Name` — also reserved in some contexts

### Entity Sync Data Flow

```
1. 1С calls GET /entities/revision → gets revision from service
2. 1С builds XDTO request with fromRevision, sends to IIKO (LAN)
3. IIKO returns XML with entities delta
4. 1С parses XDTO locally (ExeItems → FillRefs → write catalogs)
5. 1С calls POST /entities/persist {newRevision, objects: []} → service saves state
```

### XDTO Packages

Each IIKO API operation has a corresponding XDTO package under `XDTOPackages/` defining request/response schemas. Namespace pattern: `https://izi.cloud/iiko/reading/...`. Always use `XDTOFactory.Type(namespace, typename)` to create typed objects before populating them.

### Extension Structure Notes

- Data processors (`DataProcessors/like_*`) are the user-facing entry points — each wraps one import/export scenario with a form
- The extension adds commands to existing 1С document list forms rather than replacing them
- `like_connections` catalog holds IIKO server credentials and is the root reference for all registers
- License key stored in `Constants.like_LicenseKey`, manageable via the About form (`like_aboutForm`)

## Infrastructure

- **Server:** Windows 10, Docker Desktop (WSL2)
- **Proxy:** Traefik v3 (file provider), Let's Encrypt
- **Domain:** `laika.ui99.ru` → Go service (port 8080 via Traefik)
- **Admin panel:** port 8081, LAN-only (not through Traefik)
- **Database:** PostgreSQL 16, migrations via goose
