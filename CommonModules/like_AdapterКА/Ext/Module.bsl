///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019-2025, Tian Semen Sergeevich (semen@tyan.pw), https://tyan.pw
// All rights reserved. This program and accompanying materials
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

// Адаптер для конфигурации "Комплексная автоматизация".
// Реализует запись объектов в справочники КА по структурам,
// возвращённым Laika-сервисом.
// Не содержит бизнес-логики — только чтение/запись объектов 1С.

// ============================================================
// ПУБЛИЧНЫЙ ИНТЕРФЕЙС
// ============================================================

// Записывает массив объектов, полученных от like_CoreAPI.SyncEntities.
// upsertList — Массив Соответствий из JSON-ответа сервиса.
// Каждый элемент содержит поля: uuid, catalog, isFolder, deletionMark,
// code, description, и опциональные: parentUUID, accountingCategoryUUID,
// mainUnitUUID, num, productType, isCash, supplierType, isClient, и др.
Procedure WriteEntities(upsertList) Export

	For Each item In upsertList Do
		WriteEntity(item);
	EndDo;

EndProcedure

// Создаёт XDTO-объект мобильного заказа для 1С mobile app framework.
// order    — Соответствие из like_CoreAPI.ParseOrder (поля: id, date, documentNumber, items[])
// settings — строка регистра like_ordersSettings (Организация, Клиент, Валюта, ВидЦены)
// Возвращает XDTO-объект DocumentObject.ЗаказКлиента или Undefined при ошибке.
Function CreateMobileOrder(order, settings) Export

	URIName     = "http://www.1c.ru/CustomerOrders/Exchange";
	objectType  = ФабрикаXDTO.Тип(URIName, "DocumentObject.ЗаказКлиента");
	mobileOrder = ФабрикаXDTO.Создать(objectType);

	orderDate = like_Common.IikoDateTimeTo1C(order["date"]);
	docDate   = BegOfDay(orderDate);
	priceType = IdStrByRef(settings.ВидЦены);
	store     = "00000000-0000-0000-0000-000000000000";

	mobileOrder.Date                         = orderDate;
	mobileOrder.DeletionMark                 = False;
	mobileOrder.Posted                       = True;
	mobileOrder.Ref                          = order["id"];
	mobileOrder.Валюта                       = IdStrByRef(settings.Валюта);
	mobileOrder.ВидЦены                      = priceType;
	mobileOrder.ДатаОплаты                   = docDate;
	mobileOrder.ДатаОтгрузки                 = docDate;
	mobileOrder.ДатаПредоплатыПоДокументу    = docDate;
	mobileOrder.ДатаСледующегоПлатежа        = docDate;
	mobileOrder.ДокументОснование            = "00000000-0000-0000-0000-0000000000000000";
	mobileOrder.ЖелаемаяДатаОтгрузки        = docDate;
	mobileOrder.Клиент                       = IdStrByRef(settings.Клиент);
	Контрагент = ПартнерыИКонтрагенты.ПолучитьКонтрагентаПартнераПоУмолчанию(settings.Клиент);
	mobileOrder.Контрагент                   = IdStrByRef(Контрагент);
	mobileOrder.Организация                  = IdStrByRef(settings.Организация);
	mobileOrder.Самовывоз                    = False;
	mobileOrder.Склад                        = store;
	mobileOrder.СостояниеДокумента           = "Горящие";
	mobileOrder.СостояниеДокументаИБ         = "НеПередан";
	mobileOrder.СтатусДокумента              = "НеСогласован";
	mobileOrder.СтатусОбмена                 = "КОбмену";
	mobileOrder.ФормаОплаты                  = "Наличная";

	goodsObjectType = ФабрикаXDTO.Тип(URIName, "DocumentTabularSectionRow.ЗаказКлиента.Товары");

	items = order["items"];
	For Each item In items Do
		productUUID = item["productUUID"];

		// Найти 1С-ссылку через UUID каталога (UUID = IIKO UUID, установлен при синхронизации)
		productRef = Catalogs.like_products.GetRef(New UUID(productUUID));
		matchingQuery = New Query;
		matchingQuery.SetParameter("likeRef", productRef);
		matchingQuery.Text = "SELECT TOP 1 ref1C FROM InformationRegister.like_objectMatching WHERE likeRef = &likeRef";
		sel = matchingQuery.Execute().Select();
		If Not sel.Next() Or sel.ref1C = Null Then
			Message(NStr("en = 'No matching for product '; ru = 'Не найдено сопоставление для товара '") + productUUID);
			Continue;
		EndIf;

		НовыйТовар = ФабрикаXDTO.Создать(goodsObjectType);
		НовыйТовар.ВидЦены           = priceType;
		НовыйТовар.Количество        = 1;
		НовыйТовар.КоличествоУпаковок = 1;
		НовыйТовар.Номенклатура      = IdStrByRef(sel.ref1C);
		НовыйТовар.Склад             = store;
		НовыйТовар.Упаковка          = "8bc3c66a-1769-4d03-91b7-802e4948fed1";

		mobileOrder.Товары.Добавить(НовыйТовар);
	EndDo;

	Return mobileOrder;

EndFunction

// ============================================================
// ВНУТРЕННЯЯ ЛОГИКА
// ============================================================

Procedure WriteEntity(item)

	catalogName  = item["catalog"];
	uuid         = item["uuid"];
	isFolder     = item["isFolder"] = True;
	deletionMark = item["deletionMark"] = True;

	BeginTransaction();
	Try

		ref = Catalogs[catalogName].GetRef(New UUID(uuid));

		// Найти существующий объект или создать новый
		existingObject = ref.GetObject();
		If existingObject = Undefined Then
			If isFolder Then
				entity = Catalogs[catalogName].CreateFolder();
			Else
				entity = Catalogs[catalogName].CreateItem();
			EndIf;
			entity.SetNewObjectRef(ref);
		Else
			entity = existingObject;
		EndIf;

		entity.DeletionMark = deletionMark;
		entity.Code         = StrValue(item["code"]);
		entity.Description  = StrValue(item["description"]);

		// Parent — иерархические справочники
		parentUUID = StrValue(item["parentUUID"]);
		If ValueIsFilled(parentUUID) Then
			entity.Parent = Catalogs[catalogName].GetRef(New UUID(parentUUID));
		EndIf;

		// Атрибуты, специфичные для отдельных справочников
		SetOptionalAttributes(entity, item);

		entity.Write();
		CommitTransaction();

	Except
		If TransactionActive() Then
			RollbackTransaction();
		EndIf;
		WriteLogEvent(
			NStr("en = 'like_AdapterКА.WriteEntity'; ru = 'like_AdapterКА.WriteEntity'"),
			EventLogLevel.Error,,
			uuid + " / " + catalogName,
			ErrorDescription());
	EndTry;

EndProcedure

// Устанавливает атрибуты, которые есть не у всех справочников.
// Проверяем наличие атрибута перед установкой — адаптер не должен
// знать внутреннюю структуру каждого справочника.
Procedure SetOptionalAttributes(entity, item)

	meta = entity.Metadata();

	// like_products, like_accountingCategories
	acUUID = StrValue(item["accountingCategoryUUID"]);
	If ValueIsFilled(acUUID) And meta.Attributes.Find("accountingCategoryID") <> Undefined Then
		entity.accountingCategoryID = acUUID;
		entity.accountingCategory   = Catalogs.like_accountingCategories.GetRef(New UUID(acUUID));
	EndIf;

	// like_products
	muUUID = StrValue(item["mainUnitUUID"]);
	If ValueIsFilled(muUUID) And meta.Attributes.Find("mainUnitID") <> Undefined Then
		entity.mainUnitID   = muUUID;
		entity.measureUnit  = Catalogs.like_measureUnits.GetRef(New UUID(muUUID));
	EndIf;

	If meta.Attributes.Find("num") <> Undefined Then
		entity.num = StrValue(item["num"]);
	EndIf;

	If meta.Attributes.Find("type") <> Undefined Then
		productType = StrValue(item["productType"]);
		If ValueIsFilled(productType) Then
			entity.type = Enums.like_productTypes[productType];
		EndIf;
	EndIf;

	// like_paymentTypes
	If meta.Attributes.Find("isCash") <> Undefined Then
		entity.isCash = item["isCash"] = True;
	EndIf;

	// like_users
	If meta.Attributes.Find("supplierType") <> Undefined Then
		supplierType = StrValue(item["supplierType"]);
		entity.supplierType  = ?(ValueIsFilled(supplierType),
			Enums.like_supplierTypes[supplierType],
			Enums.like_supplierTypes.EmptyRef());
		entity.client     = item["isClient"]      = True;
		entity.employee   = item["isEmployee"]    = True;
		entity.pluginUser = item["isPluginUser"]  = True;
		entity.supplier   = item["isSupplierUser"]= True;
		entity.system     = item["isSystem"]      = True;
	EndIf;

EndProcedure

// Безопасно возвращает строку из значения соответствия.
Function StrValue(value)
	Return ?(value = Undefined, "", String(value));
EndFunction

Function IdStrByRef(ref)
	Return String(ref.UUID());
EndFunction
