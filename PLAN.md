# План реализации Лайка 2.0

## Архитектурная цель

IIKO-сервер работает в локальной сети клиента — Go-сервис не имеет к нему прямого доступа.
Бизнес-логика переносится в Go-сервис для защиты от обхода лицензии (1С-код открыт).

```text
IIKO (LAN)
    ↓  raw XML  (существующий BSL без изменений)
   1С  — только сбор данных и запись готовых объектов
    ↓  POST /api/v1/...  { license_key, raw_xml }
  Go Service  ← проверяет лицензию, парсит XML, бизнес-логика, ведёт состояние sync
    ↓  { objects_to_create[], objects_to_update[], new_revision }
   1С  — записывает готовые объекты в справочники/документы
```

**Что хранит сервис в БД** (нельзя подделать со стороны 1С):

- лицензии и фича-флаги
- состояние синхронизации: `entity_versions`, `object_matching`, `document_matching`
- платежи

**Адаптерная модель** для разных конфигураций 1С сохраняется: один адаптерный BSL-модуль
на конфигурацию, общая бизнес-логика — в сервисе.

---

## Фаза 1 — Скелет Go-сервиса ✅

- [x] Go-модуль, структура директорий, chi-роутер, `/health`
- [x] PostgreSQL + goose-миграции, начальная схема `customers`, `licenses`
- [x] Docker Compose: dev + prod, Traefik (file provider), `laika.ui99.ru`

**Критерий:** `GET https://laika.ui99.ru/health` → `{"status":"ok"}` ✅

---

## Фаза 2 — Перенос бизнес-логики в сервис ✅

1С собирает сырые XML-ответы от IIKO и отправляет их на сервис. Сервис разбирает,
применяет логику, возвращает готовые структуры для записи в 1С.

### Синхронизация справочников

- [x] Миграция: `entity_versions(license_id, revision)`, `object_matching(license_id, iiko_uuid, catalog_name, revision)`
- [x] `GET /api/v1/entities/revision` — текущая revision для лицензии (передаётся в IIKO-запрос)
- [x] `POST /api/v1/entities/sync` — принимает `{ licenseKey, rawXml }`, возвращает `{ newRevision, upsert[] }`
- [x] `internal/iiko/entities.go` — XML-типы и парсер ответа IIKO
- [x] `internal/iiko/sync.go` — бизнес-логика: фильтрация по revision, сохранение в БД, формирование ответа для 1С

### Документы и накладные

- [ ] Миграция: `document_matching(license_id, iiko_doc_id, doc_type, data jsonb)`

### 1С-сторона

- [x] Новый общий модуль `like_CoreAPI`: единственное место HTTP-вызовов к сервису, заголовок `License-Key`
- [x] Константа `like_LicenseKey` для хранения ключа лицензии
- [x] `like_CommonAtServer.GetIikoRawXML` — вариант `GetIIKOObject`, возвращающий сырой XML вместо XDTO
- [x] `like_AdapterКА.WriteEntities` — запись объектов в справочники КА по структурам от сервиса
- [x] `like_EntitiesAtServer.Update` — рефакторинг: IIKO → rawXML → `like_CoreAPI.SyncEntities` → `like_AdapterКА.WriteEntities`
- [x] `POST /api/v1/invoices/parse-list` — список накладных из rawXML
- [x] `POST /api/v1/invoices/parse` — одна накладная из rawXML
- [x] `POST /api/v1/orders/parse` — производственный заказ из rawXML
- [x] `like_InvoicesAtServer.GetInvoices` — рефакторинг: rawXML → CoreAPI.ParseInvoiceList
- [x] `like_DocumentAtServer.GetDocumentRawXML` — новый метод, возвращает сырой XML
- [x] `like_Orders.Order1CFromIiko` — рефакторинг: rawXML → CoreAPI.ParseOrder → AdapterКА
- [x] `like_AdapterКА.CreateMobileOrder` — создание мобильного заказа из структуры сервиса

**Критерий:** все сценарии работают через сервис; без валидного `License-Key` — ничего не работает. ✅

---

## Фаза 3 — Лицензирование ✅

- [x] Middleware: `License-Key` → 401/402/403 в зависимости от статуса
- [x] `GET /api/v1/license/status` — статус + список доступных фич
- [x] В 1С: `like_CoreAPI` обрабатывает 401/402/403 — показывает понятное сообщение
- [x] CLI `cmd/keygen` для выпуска ключей: `-name`, `-email`, `-plan`, `-expires`
- [x] `internal/license/service.go` — Resolve: UUID-валидация → DB lookup → проверка expiry
- [x] `internal/license/context.go` — WithInfo / FromContext
- [x] Все TODO-заглушки `licenseID := req.LicenseKey` удалены из sync/invoices/orders

**Критерий:** без ключа сервис молчит; 1С сообщает пользователю внятно. ✅

---

## Фаза 4 — Биллинг и СБП

- [ ] Миграция: `payments(id, license_id, amount, status, sbp_payment_id, created_at, paid_at)`
- [ ] Выбор банка-партнёра (старт: ЮКасса — поддерживает СБП QR, хорошая документация)
- [ ] `POST /api/v1/billing/payment-intent` → QR-код СБП (base64 PNG) + `payment_id`
- [ ] `POST /webhook/sbp/{payment_id}` — вебхук от банка → продление лицензии
- [ ] `GET /api/v1/billing/payment/{id}/status` — опрос статуса
- [ ] В 1С: форма "Продлить подписку" — показывает QR, опрашивает статус

**Критерий:** клиент продлевает подписку через СБП без участия администратора.

---

## Фаза 5 — Демо-режим

- [ ] План `demo`: 14 дней, `{ max_documents: 100, readonly: false, max_connections: 1 }`
- [ ] `POST /api/v1/demo/activate` — активация без оплаты
- [ ] В 1С: баннер "Демо-режим. Осталось X дней."
- [ ] Ограничения применяются в сервисе (счётчики документов, блокировка по лимиту)

**Критерий:** новый клиент начинает работать без звонка; по истечении — предложение купить.

---

## Фаза 6 — Поддержка других конфигураций 1С

- [ ] Зафиксировать интерфейс адаптера (BSL): `НайтиНоменклатуру`, `НайтиКонтрагента`, `СоздатьДокументПоступление`, …
- [ ] Переименовать текущий код КА → `like_AdapterКА`
- [ ] `like_CoreAPI` выбирает адаптер через `ТипКонфигурации()` автоматически
- [ ] `like_AdapterУТ` — по запросу

**Критерий:** новая конфигурация = один адаптерный модуль, сервис не меняется.

---

## Текущий статус

**Активная фаза:** Фаза 4  
**Следующий шаг:** миграция `payments`, выбор банка-партнёра, `POST /api/v1/billing/payment-intent`
