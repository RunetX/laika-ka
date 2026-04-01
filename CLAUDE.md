# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Лайка** — a 1С:Предприятие 8 extension (v0.4.1.4) that integrates 1С "Комплексная автоматизация" with the IIKO restaurant POS system. It syncs master data (products, stores, users) and documents (invoices, orders) bidirectionally.

The roadmap calls for extracting all IIKO/business logic into a Go web service, leaving 1С as a thin HTTP client. See the architecture plan discussed in the project for details.

## Development Environment

This is a **1С extension project** — there are no traditional build scripts or test runners. Development happens in **1С:Конфигуратор** (1C Enterprise IDE):

- Load the extension into Конфигуратор via *Файл → Открыть* (`.cfe`) or connect to a configuration database
- Source files are XML metadata + `.bsl` modules — edit either in Конфигуратор or directly in the file system
- The extension targets 1С:Предприятие **8.3.12+**
- Test by running scenarios in the 1С Enterprise client against a live IIKO server (no automated test framework exists)

## Architecture

### Module Responsibilities

| Module | Role |
|---|---|
| `like_Common` | Utility functions: GZIP decompression (manual ZIP construction), XML attribute injection, Russian→Latin translit |
| `like_CommonAtServer` | Low-level primitives: SHA1 hashing for IIKO auth, XDTO↔XML conversion, `GetObjectFieldsStructure` (HTTP request descriptor) |
| `like_ConnectionAtServer` | Connection catalog queries, entity version initialization, server info bootstrap |
| `like_EntitiesAtServer` | Delta sync with IIKO: builds `entities_version`-based requests, parses entity response, updates `like_objectMatching` |
| `like_DocumentAtServer` | Fetches IIKO documents by type/date range, returns raw XDTO structures |
| `like_InvoicesAtServer` | Maps IIKO invoices → 1С `ПриобретениеТоваровУслуг` / `РеализацияТоваровУслуг` |
| `like_Orders` | Creates 1С customer orders from IIKO production orders; calls the standard subsystem `МобильноеПриложениеЗаказыКлиентовПереопределяемый` |
| `like_CreatingObjects` | Builds XDTO packages for writing back to IIKO (e.g. creating invoices) |
| `like_HTTPConnector` | Full REST client (GET/POST/PUT/PATCH/DELETE/HEAD/OPTIONS) — external library by Vladimir Bondarevskiy (Apache 2.0) |

### Key Data Flow

```
IIKO Server ←→ like_CommonAtServer (auth, XDTO) ←→ domain modules ←→ 1С documents/catalogs
                       ↑
              like_HTTPConnector (transport)
```

**Authentication:** SHA1 hash of password sent as `X-Resto-*` headers on every IIKO request.

**GZIP responses:** IIKO compresses responses. `like_Common.DecompressGZIP` manually reconstructs a valid ZIP structure from the raw GZIP stream so 1С's `ZipFileReader` can handle it.

**Object matching:** All IIKO UUIDs are resolved to 1С references via `InformationRegister.like_objectMatching` (keyed on connection + UUID + matching type). Documents use `like_documentsMatching`.

**Entity sync:** Incremental — `like_entititesVersions` stores the last known `entities_version` per connection. Requests include `fromRevision` so IIKO returns only the delta.

### XDTO Packages

Each IIKO API operation has a corresponding XDTO package under `XDTOPackages/` defining request/response schemas. Namespace pattern: `https://izi.cloud/iiko/reading/...`. Always use `XDTOFactory.Type(namespace, typename)` to create typed objects before populating them.

### Extension Structure Notes

- Data processors (`DataProcessors/like_*`) are the user-facing entry points — each wraps one import/export scenario with a form
- The extension adds commands to existing 1С document list forms (`Documents/*/Forms/ListForm`) rather than replacing them
- `like_connections` catalog holds IIKO server credentials and is the root reference for all other registers

## Planned Go Web Service

The next major milestone is a Go service that will own all IIKO API calls and business logic. The 1С side will become a thin adapter that:
1. Reads/writes native 1С objects (via a config-specific adapter module)
2. Delegates all IIKO communication to `POST/GET /api/v1/...` on the Go service
3. Displays license/billing status returned by the service

Infrastructure: Docker Compose on the existing home server (Go service + PostgreSQL + Redis + Nginx).
