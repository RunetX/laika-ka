# Протокол взаимодействия с сервером IIKO RMS

Составлено на основе анализа кода laika-ka, laika-service и серии статей Infostart.

## Архитектура

```
1C (laika-ka)  ──HTTP──▶  IIKO RMS Server (Tomcat, LAN)
      │                         │
      │                    GZIP XML ответы
      │                         │
      ▼                         ▼
1C получает raw XML  ──JSON──▶  laika-service (Go, cloud)
                                    │
                              парсит XML,
                              возвращает JSON
```

- **Сущности (справочники)** — большие XML, парсятся **локально в 1С** через XDTO
- **Документы (накладные, заказы)** — малые XML, парсятся **в Go-сервисе** (защита лицензии)
- 1С напрямую обращается к серверу IIKO в LAN, Go-сервис IIKO не вызывает

---

## Аутентификация

Все запросы к IIKO используют заголовки (без сессий/cookies):

```
X-Resto-LoginName: [connection.user]
X-Resto-PasswordHash: SHA1([connection.password])   // lowercase hex, без пробелов
X-Resto-BackVersion: [connection.version]            // например "11.0"
X-Resto-AuthType: BACK
X-Resto-ServerEdition: IIKO_RMS | IIKO_CLOUD | IIKO_DEFAULT
Content-Type: text/xml
Accept-Encoding: gzip
```

SHA1 вычисляется в `like_CommonAtServer.GetHash()`:
```bsl
Hash = New DataHashing(HashFunction.SHA1);
Hash.Append(Password);
Return Lower(StrReplace(TrimAll(Hash.HashSum), " ", ""));
```

---

## Эндпоинты IIKO RMS

### 1. GET /resto/get_server_info.jsp

**Назначение:** Инициализация подключения, получение версии и edition сервера.

- Без параметров, без тела запроса
- XDTO namespace: `https://izi.cloud/iiko/reading/serverInfoResponse`, тип `r`
- Ответ: `version`, `serverState`, `edition`
- `serverState` — enum: `NEW`, `WAITING_LICENSE`, `STARTING`, `START_FAILED`, `STARTED_SUCCESSFULLY`, `EMERGENCY`, `STOPPING`, `STOPPED`
- Рабочее состояние сервера: `STARTED_SUCCESSFULLY` (НЕ `RUNNING`!)
- Результат сохраняется в справочнике `like_connections`
- Версия определяет формат ответа `waitEntitiesUpdate` (v < 9 vs v >= 9)

---

### 2. POST /resto/services/update?methodName=waitEntitiesUpdate

**Назначение:** Дельта-синхронизация справочников (products, stores, users, departments и др.)

**Запрос (XDTO):**
- Namespace: `https://izi.cloud/iiko/reading/entitiesUpdate`, тип `args`

```xml
<args>
  <entities_version>2987</entities_version>
  <client_type>BACK</client_type>
  <enable_warnings>false</enable_warnings>
  <request_watchdog_check_results>false</request_watchdog_check_results>
  <use_raw_entities>true</use_raw_entities>
  <fromRevision>2987</fromRevision>
  <timeoutMillis>30000</timeoutMillis>
  <useRawEntities>true</useRawEntities>
</args>
```

**Ответ (GZIP, XDTO):**
- v < 9: namespace `https://izi.cloud/iiko/reading/entitiesUpdateResponse`
- v >= 9: namespace `https://izi.cloud/iiko/reading/entitiesUpdateResponse9`

```xml
<result>
  <success>true</success>
  <entitiesUpdate>
    <revision>3000</revision>
    <items>
      <i>
        <id>uuid-here</id>
        <type>PRODUCT</type>
        <r>
          <revision>10</revision>
          <deleted>false</deleted>
          <code>P001</code>
          <num>123</num>
          <name><customValue>Молоко 3.2%</customValue></name>
          <parent>parent-uuid</parent>
          <accountingCategory>ac-uuid</accountingCategory>
          <mainUnit>unit-uuid</mainUnit>
          <type>GOODS</type>
        </r>
      </i>
      <i>
        <id>dept-uuid</id>
        <type>DEPARTMENT</type>
        <r>
          <revision>5</revision>
          <deleted>false</deleted>
          <code>D01</code>
          <departmentId>D01</departmentId>
          <name>Кухня</name>  <!-- plain text, НЕ customValue! -->
        </r>
      </i>
    </items>
  </entitiesUpdate>
</result>
```

**Типы сущностей:**

| IIKO тип | 1C справочник | isFolder | Особенности |
|----------|--------------|----------|-------------|
| STORE | like_stores | false | code, name, parent |
| ACCOUNT | like_accounts | false | code, name, parent |
| ACCOUNTINGCATEGORY | like_accountingCategories | false | code, name |
| CASHPAYMENTTYPE | like_paymentTypes | false | isCash=true |
| NONCASHPAYMENTTYPE | like_paymentTypes | false | isCash=false |
| CASHREGISTER | like_cashRegisters | false | code=number |
| CONCEPTION | like_conceptions | false | code, name |
| DEPARTMENT | like_departments | false | code=departmentId, name — plain text |
| MEASUREUNIT | like_measureUnits | false | code, name |
| PRODUCT | like_products | false | code, name, parent, accountingCat, mainUnit, type=GOODS |
| PRODUCTGROUP | like_products | true | code, name, parent, accountingCat |
| USER | like_users | false | supplierType, client, employee, supplier, system |

**Формат имени сущности (два варианта!):**
- Большинство типов: `<name><customValue>Текст</customValue></name>`
- DEPARTMENT: `<name>Текст</name>` (plain text)

---

### 3. POST /resto/services/document?methodName=getIncomingDocumentsRecordsByDepartments

**Назначение:** Список накладных за период.

**Запрос (XDTO):**
- Namespace: `https://izi.cloud/iiko/reading/invoices`, тип `args`

```xml
<args>
  <entities_version>2987</entities_version>
  <client_type>BACK</client_type>
  <enable_warnings>false</enable_warnings>
  <request_watchdog_check_results>true</request_watchdog_check_results>
  <use_raw_entities>true</use_raw_entities>
  <dateFrom>2019-01-01T00:00:00.000+03:00</dateFrom>
  <dateTo>2019-12-31T23:59:59.999+03:00</dateTo>
  <docType>INCOMING_INVOICE</docType>
</args>
```

**Формат дат:** ISO 8601 с миллисекундами и часовым поясом.
- Начало: `.000+HH:MM`
- Конец: `.999+HH:MM`
- Хелпер: `like_CommonAtServer.GetIikoDate(date1C, milliseconds)`

**Ответ (GZIP, XML):**

```xml
<result>
  <success>true</success>
  <entitiesUpdate><!-- дельта сущностей, как в update --></entitiesUpdate>
  <returnValue>
    <i>
      <documentID>doc-uuid-1</documentID>
      <date>2025-03-15</date>
      <number>INV-001</number>
      <type>INCOMING_INVOICE</type>
      <processed>true</processed>
      <comment>текст комментария</comment>
      <documentSummary>Наименования товаров</documentSummary>  <!-- ТЕКСТ, не число! -->
      <counteragent>supplier-uuid</counteragent>
      <conception>conception-uuid</conception>
      <storeFrom>store-uuid</storeFrom>
      <amount>15000.50</amount>
      <sumWithoutNds>12500.00</sumWithoutNds>
      <sum>15000.00</sum>
      <invoiceIncomingNumber>EXT-INV-001</invoiceIncomingNumber>
      <assignedStores>
        <i>store-1-uuid</i>
        <i>store-2-uuid</i>
      </assignedStores>
    </i>
  </returnValue>
</result>
```

**docType:** `INCOMING_INVOICE` | `OUTGOING_INVOICE`

---

### 4. POST /resto/services/document?methodName=getAbstractDocument

**Назначение:** Получение одного документа (накладная или заказ) по UUID.

**Запрос (XDTO):**
- Namespace: `https://izi.cloud/iiko/reading/document`, тип `args`

```xml
<args>
  <entities_version>2987</entities_version>
  <client_type>BACK</client_type>
  <enable_warnings>false</enable_warnings>
  <request_watchdog_check_results>true</request_watchdog_check_results>
  <use_raw_entities>true</use_raw_entities>
  <id>document-uuid-here</id>
</args>
```

**Ответ — Приходная накладная (GZIP, XML):**

```xml
<result>
  <success>true</success>
  <errorString/>
  <entitiesUpdate><!-- дельта сущностей --></entitiesUpdate>
  <returnValue>
    <documentNumber>DOC-100</documentNumber>
    <dateIncoming>2025-04-01</dateIncoming>
    <conception><__content>con-uuid</__content></conception>
    <supplier>sup-uuid</supplier>
    <defaultStore><__content>store-uuid</__content></defaultStore>
    <employeePassToAccount><__content>emp-uuid</__content></employeePassToAccount>
    <incomingDocumentNumber><__content>EXT-500</__content></incomingDocumentNumber>
    <comment>Тестовая накладная</comment>
    <incomingDate><__content>2025-03-30</__content></incomingDate>
    <transportInvoiceNumber><__content>TR-01</__content></transportInvoiceNumber>
    <items>
      <i>
        <eid>item-uuid-1</eid>          <!-- АТРИБУТ в реальности, но парсится как элемент -->
        <code>C1</code>
        <product>prod-uuid</product>
        <amount>10</amount>
        <amountUnit>unit-uuid</amountUnit>
        <store>store-uuid</store>
        <price>150.00</price>
        <sumWithoutNds>1200.00</sumWithoutNds>
        <sum>1500.00</sum>
        <ndsPercent>20</ndsPercent>
      </i>
    </items>
  </returnValue>
</result>
```

**Ответ — Производственный заказ:**

```xml
<result>
  <success>true</success>
  <errorString/>
  <returnValue>
    <eid>order-uuid-1</eid>
    <documentNumber>ORD-001</documentNumber>
    <status>NEW</status>
    <storeFrom>store-uuid</storeFrom>
    <createdInfo>
      <date>2025-03-20T10:30:00</date>
    </createdInfo>
    <items>
      <i>
        <amount>5</amount>                <!-- "0E-9" и "0" фильтруются -->
        <amountUnit>unit-uuid</amountUnit>
        <product>prod-uuid-1</product>
      </i>
    </items>
  </returnValue>
</result>
```

**Паттерн OptStr (опциональная строка — два формата):**
```xml
<!-- Формат 1: обёртка __content -->
<conception><__content>uuid</__content></conception>

<!-- Формат 2: plain chardata -->
<comment>Текст</comment>
```

---

### 5. POST /resto/services/document?methodName=saveOrUpdateDocument

**Назначение:** Создание/обновление документа в IIKO.

- Также: `saveOrUpdateDocumentWithValidation`
- Namespace запроса: `https://izi.cloud/iiko/package`
- Namespace ответа: `https://izi.cloud/iiko/document/response`
- Успех: `result.success = "true"`
- Возвращает номер документа, UUID и т.д.

---

### 6. POST /resto/services/products?methodName=createProduct|createProductGroup

**Назначение:** Создание номенклатуры/группы в IIKO.

- Namespace запроса: `https://izi.cloud/iiko/package`
- Namespace ответа: `https://izi.cloud/iiko/product/response` или `productGroup/response`

**RAW XML для создания продукта (из статьи 07):**

Ключевые поля:
- `entities-version` — текущая ревизия с сервера
- `eid` — UUID нового товара (тег product)
- `product` — артикул
- `type` — `GOODS`
- `mainUnit` — UUID единицы измерения
- `parent` — UUID родительской группы
- `num` — код в IIKO

---

### 7. Другие POST-эндпоинты для создания объектов

| methodName | Сервис | Namespace ответа |
|------------|--------|-----------------|
| createProduct | /resto/services/products | `.../product/response` |
| createProductGroup | /resto/services/products | `.../productGroup/response` |
| saveCorporationSettings | /resto/services/corporationSettings | `.../CorporationSettings/response` |
| createUser | /resto/services/users | `.../user/response` |
| saveOrUpdateDocument | /resto/services/document | `.../document/response` |

---

### 8. GET /resto/service/maintance/sql.jsp?sql=...

**Назначение:** Прямые SQL-запросы к БД IIKO.

- Query param: `sql=[URL-encoded SQL]`
- Заголовки: стандартные IIKO, **без GZIP**
- XDTO namespace: `https://izi.cloud/iiko/read/sql`, тип `root`
- Ответ: `resultSet { row[] }`

**Шаблон запроса:**
```sql
SELECT * FROM [doc_type]
WHERE documentNumber='[doc_number]'
  AND status<>'2'
  AND (dateCreated BETWEEN('[year]0101 00:00:00.000') AND ('[year]1231 23:59:59.999'))
```

**Важно:** Синтаксис SQL зависит от СУБД (PostgreSQL vs MSSQL). IIKO в основном использует MSSQL, но может быть на PostgreSQL.

---

### 9. GET /resto/services/brdDataLoading?methodName=getAllBrdData

**Назначение:** Загрузка данных BRD (Business Rules Database) — покупатели/подразделения.

- Статус: ссылки в коде есть, но активно не используется

---

## XDTO-пакеты (13 штук)

| Имя пакета | Namespace | Назначение |
|------------|-----------|-----------|
| like_iikoPackage | `.../iiko/package` | Обёртка для создания объектов |
| like_entitiesUpdate | `.../reading/entitiesUpdate` | Запрос дельта-синхронизации |
| like_entitiesUpdateResponse | `.../reading/entitiesUpdateResponse` | Ответ (v < 9) |
| like_entitiesUpdateResponse9 | `.../reading/entitiesUpdateResponse9` | Ответ (v >= 9) |
| like_readingInvoices | `.../reading/invoices` | Запрос списка накладных |
| like_readingDocument | `.../reading/document` | Запрос одного документа |
| like_readingIncomingInvoice | `.../reading/incomingInvoice` | Схема приходной накладной |
| like_readingOutgoingInvoice | `.../reading/outgoingInvoice` | Схема расходной накладной |
| like_getServerInfoResponse | `.../reading/serverInfoResponse` | Ответ get_server_info |
| like_SQLResponse | `.../read/sql` | Обёртка SQL-ответа |
| like_customers | (ref) | Данные покупателей |
| like_commonTypes | (ref) | Общие типы |

---

## GZIP-сжатие

- Большинство ответов IIKO — GZIP-сжатые
- Определяется по заголовку `Content-Encoding: gzip`
- Распаковка: `like_Common.DecompressGZIP()` (кастомная ZIP-реконструкция)
- SQL-эндпоинт (`sql.jsp`) — **без GZIP**

---

## Подводные камни (из опыта разработки)

1. **XDTO vs BSL**: XDTO-схема и BSL-код могут читать одно поле из разных мест. Пример: `deleted` обязателен И на уровне `<i>` (itemType в XDTO) И внутри `<r>` (BSL код читает `r.deleted`)
2. **nullableType**: пустые nullable-поля требуют `<field null="1"/>`, а не `<field/>`. Формат: `<field null="1"/>` (атрибут null) или `<field><__content>значение</__content></field>`
3. **xs:anyType и пустые теги**: внутри `<r>` (xs:anyType) пустой `<parent/>` или `<parent></parent>` НЕ создаёт свойство XDTO-объекта. Нужно непустое значение (например zero UUID `00000000-0000-0000-0000-000000000000`)
4. **serverState enum**: допустимые значения `NEW`, `WAITING_LICENSE`, `STARTING`, `START_FAILED`, `STARTED_SUCCESSFULLY`, `EMERGENCY`, `STOPPING`, `STOPPED`. НЕ `RUNNING`!
5. **get_server_info обязательные поля**: `serverName`, `edition`, `version`, `computerName`, `serverState`, `protocol` (nullable), `serverAddr` (nullable), `serverSubUrl` (nullable), `port`, `isPresent`
6. **supplierType enum** в 1С: `IMPORTER`, `PRODUCER`, `SUPPLIER`. Значение `internal` из IIKO не маппится — нужно пустое
7. **USER обязательные поля в `<r>`**: `deleted`, `revision`, `code`, `num`, `name`, `client`, `employee`, `supplier`, `system`, `supplierType`, `pluginUser`
8. **GZIP через Traefik**: кастомный `DecompressGZIP` в 1С конфликтует с промежуточными прокси. Для мока лучше отдавать plain XML без сжатия — 1С проверяет `Content-Encoding` header и читает plain через `GetBodyAsString("UTF-8")`
9. **Case-sensitive XML**: `<documentID>` требует `xml:"documentID"`, не `xml:"documentId"`
2. **eid — атрибут**: в позициях накладной `eid` это XML-атрибут, не элемент: `xml:"eid,attr"`
3. **documentSummary — текст**: содержит наименования товаров, не число
4. **Имена сущностей — два формата**: `<customValue>` для большинства, plain text для DEPARTMENT
5. **OptStr — два формата**: `<__content>` обёртка или plain chardata
6. **Нулевое количество в заказах**: `amount="0E-9"` или `"0"` — фильтруется
7. **Комментарий XDTO**: значение `"ОбъектXDTO"` / `"XDTODataObject"` — артефакт, заменяется на пустую строку
8. **SQL зависит от СУБД**: PostgreSQL и MSSQL имеют разный синтаксис
9. **1С числа как строки**: в JSON числа сериализуются как строки — нужен `flexInt64`
10. **Большие XML (мегабайты)**: справочники парсятся локально в 1С, не отправляются в облако

---

## Инсайты из декомпиляции серверного кода IIKO (Chain 7.4.6020.0)

Дистрибутив IIKO Chain залит в `laika-service/_iiko-chain/Server/exploded/`.
Декомпилировано из JAR: `RestoServer.jar`, `RestoCore.jar`, `Common.jar`.

### Архитектура RPC-сервера

IIKO Server = Tomcat + Spring Security + кастомный RPC.

```
HTTP запрос
  → web.xml: /services/* → ServicesServlet (resto.rpc.ServicesServlet)
  → ServicesRegistry.processCall(serviceName, methodName, xmlReader, resultProcessor)
  → ServiceCaller<T>.call(methodName, ...) — вызывает @Op метод по имени
  → ServiceResult.writeTo(writer) — оборачивает ответ в <result>
```

- `serviceName` = часть URL после `/services/` (например `document`, `update`, `products`)
- `methodName` = query param `?methodName=...`
- Аргументы парсятся из XML body через `@Arg(value="имя")`
- Ответ **всегда** обёрнут в `<result>` через `ServiceResult`

### Зарегистрированные сервисы (@RemoteService)

| @RemoteService(name=) | Java-класс | JAR |
|-----------------------|-----------|-----|
| `update` | `resto.back.cache.UpdateService` (DEPRECATED) | RestoServer.jar |
| `entities` | `resto.back.cache.EntitiesService` | RestoServer.jar |
| `document` | `resto.back.documents.DocumentService` | RestoServer.jar |
| `products` | `resto.back.store.ProductsService` | RestoServer.jar |

**Лайка использует deprecated `update`, а не новый `entities`** — у них разные сигнатуры:
- `update.waitEntitiesUpdate(fromRevision, timeoutMillis, useRawEntities: Boolean)`
- `entities.waitEntitiesUpdate(fromRevision, timeoutMillis, classNames: List<String>)`

### Полные сигнатуры методов DocumentService

```java
@RemoteService(name="document")
public class DocumentService {
    // Список накладных за период
    @Op List<AbstractDocumentListRecord> getIncomingDocumentsRecords(
        @Arg("dateFrom") Date, @Arg("dateTo") Date, @Arg("docType") DocumentType)

    // Список накладных за период с фильтром по подразделениям
    @Op List<AbstractDocumentListRecord> getIncomingDocumentsRecordsByDepartments(
        @Arg("dateFrom") Date, @Arg("dateTo") Date, @Arg("docType") DocumentType,
        @Arg("departmentsSet") @Nullable Set<DepartmentEntity>)

    // Один документ по UUID (тип определяется автоматически)
    @Op AbstractDocument getAbstractDocument(@Arg("id") Guid)

    // Один документ по типу и UUID
    @Op AbstractDocument<?> getDocument(@Arg("docType") DocumentType, @Arg("id") Guid)

    // Несколько документов по UUID
    @Op Collection<AbstractDocument> getAbstractDocuments(@Arg("documentIds") List<Guid>)

    // Сохранение/обновление документа
    @Op DocumentValidationResult saveOrUpdateDocument(
        @Arg("document") AbstractDocument<?>,
        @Arg("suppressWarnings") @Nullable Collection<ValidationWarning>)

    // Удаление
    @Op Boolean deleteIncomingDocument(@Arg("documentId") Guid, @Arg("docType") DocumentType)
    @Op void unDeleteIncomingDocument(@Arg("documentId") Guid, @Arg("docType") DocumentType)

    // Транзакции и себестоимость
    @Op List<StoreTransactionInfo> getDocumentTransactions(
        @Arg("documentId") Guid, @Arg("documentItemIds") @Nullable Set<Guid>)
    @Op Map<Guid, BigDecimal> getDocumentItemsCosts(@Arg("documentId") Guid)
    @Op Map<Guid, PricingInfo> getDocumentItemsPricing(
        @Arg("documentId") Guid, @Arg("pricingParameters") PricingParameters)
}
```

### Полные сигнатуры UpdateService (deprecated, используется Лайкой)

```java
@Deprecated
@RemoteService(name="update")
public class UpdateService {
    @Op @LongPolling void waitEntitiesUpdate(
        @Arg("fromRevision") int, @Arg("timeoutMillis") int,
        @Arg("useRawEntities") @Nullable Boolean)

    @Op @LongPolling EntitiesUpdate getEntitiesUpdate(
        @Arg("fromRevision") int, @Arg("timeoutMillis") int,
        @Arg("useRawEntities") @Nullable Boolean)
}
```

### Полные сигнатуры EntitiesService (новый)

```java
@RemoteService(name="entities")
public class EntitiesService {
    @Op @LongPolling EntitiesUpdate waitEntitiesUpdate(
        @Arg("fromRevision") int, @Arg("timeoutMillis") int,
        @Arg("classNames") @Nullable List<String>)

    @Op EntitiesUpdate getEntitiesUpdate(
        @Arg("fromRevision") int, @Arg("classNames") @Nullable List<String>)

    @Op Collection<ByValue<PersistedEntity>> getEntitiesByIds(@Arg("ids") List<Guid>)
}
```

### Полный список RPC-заголовков (enum RPCHeaders)

```
X-Resto-LoginName            — логин
X-Resto-PasswordHash         — SHA1(пароль), lowercase hex
X-Resto-BackVersion          — версия клиента ("11.0")
X-Resto-Protocol-Version     — версия протокола
X-Resto-Protocol-Changes     — список изменений протокола
X-Resto-Guid-Explain         — режим расшифровки UUID
X-Resto-ServerEdition        — IIKO_RMS | IIKO_CLOUD | IIKO_DEFAULT
X-Resto-TerminalId           — UUID терминала
X-Resto-TerminalToken        — токен терминала
X-Resto-AuthType             — тип авторизации (BACK)
X-Resto-AuthResult           — результат авторизации (в ответе)
X-Resto-FrontLoginedUserId   — legacy
X-Resto-FrontLoggedInUserId  — UUID залогиненного пользователя
X-Resto-CorrelationId        — ID для трассировки
X-Resto-License-Hash         — хеш лицензии
X-Resto-RestrictionsState-Hash — хеш ограничений
X-Resto-ConnectionTokens     — токены подключений
```

### Обработка ошибок авторизации (ServicesServlet)

При ошибке авторизации сервер возвращает:
- **HTTP 403** (по умолчанию) или **HTTP 401** (при невалидном токене терминала)
- Заголовок `X-Resto-AuthResult` со значением enum `ConnectionResult`:
  - `SUCCESS` — успех
  - `AUTH_FAILED` — неверный логин/пароль
  - `INCORRECT_BACK_VERSION` — несовместимая версия клиента
  - `INCORRECT_SERVER_VERSION` — несовместимая версия сервера
  - `TERMINAL_NOT_REGISTERED` — терминал не зарегистрирован
  - `WRONG_EDITION` — неправильная редакция (RMS/Cloud/Chain)
  - `INTERNAL_ERROR` — внутренняя ошибка сервера

### get_server_info.jsp — детали

- По умолчанию отдаёт **windows-1251** (для совместимости с iikoOffice < 3.6.2)
- UTF-8 только с параметром `?encoding=UTF-8`
- Сериализует `resto.config.ServerInfo` через `XMLConverter`
- Ответ: `<r>...</r>` (корневой элемент `r`, не `result`)

### GZIP на входе

ServicesServlet проверяет заголовок `Content-Encoding: gzip` на запросах.
Если присутствует — тело запроса распаковывается перед парсингом XML.
Т.е. клиент тоже может сжимать запросы.

### Формат ответа ServiceResult

Все ответы `/services/*` имеют единую структуру:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<result>
  <!-- ServiceResult.writeTo(writer) -->
  <success>true|false</success>
  <errorString>текст ошибки</errorString>     <!-- если !success -->
  <stackTrace>...</stackTrace>                 <!-- если системная ошибка -->
  <entitiesUpdate>...</entitiesUpdate>         <!-- delta, если есть -->
  <returnValue>...</returnValue>               <!-- данные, зависят от метода -->
</result>
```

Статус ответа (внутренний enum):
- `SUCCESS` — данные в returnValue
- `DISPLAYABLE_ERROR` — ошибка для показа пользователю
- `SYSTEM_ERROR` — внутренняя ошибка сервера
- `RECOVERABLE_WARNING` — предупреждение, можно продолжить

### web.xml маппинги (полный список)

| URL pattern | Servlet/Handler |
|-------------|----------------|
| `/services/*` | `ServicesServlet` (resto.rpc) — **основной RPC** |
| `/api/*` | Jersey REST API (resto.api.RestoApiApplication) |
| `/agent` | AgentServlet (терминальный агент) |
| `/launcher` | LauncherServlet (запуск клиента) |
| `/service/reports/web-query.iqy` | WebQueryServlet (Excel) |
| `/service/export/csv/*` | ExportCsvServlet |
| `*.jsp` / `*.jspx` | JSP (утилитарные страницы, sql.jsp, мониторинг) |

### Доступные JSP-утилиты

Кроме `get_server_info.jsp` и `sql.jsp`, на сервере есть:
- `/service/maintance/groovy.jsp` — выполнение Groovy-скриптов (!)
- `/service/maintance/flushEntities.jsp` — сброс кеша сущностей
- `/service/maintance/recomputeStore.jsp` — пересчёт остатков
- `/service/monitoring/health.jsp` — healthcheck
- `/service/monitoring/connections.jsp` — список подключений
- `/service/monitoring/threads.jsp` — потоки JVM
- `/service/import/importDocument.jsp` — импорт документа

### Версия сервера

Из `SHA256SUMS.classes.txt`: **iikoRMS version 2020 (7.4.6020.0 built on 7 Oct 2020)**

---

## Источники

- Код 1С: `laika-ka/CommonModules/like_Common*.bsl`, `like_EntitiesAtServer.bsl`, `like_InvoicesAtServer.bsl`, `like_DocumentAtServer.bsl`, `like_CreatingObjects.bsl`, `like_SQLRequestsAtServer.bsl`, `like_ConnectionAtServer.bsl`
- Код Go: `laika-service/internal/iiko/*.go`, `internal/api/*.go`
- Тестовые фикстуры: `laika-service/internal/iiko/*_test.go`
- Статьи: `laika-ka/_Articles/01-08.pdf` (Infostart, 2018-2020)
- Дистрибутив IIKO Chain 7.4.6020.0: `laika-service/_iiko-chain/Server/exploded/` (JSP, web.xml, JAR)
- Декомпиляция JAR (CFR 0.152): `RestoServer.jar`, `RestoCore.jar` → `/tmp/iiko_decompiled/`
- Методология отладки: Fiddler на процесс IIKO Office для перехвата HTTP-трафика
