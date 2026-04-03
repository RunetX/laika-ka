# План реализации Лайка 2.0

## Архитектурная цель

IIKO-сервер работает в локальной сети клиента — Go-сервис не имеет к нему прямого доступа.
Разделение по размеру данных:

- **Справочники (большой XML, МБ)** — парсятся **локально в 1С** (LAN). На сервис отправляется только revision.
- **Документы (маленький XML, КБ)** — парсятся **в Go-сервисе** (облако). Защита лицензии.

```text
Справочники (entity sync):
  IIKO (LAN) → XML → 1С парсит XDTO → пишет каталоги → POST /entities/persist {revision}

Документы (invoices, orders):
  IIKO (LAN) → XML → 1С → POST /invoices/parse {rawXml} → Go парсит → 1С пишет документы
```

**Что хранит сервис в БД** (нельзя подделать со стороны 1С):

- лицензии и фича-флаги
- состояние синхронизации: `entity_versions`, `object_matching`
- платежи

**Адаптерная модель** для разных конфигураций 1С сохраняется: один адаптерный BSL-модуль
на конфигурацию.

---

## Фаза 1 — Скелет Go-сервиса ✅

- [x] Go-модуль, структура директорий, chi-роутер, `/health`
- [x] PostgreSQL + goose-миграции, начальная схема `customers`, `licenses`
- [x] Docker Compose: dev + prod, Traefik (file provider), `laika.ui99.ru`

**Критерий:** `GET https://laika.ui99.ru/health` → `{"status":"ok"}` ✅

---

## Фаза 2 — Перенос бизнес-логики в сервис ✅

### Синхронизация справочников (локальный парсинг)

Справочники (products, stores, users, departments и др.) — большой XML (мегабайты).
Парсится **локально в 1С** через XDTO (IIKO в LAN — быстро).
На сервис отправляется только revision для трекинга состояния.

- [x] Миграция: `entity_versions(license_id, revision)`, `object_matching(license_id, iiko_uuid, catalog_name, revision)`
- [x] `GET /api/v1/entities/revision` — текущая revision для лицензии (передаётся в IIKO-запрос)
- [x] `POST /api/v1/entities/persist` — принимает `{ newRevision, objects[] }`, сохраняет состояние
- [x] `like_EntitiesAtServer.Update` — IIKO → XDTO → ExeItems (локально) → PersistEntities (на сервис)
- [x] `like_CoreAPI.PersistEntities` — отправляет revision на сервис после локальной записи

### Документы и накладные (облачный парсинг)

Документы (invoices, orders) — маленький XML (килобайты). Парсится **в Go-сервисе**.
Это защищает лицензию: без валидного ключа документы не обрабатываются.

- [x] `POST /api/v1/invoices/parse-list` — список накладных из rawXML
- [x] `POST /api/v1/invoices/parse` — одна накладная из rawXML
- [x] `POST /api/v1/orders/parse` — производственный заказ из rawXML

### 1С-сторона

- [x] Общий модуль `like_CoreAPI`: единственное место HTTP-вызовов к сервису, заголовок `License-Key`
- [x] Константа `like_LicenseKey` для хранения ключа лицензии + ввод через форму "О программе"
- [x] `like_AdapterКА.WriteEntities` — запись объектов в справочники КА
- [x] `like_InvoicesAtServer.GetInvoices` — rawXML → CoreAPI.ParseInvoiceList
- [x] `like_Orders.Order1CFromIiko` — rawXML → CoreAPI.ParseOrder → AdapterКА
- [x] `like_AdapterКА.CreateMobileOrder` — создание мобильного заказа из структуры сервиса

**Критерий:** справочники синхронизируются локально; документы через сервис; без `License-Key` — ничего не работает. ✅

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

## Фаза 4 — Биллинг и СБП ✅

- [x] Миграция: `payments(id, license_id, amount, period, status, yukassa_id, created_at, paid_at)`
- [x] Банк-партнёр: ЮКасса (СБП QR, `internal/billing/yukassa.go`)
- [x] `POST /api/v1/billing/payment` → QR-код СБП + `payment_id`
- [x] `POST /webhook/yukassa` — вебхук от ЮКассы → продление лицензии (с проверкой IP)
- [x] `GET /api/v1/billing/payment/{id}/status` — опрос статуса
- [x] В 1С: обработка `like_billing` — форма "Продлить подписку", QR, поллинг статуса
- [x] `like_CoreAPI.CreatePayment` / `GetPaymentStatus` — HTTP-клиент к биллингу

**Критерий:** клиент продлевает подписку через СБП без участия администратора. ✅

---

## Фаза 5 — Демо-режим

- [x] План `demo`: 14 дней, `{ max_documents: 100, max_connections: 1 }` — константы в `license/service.go`
- [x] Миграция `004_demo.sql`: `doc_count` в таблице `licenses`
- [x] `POST /api/v1/demo/activate` — создаёт customer + demo-лицензию, возвращает ключ
- [x] `license.ActivateDemo()` — проверка дубликата по email, 14 дней, features с лимитами
- [x] `license.CheckDemoLimit()` / `IncrementDocCount()` — счётчик документов в invoice/order хэндлерах
- [x] `GET /api/v1/license/status` — возвращает `docCount` для UI
- [x] В 1С: `like_CoreAPI.ActivateDemo()` + `ExecuteNoAuth()` — HTTP-клиент без License-Key
- [x] В 1С: обработка `like_demo` — форма активации (email + название → ключ → сохранение в константу)
- [x] В 1С: баннер "демо (документов: X / 100)" в форме биллинга
- [x] В 1С: обработка 403 "demo document limit" с понятным сообщением

**Критерий:** новый клиент начинает работать без звонка; по истечении — предложение купить.

---

## Фаза 6 — Поддержка других конфигураций 1С ✅

- [x] Зафиксирован интерфейс адаптера: `WriteEntities(upsertList)`, `CreateMobileOrder(order, settings)`
- [x] `like_AdapterКА` — без изменений (уже был с правильным именем)
- [x] `like_Adapter` — диспетчер: определяет тип конфигурации (`ConfigurationType()`) и делегирует
- [x] Все вызывающие модули переведены с `like_AdapterКА` → `like_Adapter`
- [x] `like_AdapterУТ` — заглушка с Raise (реализация по запросу)
- [x] Определение конфигурации: по `Metadata.Name` + fallback по характерным документам

**Критерий:** новая конфигурация = один адаптерный модуль, сервис не меняется. ✅

---

---

## Фаза 7 — Тестирование и исправления (2026-04-03) ✅

Развёрнуто на `laika.ui99.ru`, проведено E2E-тестирование с реальным IIKO.

### Исправления по результатам тестирования:
- [x] `Execute`, `Activate`, `Key` — переименованы (зарезервированные слова BSL)
- [x] `QRCodeGenerator` — убрана прямая зависимость (платформа < 8.3.22)
- [x] `formatDate` в админке — принимает и `time.Time`, и `*time.Time`
- [x] `SafeGet` — безопасное чтение из Map и Structure (1С ReadJSON возвращает разные типы)
- [x] Таймауты сервера увеличены до 5 минут (большие XML от IIKO)
- [x] `flexInt64` — Go принимает revision и как число, и как строку (1С сериализует числа в строки)
- [x] `documentID` — регистрозависимый XML-тег исправлен (documentId → documentID)
- [x] `documentSummary` — тип исправлен с float64 на string (текстовое описание)
- [x] `eid` — исправлен парсинг XML-атрибута (`xml:"eid"` → `xml:"eid,attr"`)
- [x] `code` — добавлено в ParsedInvoiceItem

### Архитектурное изменение: локальный парсинг справочников
- [x] `POST /entities/sync` (облачный парсинг XML) → `POST /entities/persist` (только revision)
- [x] 1С парсит XML от IIKO локально через XDTO (в LAN — мгновенно)
- [x] На сервис отправляется только revision для трекинга состояния
- [x] Документы (invoices, orders) по-прежнему парсятся в облаке — маленький XML

### Новая функциональность:
- [x] Форма "О программе" — ввод ключа лицензии + проверка статуса
- [x] Админ-панель — создание лицензий через веб-интерфейс
- [x] Интеграционные тесты (18 автотестов, разделы 1-4)
- [x] Форма деталей накладной переведена с XDTO на JSON-ответ сервиса

**Критерий:** E2E работает: sync справочников, список накладных, детали накладной. ✅

---

## Следующие шаги

## Фаза 8 — Рефакторинг laika-ka

### A. Устранение заимствованных форм (3 документа)

ПриобретениеТоваровУслуг уже переведён на программное создание UI.
Нужно сделать то же для оставшихся двух + удалить дублирующую обработку.

- [x] ПриобретениеТоваровУслуг — программная кнопка + форма загрузки накладных
- [ ] A1. РеализацияТоваровУслуг — добавить в `МодификацияКонфигурацииПереопределяемый`, перевести `Send2IIKO`, удалить заимствованную форму
- [ ] A2. ОтгрузкаТоваровСХранения — аналогично
- [ ] A3. Удалить `like_invoicesDownload/Forms/like_InvoicesForm` — полностью дублирует `FetchInvoicesList()`

### B. Исправление сломанных форм (XDTO→JSON)

Сервис теперь возвращает JSON, но некоторые формы всё ещё читают XDTO-свойства.

- [x] B1. `like_outgoingInvoiceForm` — перевести с `d.items.i` / `d.__content` на `SafeGet()`
- [x] B2. `like_OrdersForm.GetInvoices()` — убрать проверки `Type("XDTOList")`, читать JSON-массив

### C. Консолидация серверной логики

- [ ] C1. Три `GetRequisites` → одна параметризованная `GetDocumentRequisites(documentsList, docMeta, requisites)` *(отложено — требует тестирования с IIKO)*
- [ ] C2. Три XDTO-билдера → общий `BuildInvoiceXDTO()` с параметрами маппинга *(отложено — требует тестирования с IIKO)*
- [x] C3. `GetIikoObject`/`GetIikoRawXML` → общий `ExecuteIikoHTTPRequest()`
- [x] C4. `DoExecute`/`ExecuteNoAuth` → общий `DoHTTPRequest()`

### D. Безопасность запросов (.Next() без проверки)

- [x] D1. `like_ConnectionAtServer.GetActiveConnecton()` — `If Not .Next() Return Undefined`
- [x] D2. `like_EntitiesAtServer.GetEntitiesVersion()` — возвращает -1
- [x] D3. `like_InvoicesAtServer.FindByCodeAndConnection()` — возвращает ""
- [x] D4. `like_Orders.OrdersSettings()` — возвращает Undefined

### E. Удаление мёртвого кода

- [x] E1. `like_EntitiesAtServer`: удалены `GetXMLEntitiesUpdate()`, `FindByIDAndConnection()` (содержала баг), `GetExeEntityStructure()`
- [x] E2. `like_Orders`: удалены `MobileOrder()`, `OrderDataFromPackage()`, `OrderItemModel()` (-116 строк)
- [x] E3. `like_Common.InsertAttribute()` удалена (-20 строк)
- [x] E4. Дубликат `GetTableWithColumns()` заменён на `like_TypesAndDescriptionsAtServer`

### F. Унификация форм справочников

11 идентичных форм списка (22 строки каждая: фильтр по подключению + условное оформление).

- [ ] F1. Выделить `like_CommonAtServer.SetupCatalogListForm(Form)`, заменить 11 форм на однострочный вызов

### G. Тесты (Tester)

- [ ] G1. Unit-тесты чистых функций: `Translit()`, `iikoDateTimeTo1C()`, `SafeGet()`, `MapToJSON()`, `StrValue()`
- [ ] G2. Серверные тесты: `FetchInvoicesList()`, `WriteEntity()`, `GetDocumentRequisites()`
- [ ] G3. Регрессия: unsafe `.Next()`, XDTO/JSON в outgoingInvoiceForm
- [ ] G4. E2E: синхронизация → загрузка накладных → отправка в IIKO

### H. Стиль кода

- [ ] H1. Именование: `getIIKOHeaders` → `GetIIKOHeaders` (PascalCase), убрать смешение ru/en
- [ ] H2. Опечатка `entitites` — исправить в коде (регистр `like_entititesVersions` в метаданных не переименовать)

---

### Приоритет выполнения

1. **B** (сломанные формы) — баги, блокируют работу
2. **D** (unsafe Next) — потенциальные падения
3. **E** (мёртвый код) — простая чистка
4. **C** (консолидация) — снижает сложность поддержки
5. **A** (заимствованные формы) — архитектурная задача
6. **F** (унификация справочников) — простой рефакторинг
7. **G** (тесты) — на каждом этапе к изменённому коду
8. **H** (стиль) — в последнюю очередь

---

## Следующие шаги (после рефакторинга)

- [ ] Тестирование отправки накладных из 1С в IIKO (блокер: лицензия IIKO)
- [ ] Тестирование заказов на производство
- [ ] Подключение YuKassa
- [ ] Реализация `like_AdapterУТ` по первому запросу клиента
