///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019-2025, Tian Semen Sergeevich (semen@tyan.pw), https://tyan.pw
// All rights reserved. This program and accompanying materials
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

// Единственная точка HTTP-взаимодействия с Laika-сервисом.
// Все остальные модули вызывают функции этого модуля — прямых HTTP-вызовов к сервису больше нигде нет.

// ============================================================
// НАСТРОЙКИ
// ============================================================

Function ServiceURL() Export
	Return "https://laika.ui99.ru";
EndFunction

// Ключ лицензии хранится в константе like_LicenseKey.
// Если константа не заполнена — используем заглушку для разработки.
Function LicenseKey() Export
	licKey = Constants.like_LicenseKey.Get();
	If Not ValueIsFilled(licKey) Then
		Raise NStr("en = 'License key is not set. Fill in constant like_LicenseKey.';
		           |ru = 'Не заполнен ключ лицензии. Заполните константу like_LicenseKey.'");
	EndIf;
	Return licKey;
EndFunction

// ============================================================
// НИЗКОУРОВНЕВЫЙ HTTP
// ============================================================

Function BuildRequest(resource, body = Undefined) Export

	Headers = New Map;
	Headers.Insert("Content-Type", "application/json");
	Headers.Insert("Accept",       "application/json");
	Headers.Insert("License-Key",  LicenseKey());

	Request = New HTTPRequest(resource, Headers);
	If body <> Undefined Then
		Request.SetBodyFromString(body, TextEncoding.UTF8, ByteOrderMarkUse.DontUse);
	EndIf;

	Return Request;

EndFunction

Function BuildConnection()

	URL  = ServiceURL();
	// Parses "https://laika.ui99.ru" → host + port
	Pos  = Find(URL, "://");
	tail = Mid(URL, Pos + 3);
	isSecure = (Lower(Left(URL, Pos - 1)) = "https");

	colonPos = Find(tail, ":");
	If colonPos > 0 Then
		host = Left(tail, colonPos - 1);
		port = Number(Mid(tail, colonPos + 1));
	Else
		host = tail;
		port = ?(isSecure, 443, 80);
	EndIf;

	If isSecure Then
		Return New HTTPConnection(host, port,,,,, New OpenSSLSecureConnection());
	Else
		Return New HTTPConnection(host, port);
	EndIf;

EndFunction

// Выполняет HTTP-запрос и возвращает структуру:
//   Success    — Булево
//   StatusCode — Число
//   Body       — Строка (JSON)
//   Error      — Строка (если Success = Ложь)
Function DoExecute(method, resource, body = Undefined) Export

	result = DoHTTPRequest(method, resource, body, True);
	If result.Success Then
		Return result;
	EndIf;

	If result.StatusCode = 401 Then
		result.Error = NStr("en = 'License key is invalid or missing.';
		                    |ru = 'Ключ лицензии недействителен или не передан.'");
		like_Common.UsrMessage(result.Error);
	ElsIf result.StatusCode = 402 Then
		result.Error = NStr("en = 'Subscription expired. Renew via Laika settings.';
		                    |ru = 'Подписка истекла. Продлите через настройки Лайки.'");
		like_Common.UsrMessage(result.Error);
	ElsIf result.StatusCode = 403 Then
		If Find(result.Body, "demo document limit") > 0 Then
			result.Error = NStr("en = 'Demo document limit reached. Subscribe to continue.';
			                    |ru = 'Лимит документов в демо-режиме исчерпан. Оформите подписку для продолжения работы.'");
		Else
			result.Error = NStr("en = 'This feature is not available in your plan.';
			                    |ru = 'Эта функция недоступна в вашем тарифе.'");
		EndIf;
		like_Common.UsrMessage(result.Error);
	EndIf;

	Return result;

EndFunction

// Вариант Execute без заголовка License-Key (для /demo/activate).
Function ExecuteNoAuth(method, resource, body = Undefined) Export

	result = DoHTTPRequest(method, resource, body, False);
	If result.Success Then
		Return result;
	EndIf;

	If result.StatusCode = 409 Then
		result.Error = NStr("en = 'Demo already activated for this email.';
		                    |ru = 'Демо-режим уже был активирован для этого email.'");
		like_Common.UsrMessage(result.Error);
	EndIf;

	Return result;

EndFunction

Function DoHTTPRequest(method, resource, body, includeAuth)

	result = New Structure("Success, StatusCode, Body, Error", False, 0, "", "");

	Try
		connection = BuildConnection();

		If includeAuth Then
			request = BuildRequest(resource, body);
		Else
			Headers = New Map;
			Headers.Insert("Content-Type", "application/json");
			Headers.Insert("Accept",       "application/json");
			request = New HTTPRequest(resource, Headers);
			If body <> Undefined Then
				request.SetBodyFromString(body, TextEncoding.UTF8, ByteOrderMarkUse.DontUse);
			EndIf;
		EndIf;

		response = connection.CallHTTPMethod(method, request);
	Except
		result.Error = NStr("en = 'Connection error: '; ru = 'Ошибка соединения: '") + ErrorDescription();
		WriteLogEvent("like_CoreAPI", EventLogLevel.Error,,, result.Error);
		Return result;
	EndTry;

	result.StatusCode = response.StatusCode;
	result.Body       = response.GetBodyAsString("UTF-8");

	If response.StatusCode >= 200 And response.StatusCode < 300 Then
		result.Success = True;
	Else
		result.Error = NStr("en = 'Server error: '; ru = 'Ошибка сервера: '") + response.StatusCode;
		WriteLogEvent("like_CoreAPI", EventLogLevel.Error,,, result.Error + " | " + result.Body);
	EndIf;

	Return result;

EndFunction

// ============================================================
// СПРАВОЧНИКИ — СИНХРОНИЗАЦИЯ
// ============================================================

// Возвращает текущую revision с сервера.
// Передаётся в тело запроса к IIKO (/resto/services/update, поле fromRevision).
Function GetEntitiesRevision() Export

	result = DoExecute("GET", "/api/v1/entities/revision?licenseKey=" + LicenseKey());
	If Not result.Success Then
		Return -1;
	EndIf;

	parsed = ParseJSON(result.Body);
	Return ?(parsed <> Undefined, parsed["revision"], -1);

EndFunction

// Сохраняет состояние синхронизации на сервисе после локального парсинга XML.
// 1С разбирает XML и записывает справочники самостоятельно (в LAN — быстро),
// затем отправляет на сервис только revision и список UUID для трекинга.
//
// objects — Массив Структур: {uuid, catalog, revision}
// newRevision — Число (revision из ответа IIKO)
//
// Возвращает Булево (успех/неуспех).
Function PersistEntities(newRevision, objects) Export

	bodyMap = New Map;
	bodyMap.Insert("newRevision", newRevision);
	bodyMap.Insert("objects",     objects);

	result = DoExecute("POST", "/api/v1/entities/persist", MapToJSON(bodyMap));
	Return result.Success;

EndFunction

// ============================================================
// НАКЛАДНЫЕ
// ============================================================

// Отправляет rawXML ответа IIKO на getIncomingDocumentsRecordsByDepartments.
// Возвращает структуру:
//   Success      — Булево
//   Invoices     — Массив Соответствий (строки для табличной части формы)
//   NewRevision  — Число
//   EntityUpsert — Массив (передать в like_AdapterКА.WriteEntities)
Function ParseInvoiceList(rawXML) Export

	bodyMap = New Map;
	bodyMap.Insert("licenseKey", LicenseKey());
	bodyMap.Insert("rawXml",     rawXML);

	result = DoExecute("POST", "/api/v1/invoices/parse-list", MapToJSON(bodyMap));

	empty = New Structure("Success, Invoices, NewRevision, EntityUpsert",
		False, New Array, -1, New Array);
	If Not result.Success Then
		Return empty;
	EndIf;

	parsed = ParseJSON(result.Body);
	If parsed = Undefined Then
		Return empty;
	EndIf;

	Return New Structure("Success, Invoices, NewRevision, EntityUpsert",
		True,
		parsed["invoices"],
		parsed["newRevision"],
		parsed["entityUpsert"]);

EndFunction

// Отправляет rawXML ответа IIKO на getAbstractDocument (ns: incomingInvoice).
// Возвращает структуру:
//   Success      — Булево
//   Invoice      — Соответствие (поля накладной для like_AdapterКА.CreateIncomingInvoice)
//   NewRevision  — Число
//   EntityUpsert — Массив
Function ParseInvoice(rawXML) Export

	bodyMap = New Map;
	bodyMap.Insert("licenseKey", LicenseKey());
	bodyMap.Insert("rawXml",     rawXML);

	result = DoExecute("POST", "/api/v1/invoices/parse", MapToJSON(bodyMap));

	empty = New Structure("Success, Invoice, NewRevision, EntityUpsert",
		False, New Map, -1, New Array);
	If Not result.Success Then
		Return empty;
	EndIf;

	parsed = ParseJSON(result.Body);
	If parsed = Undefined Then
		Return empty;
	EndIf;

	Return New Structure("Success, Invoice, NewRevision, EntityUpsert",
		True,
		parsed["invoice"],
		parsed["newRevision"],
		parsed["entityUpsert"]);

EndFunction

// ============================================================
// ПРОИЗВОДСТВЕННЫЕ ЗАКАЗЫ
// ============================================================

// Отправляет rawXML ответа IIKO на getAbstractDocument (ns: productionOrder).
// Возвращает структуру:
//   Success — Булево
//   Order   — Соответствие (поля заказа для like_AdapterКА.CreateMobileOrder)
Function ParseOrder(rawXML) Export

	bodyMap = New Map;
	bodyMap.Insert("licenseKey", LicenseKey());
	bodyMap.Insert("rawXml",     rawXML);

	result = DoExecute("POST", "/api/v1/orders/parse", MapToJSON(bodyMap));

	empty = New Structure("Success, Order", False, New Map);
	If Not result.Success Then
		Return empty;
	EndIf;

	parsed = ParseJSON(result.Body);
	If parsed = Undefined Then
		Return empty;
	EndIf;

	Return New Structure("Success, Order", True, parsed);

EndFunction

// ============================================================
// СТАТУС ЛИЦЕНЗИИ
// ============================================================

// Возвращает структуру:
//   Success    — Булево
//   Plan       — Строка ("basic", "demo", ...)
//   ExpiresAt  — Строка (ISO 8601)
//   Features   — Соответствие (имя_фичи → Булево)
Function GetLicenseStatus() Export

	result = DoExecute("GET", "/api/v1/license/status?licenseKey=" + LicenseKey());

	status = New Structure("Success, Plan, ExpiresAt, Features, DocCount", False, "", "", New Map, 0);
	If Not result.Success Then
		Return status;
	EndIf;

	parsed = ParseJSON(result.Body);
	If parsed = Undefined Then
		Return status;
	EndIf;

	status.Success   = True;
	status.Plan      = SafeGet(parsed, "plan", "");
	status.ExpiresAt = SafeGet(parsed, "expiresAt", "");
	status.Features  = SafeGet(parsed, "features", New Map);
	status.DocCount  = SafeGet(parsed, "docCount", 0);
	Return status;

EndFunction

// ============================================================
// БИЛЛИНГ
// ============================================================

// Создаёт платёж на сервисе и возвращает данные для QR-кода СБП.
// period — "month" | "year"
// Возвращает структуру:
//   Success    — Булево
//   PaymentId  — Строка (UUID)
//   QRCodeData — Строка (данные для формирования QR)
//   Amount     — Строка ("990.00")
//   Period     — Строка
Function CreatePayment(period) Export

	bodyMap = New Map;
	bodyMap.Insert("period", period);

	result = DoExecute("POST", "/api/v1/billing/payment", MapToJSON(bodyMap));

	empty = New Structure("Success, PaymentId, QRCodeData, Amount, Period",
		False, "", "", "", "");
	If Not result.Success Then
		Return empty;
	EndIf;

	parsed = ParseJSON(result.Body);
	If parsed = Undefined Then
		Return empty;
	EndIf;

	Return New Structure("Success, PaymentId, QRCodeData, Amount, Period",
		True,
		parsed["paymentId"],
		parsed["qrCodeData"],
		parsed["amount"],
		parsed["period"]);

EndFunction

// Опрашивает статус платежа.
// Возвращает структуру:
//   Success — Булево
//   Status  — Строка ("pending" | "succeeded" | "canceled")
//   PaidAt  — Строка (ISO 8601) или ""
Function GetPaymentStatus(paymentId) Export

	result = DoExecute("GET", "/api/v1/billing/payment/" + paymentId + "/status");

	empty = New Structure("Success, Status, PaidAt", False, "", "");
	If Not result.Success Then
		Return empty;
	EndIf;

	parsed = ParseJSON(result.Body);
	If parsed = Undefined Then
		Return empty;
	EndIf;

	Return New Structure("Success, Status, PaidAt",
		True,
		parsed["status"],
		?(parsed["paidAt"] <> Undefined, parsed["paidAt"], ""));

EndFunction

// ============================================================
// ДЕМО-РЕЖИМ
// ============================================================

// Активирует демо-лицензию без оплаты.
// Этот запрос не требует License-Key — ключ создаётся на сервисе.
// Возвращает структуру:
//   Success    — Булево
//   LicenseKey — Строка (UUID)
//   Plan       — Строка ("demo")
//   ExpiresAt  — Строка (ISO 8601)
Function ActivateDemo(name, email) Export

	bodyMap = New Map;
	bodyMap.Insert("name",  name);
	bodyMap.Insert("email", email);

	result = ExecuteNoAuth("POST", "/api/v1/demo/activate", MapToJSON(bodyMap));

	empty = New Structure("Success, LicenseKey, Plan, ExpiresAt", False, "", "", "");
	If Not result.Success Then
		Return empty;
	EndIf;

	parsed = ParseJSON(result.Body);
	If parsed = Undefined Then
		Return empty;
	EndIf;

	Return New Structure("Success, LicenseKey, Plan, ExpiresAt",
		True,
		parsed["licenseKey"],
		parsed["plan"],
		parsed["expiresAt"]);

EndFunction

// ============================================================
// ВСПОМОГАТЕЛЬНЫЕ
// ============================================================

// Разбирает JSON-строку в Соответствие (Map).
// Возвращает Undefined если строка пустая или невалидная.
Function ParseJSON(jsonString) Export

	If Not ValueIsFilled(jsonString) Then
		Return Undefined;
	EndIf;

	Try
		reader = New JSONReader;
		reader.SetString(jsonString);
		result = ReadJSON(reader);
		reader.Close();
		Return result;
	Except
		WriteLogEvent("like_CoreAPI", EventLogLevel.Error,,,
			NStr("en = 'JSON parse error: '; ru = 'Ошибка разбора JSON: '") + ErrorDescription());
		Return Undefined;
	EndTry;

EndFunction

// Сериализует Соответствие в JSON-строку.
Function MapToJSON(map) Export

	writer = New JSONWriter;
	writer.SetString();
	WriteJSON(writer, map);
	Return writer.Close();

EndFunction

// Безопасное чтение значения из Map или Structure.
// ReadJSON может вернуть как Соответствие, так и Структуру — в зависимости от платформы.
Function SafeGet(collection, fieldName, defaultValue) Export

	If TypeOf(collection) = Type("Map") Then
		mapValue = collection[fieldName];
		Return ?(mapValue <> Undefined, mapValue, defaultValue);
	EndIf;

	If TypeOf(collection) = Type("Structure") Then
		mapValue = Undefined;
		If collection.Property(fieldName, mapValue) Then
			Return ?(mapValue <> Undefined, mapValue, defaultValue);
		EndIf;
		Return defaultValue;
	EndIf;

	Return defaultValue;

EndFunction
