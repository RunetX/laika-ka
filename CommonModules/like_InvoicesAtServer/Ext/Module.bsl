///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019-2023, Tian Semen Sergeevich (semen@tyan.pw), https://tyan.pw
// All rights reserved. This program and accompanying materials 
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

Function GetReadingInvoicesXML(connection, dateFrom, dateTo, docType)
	
	argsType = XDTOFactory.Type("https://izi.cloud/iiko/reading/invoices", "args");
	args = XDTOFactory.Create(argsType); 
	
	eVersion = like_EntitiesAtServer.GetEntitiesVersion(connection);
	args.entities_version = eVersion;
	args.client_type 	  = "BACK";
	args.enable_warnings  = False;	
	args.request_watchdog_check_results = True;
	args.use_raw_entities = True;
	args.dateFrom 		  = like_CommonAtServer.getIIKODate(dateFrom, "000");
	args.dateTo 		  = like_CommonAtServer.getIIKODate(dateTo, "999");
	args.docType 		  = docType;	
	
	return like_CommonAtServer.XDTO2XML(args);
	
EndFunction

Function GetInvoices(dateFrom, dateTo, docType) Export

	ActiveConnection = like_ConnectionAtServer.GetActiveConnecton();
	If ActiveConnection = Undefined Then
		Return New Structure("success, errorString", False, NStr("en = 'No active connection'; ru = 'Подключение неактивно'"));
	EndIf;

	// 1. Получить rawXML от IIKO
	XMLPackage   = GetReadingInvoicesXML(ActiveConnection, dateFrom, dateTo, docType);
	ConnectionFields = like_ConnectionAtServer.GetConnectionFields(ActiveConnection);

	ObjectFields = like_CommonAtServer.GetObjectFieldsStructure();
	ObjectFields.ConProps    = ConnectionFields;
	ObjectFields.Resource    = "/resto/services/document";
	ObjectFields.RequestType = "POST";
	ObjectFields.Headers     = like_Common.GetIIKOHeaders(ConnectionFields);
	ObjectFields.Body        = XMLPackage;
	ObjectFields.isGZIP      = True;
	Params = New Map;
	Params.Insert("methodName", "getIncomingDocumentsRecordsByDepartments");
	ObjectFields.Parameters  = Params;

	rawXML = like_CommonAtServer.GetIikoRawXML(ObjectFields);
	If rawXML = Undefined Then
		Return New Structure("success, errorString", False,
			NStr("en = 'Receiving data from IIKO server error'; ru = 'Ошибка получения данных с сервера IIKO'"));
	EndIf;

	// 2. Разобрать на сервисе — бизнес-логика там
	parseResult = like_CoreAPI.ParseInvoiceList(rawXML);
	If Not parseResult.Success Then
		Return New Structure("success, errorString", False,
			NStr("en = 'No invoices '; ru = 'Нет накладных типа '") + docType);
	EndIf;

	// 3. Применить сопутствующие обновления справочников
	If parseResult.EntityUpsert.Count() > 0 Then
		like_Adapter.WriteEntities(parseResult.EntityUpsert);
	EndIf;

	If parseResult.Invoices.Count() = 0 Then
		Return New Structure("success, errorString", False,
			NStr("en = 'No invoices '; ru = 'Нет накладных типа '") + docType);
	EndIf;

	Return New Structure("success, returnValue", True, parseResult.Invoices);

EndFunction

Function FindByCodeAndConnection(CatalogName, code) Export
	
	FindQuery = New Query("SELECT
	                      |	like_catalog.UUID AS UUID
	                      |FROM
	                      |	Catalog.[catalogName] AS like_catalog
	                      |WHERE
	                      |	like_catalog.Code = &Code
	                      |	AND like_catalog.connection = &connection");
	FindQuery.Text = StrReplace(FindQuery.Text, "[catalogName]", CatalogName);
	FindQuery.SetParameter("Code", code);
	FindQuery.SetParameter("connection", like_ConnectionAtServer.GetActiveConnecton());
	FindSelection = FindQuery.Execute().Select();
	If Not FindSelection.Next() Then
		Return "";
	EndIf;
	Return FindSelection.UUID;
	
EndFunction

Function GetInvoiceNumberAndID(connection, ref1C) Export
	
	foundMatch = like_DocumentAtServer.GetDocumentMatching(ref1C);
	
	If foundMatch = Undefined Then
		Return New Structure("id, number, documentData, isNew",
							String(New UUID), like_Common.Translit(ref1C.Number), Undefined, True);
	EndIf;
						
	documentData = like_DocumentAtServer.GetDocumentDateCreatedAndUUID(foundMatch);
	
	If documentData = Undefined Then
		Return New Structure("id, number, documentData, isNew",
							String(New UUID),
							foundMatch.number,
							Undefined,
							True);	
	EndIf;
	
	Return New Structure("id, number, documentData, isNew",
							documentData.id,
							documentData.documentNumber,
							documentData,
							False);
	
EndFunction

Function GetIncomingInvoicesRequisites(documentsList) Export 
	
	tableManager = New TempTablesManager;
	requisitesQuery = New Query;
	requisitesQuery.TempTablesManager = tableManager;
	requisitesQuery.Text = "SELECT DISTINCT
   |	PurchaseGoodsServices.Партнер AS ref1C,
   |	VALUE(Enum.like_matchingTypes.EmptyRef) AS mType
   |INTO typeDependentRequisites
   |FROM
   |	Document.ПриобретениеТоваровУслуг AS PurchaseGoodsServices
   |WHERE
   |	PurchaseGoodsServices.Ref IN(&invoicesList)
   |
   |UNION
   |
   |SELECT DISTINCT
   |	PurchaseGoodsServices.Склад,
   |	VALUE(Enum.like_matchingTypes.EmptyRef)
   |FROM
   |	Document.ПриобретениеТоваровУслуг AS PurchaseGoodsServices
   |WHERE
   |	PurchaseGoodsServices.Ref IN(&invoicesList)
   |;
   |
   |////////////////////////////////////////////////////////////////////////////////
   |SELECT DISTINCT
   |	Goods.Номенклатура AS ref1C
   |INTO typeUndependentRequisites
   |FROM
   |	Document.ПриобретениеТоваровУслуг.Товары AS Goods
   |WHERE
   |	Goods.Ref IN(&invoicesList)
   |
   |UNION
   |
   |SELECT DISTINCT
   |	Goods.Номенклатура.ЕдиницаИзмерения
   |FROM
   |	Document.ПриобретениеТоваровУслуг.Товары AS Goods
   |WHERE
   |	Goods.Ref IN(&invoicesList)";
	requisitesQuery.SetParameter("invoicesList", documentsList);
	requisitesQuery.Execute();
	
	Return tableManager;
	
EndFunction

Function GetSaleOfGoodsDocumentRequisites(documentsList) Export

	matchingTypes = ShipmentOfGoodsFromStorageMatchingTypes();
	
	tableManager = New TempTablesManager;
	requisitesQuery = New Query;
	requisitesQuery.TempTablesManager = tableManager;
	requisitesQuery.SetParameter("documentsList", documentsList);
	requisitesQuery.SetParameter("matchingTypes", matchingTypes);
	requisitesQuery.Text = "SELECT
	|	mTypes.matchingType AS mType
	|INTO tmpMatchingTypes
	|FROM
	|	&matchingTypes AS mTypes
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	SaleOfGoods.Партнер AS ref1C,
	|	mTypes.mType AS mType
	|INTO typeDependentRequisites
	|FROM
	|	Document.РеализацияТоваровУслуг AS SaleOfGoods,
	|	tmpMatchingTypes AS mTypes
	|WHERE
	|	SaleOfGoods.Ref IN(&documentsList)
	|
	|UNION
	|
	|SELECT DISTINCT
	|	SaleOfGoods.Контрагент,
	|	VALUE(Enum.like_matchingTypes.EmptyRef)
	|FROM
	|	Document.РеализацияТоваровУслуг AS SaleOfGoods
	|WHERE
	|	SaleOfGoods.Ref IN(&documentsList)
	|
	|UNION
	|
	|SELECT DISTINCT
	|	SaleOfGoods.Организация,
	|	VALUE(Enum.like_matchingTypes.EmptyRef)
	|FROM
	|	Document.РеализацияТоваровУслуг AS SaleOfGoods
	|WHERE
	|	SaleOfGoods.Ref IN(&documentsList)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Goods.Номенклатура AS ref1C
	|INTO typeUndependentRequisites
	|FROM
	|	Document.РеализацияТоваровУслуг.Товары AS Goods
	|WHERE
	|	Goods.Ref IN(&documentsList)
	|
	|UNION
	|
	|SELECT DISTINCT
	|	CASE
	|		WHEN Goods.Номенклатура.ВесИспользовать
	|			THEN Goods.Номенклатура.ВесЕдиницаИзмерения
	|		ELSE Goods.Номенклатура.ЕдиницаИзмерения
	|	END
	|FROM
	|	Document.РеализацияТоваровУслуг.Товары AS Goods
	|WHERE
	|	Goods.Ref IN(&documentsList)";
	requisitesQuery.Execute();
	
	Return tableManager;
	
EndFunction

Function ShipmentOfGoodsFromStorageMatchingTypes() Export

	matchingTypes =
		like_TypesAndDescriptionsAtServer.GetTableWithColumns("matchingType;matchingTypes");
		
	newMatchingType = matchingTypes.Add();
	newMatchingType.matchingType = Enums.like_matchingTypes.EmptyRef();
	
	newMatchingType = matchingTypes.Add();
	newMatchingType.matchingType = Enums.like_matchingTypes.partnerConception;
	
	Return matchingTypes;

EndFunction

Function ShipmentOfGoodsFromStorageRequisites(documentsList) Export
	
	matchingTypes = ShipmentOfGoodsFromStorageMatchingTypes();
	
	tableManager = New TempTablesManager;
	requisitesQuery = New Query;
	requisitesQuery.TempTablesManager = tableManager;
	requisitesQuery.SetParameter("documentsList", documentsList);
	requisitesQuery.SetParameter("matchingTypes", matchingTypes);
	requisitesQuery.Text = "SELECT
   |	mTypes.matchingType AS mType
   |INTO tmpMatchingTypes
   |FROM
   |	&matchingTypes AS mTypes
   |;
   |
   |////////////////////////////////////////////////////////////////////////////////
   |SELECT DISTINCT
   |	ShipmentOfGoods.Партнер AS ref1C,
   |	mTypes.mType AS mType
   |INTO typeDependentRequisites
   |FROM
   |	Document.ОтгрузкаТоваровСХранения AS ShipmentOfGoods,
   |	tmpMatchingTypes AS mTypes
   |WHERE
   |	ShipmentOfGoods.Ref IN(&documentsList)
   |
   |UNION
   |
   |SELECT DISTINCT
   |	ShipmentOfGoods.Склад,
   |	VALUE(Enum.like_matchingTypes.EmptyRef)
   |FROM
   |	Document.ОтгрузкаТоваровСХранения AS ShipmentOfGoods
   |WHERE
   |	ShipmentOfGoods.Ref IN(&documentsList)
   |;
   |
   |////////////////////////////////////////////////////////////////////////////////
   |SELECT DISTINCT
   |	Goods.Номенклатура AS ref1C
   |INTO typeUndependentRequisites
   |FROM
   |	Document.ОтгрузкаТоваровСХранения.Товары AS Goods
   |WHERE
   |	Goods.Ref IN(&documentsList)
   |
   |UNION
   |
   |SELECT DISTINCT
   |	Goods.Номенклатура.ЕдиницаИзмерения
   |FROM
   |	Document.ОтгрузкаТоваровСХранения.Товары AS Goods
   |WHERE
   |	Goods.Ref IN(&documentsList)";
	requisitesQuery.Execute();
	         
	Return tableManager;
	
EndFunction

Function GetIncomingInvoiceXDTO(ref1C, documentStructure, matchedObjects) Export
	                                           
	document 						= like_CreatingObjects.CreateXDTOObject("invoiceType");
	document.cls 					= "IncomingInvoice";
	document.eid 					= documentStructure.id;
	document.incomingDocumentNumber = ref1C.НомерВходящегоДокумента;   
	document.supplier 				= like_CommonAtServer.GetMatchedObject(matchedObjects, ref1C.Партнер).UUID;
	document.defaultStore 			= like_CommonAtServer.GetMatchedObject(matchedObjects, ref1C.Склад).UUID;
	document.dateIncoming 			= Format(ref1C.Дата,"DF=yyyy-MM-ddTHH:mm:ss.000+03.00");
	document.documentNumber			= documentStructure.number;
	document.status 				= "NEW";
	document.comment 				= "Создана Лайкой. " + ref1C.Комментарий;
	document.id 					= documentStructure.id;
	
	tsNotes = like_CreatingObjects.CreateXDTOObject("invoiceItemsType");
	ppNumber  = 0;
	
	For each product In ref1C.Товары Do
		likeProduct = like_CommonAtServer.GetMatchedObject(matchedObjects, product.Номенклатура);
		If likeProduct = Undefined Then
			Continue;
		EndIf;
		
		ppNumber = ppNumber + 1;                           
		
		note = like_CreatingObjects.CreateXDTOObject("invoiceItemType");
		note.cls 			 = "IncomingInvoiceItem";
		elementID 			 = String(New UUID);
		note.eid 			 = elementID;
		note.store		 	 = like_CommonAtServer.GetMatchedObject(matchedObjects, product.Склад).UUID;
		note.code 		 	 = likeProduct.code;
		note.sum			 = product.СуммаСНДС;
		note.ndsPercent 	 = УчетНДСПереопределяемый.ПолучитьСтавкуНДС(product.СтавкаНДС);
		note.sumWithoutNds 	 = product.Сумма;
		note.price		 	 = product.Цена;
		note.priceWithoutNds = Round(note.sumWithoutNds/product.Количество, 2);
		
		incomingInvoiceRef 	 	= like_CreatingObjects.CreateXDTOObject("invoiceItemInvoiceType");
		incomingInvoiceRef.cls 	= "IncomingInvoice";
		incomingInvoiceRef.eid 	= documentStructure.id;
		
		note.invoice 		= incomingInvoiceRef;
		note.discountSum	= 0;
		note.actualAmount 	= product.Количество;
		note.amountUnit 	= like_CommonAtServer.GetMatchedObject(matchedObjects, product.Номенклатура.ЕдиницаИзмерения).UUID;
		note.num 			= ppNumber;
		note.product 		= likeProduct.UUID;
		note.amount 		= product.Количество;
		note.id 			= elementID;
		
		tsNotes.i.Add(note);
	EndDo;		
	                
	document.items = tsNotes;
	Return document;
	
EndFunction

Function IncomingInvoiceXDTOBySalesDocument(ref1C, documentStructure, matchedObjects) Export

	document 						= like_CreatingObjects.CreateXDTOObject("invoiceType");
	document.cls 					= "IncomingInvoice";
	document.eid 					= documentStructure.id;
	document.supplier 				= like_CommonAtServer.GetMatchedObject(matchedObjects, ref1C.Организация).UUID;
	document.defaultStore 			= like_CommonAtServer.GetMatchedObject(matchedObjects, ref1C.Контрагент).UUID;
	document.dateIncoming 			= Format(ref1C.Дата,"DF=yyyy-MM-ddTHH:mm:ss.000+03.00");
	document.documentNumber			= documentStructure.number;
	document.status 				= "NEW";
	conception = like_CommonAtServer.GetMatchedObject(matchedObjects, 
		ref1C.Партнер,
		Enums.like_matchingTypes.partnerConception).UUID; 
	document.conception				= conception;
	document.comment 				= "Создана Лайкой. " + ref1C.Комментарий;
	document.id 					= documentStructure.id;

	tsNotes = like_CreatingObjects.CreateXDTOObject("invoiceItemsType");
	ppNumber  = 0;
	
	For each product In ref1C.Товары Do
		likeProduct = like_CommonAtServer.GetMatchedObject(matchedObjects, product.Номенклатура);
		If likeProduct = Undefined Then
			Continue;
		EndIf;

		ppNumber = ppNumber + 1;

		note = like_CreatingObjects.CreateXDTOObject("invoiceItemType");
		note.cls 			 = "IncomingInvoiceItem";
		elementID 			 = String(New UUID);
		note.eid 			 = elementID;
		note.store			 = document.defaultStore;
		note.code 		 	 = likeProduct.code;
		note.sum			 = product.СуммаСНДС;
		note.ndsPercent 	 = УчетНДСПереопределяемый.ПолучитьСтавкуНДС(product.СтавкаНДС);
		note.sumWithoutNds 	 = product.Сумма;
		
		If product.Номенклатура.ВесИспользовать Then	
			note.amount = (product.Количество * product.Номенклатура.ВесЧислитель) / product.Номенклатура.ВесЗнаменатель;
			productAmountUnit = product.Номенклатура.ВесЕдиницаИзмерения; 	
		Else	
			note.amount 	  = product.Количество;
			productAmountUnit = product.Номенклатура.ЕдиницаИзмерения;	
		EndIf;
		
		note.actualAmount = note.amount;
		note.amountUnit   = like_CommonAtServer.GetMatchedObject(matchedObjects, productAmountUnit).UUID;
		
		note.price		 	 = Round(note.sum / note.amount, 2);
		note.priceWithoutNds = Round(note.sumWithoutNds / note.amount, 2);

		incomingInvoiceRef 	 	= like_CreatingObjects.CreateXDTOObject("invoiceItemInvoiceType");
		incomingInvoiceRef.cls 	= "IncomingInvoice";
		incomingInvoiceRef.eid 	= documentStructure.id;

		note.invoice 		= incomingInvoiceRef;
		note.discountSum	= 0;
		note.num 			= ppNumber;
		note.product 		= likeProduct.UUID;
		note.id 			= elementID;

		tsNotes.i.Add(note);
	EndDo;

	document.items = tsNotes;
	Return document;

EndFunction

Function IncomingInvoiceXDTOByShipmentOfGoods(ref1C, documentStructure, matchedObjects) Export
	
	document 						= like_CreatingObjects.CreateXDTOObject("invoiceType");
	document.cls 					= "IncomingInvoice";
	document.eid 					= documentStructure.id;
	document.supplier 				= like_CommonAtServer.GetMatchedObject(matchedObjects, ref1C.Партнер).UUID;
	document.defaultStore 			= like_CommonAtServer.GetMatchedObject(matchedObjects, ref1C.Склад).UUID;
	document.dateIncoming 			= Format(ref1C.Дата,"DF=yyyy-MM-ddTHH:mm:ss.000+03.00");
	document.documentNumber			= documentStructure.number;
	document.status 				= "NEW";
	conception = like_CommonAtServer.GetMatchedObject(matchedObjects, 
		ref1C.Партнер,
		Enums.like_matchingTypes.partnerConception).UUID; 
	document.conception				= conception;
	document.comment 				= "Создана Лайкой. " + ref1C.Комментарий;
	document.id 					= documentStructure.id;
	
	tsNotes = like_CreatingObjects.CreateXDTOObject("invoiceItemsType");
	ppNumber  = 0;
	
	For each product In ref1C.Товары Do
		likeProduct = like_CommonAtServer.GetMatchedObject(matchedObjects, product.Номенклатура);
		If likeProduct = Undefined Then
			Continue;
		EndIf;
		
		ppNumber = ppNumber + 1;                           
		
		note = like_CreatingObjects.CreateXDTOObject("invoiceItemType");
		note.cls 			 = "IncomingInvoiceItem";
		elementID 			 = String(New UUID);
		note.eid 			 = elementID;
		note.store		 	 = like_CommonAtServer.GetMatchedObject(matchedObjects, product.Склад).UUID;
		note.code 		 	 = likeProduct.code;
		note.sum			 = product.СуммаСНДС;
		note.ndsPercent 	 = УчетНДСПереопределяемый.ПолучитьСтавкуНДС(product.СтавкаНДС);
		note.sumWithoutNds 	 = product.Сумма;
		note.price		 	 = product.Цена;
		note.priceWithoutNds = Round(note.sumWithoutNds/product.Количество, 2);
		
		incomingInvoiceRef 	 	= like_CreatingObjects.CreateXDTOObject("invoiceItemInvoiceType");
		incomingInvoiceRef.cls 	= "IncomingInvoice";
		incomingInvoiceRef.eid 	= documentStructure.id;
		
		note.invoice 		= incomingInvoiceRef;
		note.discountSum	= 0;
		note.actualAmount 	= product.Количество;
		note.amountUnit 	= like_CommonAtServer.GetMatchedObject(matchedObjects, product.Номенклатура.ЕдиницаИзмерения).UUID;
		note.num 			= ppNumber;
		note.product 		= likeProduct.UUID;
		note.amount 		= product.Количество;
		note.id 			= elementID;
		
		tsNotes.i.Add(note);
	EndDo;		
	                
	document.items = tsNotes;
	Return document;
	
EndFunction

Procedure SendInvoices2IIKO(invoicesList) Export

	activeConnection = like_ConnectionAtServer.GetActiveConnecton();
	If activeConnection = Undefined Then
		Return;
	EndIf;

	If TypeOf(invoicesList[0]) = Type("DocumentRef.ПриобретениеТоваровУслуг") Then
		invoicesRequisitesTempTable = GetIncomingInvoicesRequisites(invoicesList);
	Else
		invoicesRequisitesTempTable = ShipmentOfGoodsFromStorageRequisites(invoicesList);
	EndIf;
	
	matchedObjects = like_DocumentAtServer.GetMatchedObjects(activeConnection, 
															 invoicesRequisitesTempTable,
															 DocTypeByDocumentsList(invoicesList));
	
	For Each invoice In invoicesList Do
		like_DocumentAtServer.SaveOrUpdateDocument(activeConnection, invoice, matchedObjects);	
	EndDo;

EndProcedure

Procedure SendSalesInvoices2IIKO(documentsList) Export

	activeConnection = like_ConnectionAtServer.GetActiveConnecton();
	If activeConnection = Undefined Then
		Return;
	EndIf;
	
	documentsRequisitesTempTable = GetSaleOfGoodsDocumentRequisites(documentsList);
	matchedObjects = like_DocumentAtServer.GetMatchedObjects(activeConnection, 
															 documentsRequisitesTempTable,
															 DocTypeByDocumentsList(documentsList));

	For Each document In documentsList Do
		like_DocumentAtServer.SaveOrUpdateDocument(activeConnection, document, matchedObjects);	
	EndDo;

EndProcedure

Function DocTypeByDocumentsList(documentsList) Export

	If documentsList.Count() = 0 Then
		Return Undefined;
	EndIf;

	If TypeOf(documentsList[0]) = Type("DocumentRef.ПриобретениеТоваровУслуг") Then
		Return "Приобретение";
	ElsIf TypeOf(documentsList[0]) = Type("DocumentRef.РеализацияТоваровУслуг") Then
		Return "Реализация";
	ElsIf TypeOf(documentsList[0]) = Type("DocumentRef.ОтгрузкаТоваровСХранения") Then
		Return "Отгрузка";
	Else
		Return Undefined;
	EndIf;

EndFunction

// Returns a Structure with invoicesList (ValueTable), sumSum, sumSumWithoutNds, count
// for loading into the form.
Function FetchInvoicesList(periodStart, periodEnd, loadIncoming, loadOutgoing) Export

	If Not (loadIncoming Or loadOutgoing) Then
		Return Undefined;
	EndIf;

	invoicesVT = like_InvoicesListColumns();
	incomingVT = invoicesVT.Copy();
	outgoingVT = invoicesVT.Copy();

	If loadIncoming Then
		FillInvoicesFromIIKO(incomingVT, periodStart, periodEnd, "INCOMING_INVOICE", 0);
	EndIf;
	If loadOutgoing Then
		FillInvoicesFromIIKO(outgoingVT, periodStart, periodEnd, "OUTGOING_INVOICE", 1);
	EndIf;

	concatenatedStores = invoicesVT.Copy(, "documentID, store");
	invoicesAndStores  = like_GetInvoicesAndStores(incomingVT, outgoingVT);
	like_FillConcatenatedStores(concatenatedStores, invoicesAndStores.storesVT);

	resultQuery = New Query("SELECT
	                         |	iVT.type AS type,
	                         |	iVT.documentID AS documentID,
	                         |	iVT.date AS date,
	                         |	iVT.counteragent AS counteragent,
	                         |	iVT.number AS number,
	                         |	iVT.documentSummary AS documentSummary,
	                         |	iVT.sum AS sum,
	                         |	iVT.processed AS processed,
	                         |	iVT.conception AS conception,
	                         |	iVT.comment AS comment,
	                         |	iVT.sumWithoutNds AS sumWithoutNds,
	                         |	iVT.invoiceIncomingNumber AS invoiceIncomingNumber,
	                         |	iVT.conceptionRef AS conceptionRef,
	                         |	iVT.counteragentRef AS counteragentRef
	                         |INTO tmpResultInvoices
	                         |FROM
	                         |	&iVT AS iVT
	                         |;
	                         |
	                         |////////////////////////////////////////////////////////////////////////////////
	                         |SELECT
	                         |	sVT.documentID AS documentID,
	                         |	sVT.store AS store
	                         |INTO tmpResultStores
	                         |FROM
	                         |	&sVT AS sVT
	                         |;
	                         |
	                         |////////////////////////////////////////////////////////////////////////////////
	                         |SELECT
	                         |	iVT.type,
	                         |	iVT.documentID,
	                         |	iVT.date,
	                         |	iVT.counteragent,
	                         |	iVT.number,
	                         |	iVT.documentSummary,
	                         |	iVT.sum,
	                         |	iVT.processed,
	                         |	iVT.conception,
	                         |	iVT.comment,
	                         |	iVT.sumWithoutNds,
	                         |	iVT.invoiceIncomingNumber,
	                         |	iVT.conceptionRef,
	                         |	iVT.counteragentRef,
	                         |	sVT.store
	                         |FROM
	                         |	tmpResultInvoices AS iVT
	                         |		INNER JOIN tmpResultStores AS sVT
	                         |		ON iVT.documentID = sVT.documentID");
	resultQuery.SetParameter("iVT", invoicesAndStores.invoicesVT);
	resultQuery.SetParameter("sVT", concatenatedStores);
	resultVT = resultQuery.ExecuteBatch()[2].Unload();
	resultVT.Sort("date Desc");

	Return New Structure("invoicesVT, sumSum, sumSumWithoutNds, count",
		resultVT,
		"Итого: " + resultVT.Total("sum"),
		"Итого: " + resultVT.Total("sumWithoutNds"),
		"Кол-во: " + resultVT.Count());

EndFunction

Function like_InvoicesListColumns()

	VT = New ValueTable;
	VT.Columns.Add("type",                  New TypeDescription("Number", New NumberQualifiers(1, 0, AllowedSign.Nonnegative)));
	VT.Columns.Add("documentID",            New TypeDescription("String", , New StringQualifiers(36)));
	VT.Columns.Add("date",                  New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	VT.Columns.Add("counteragent",          New TypeDescription("String", , New StringQualifiers(36)));
	VT.Columns.Add("number",                New TypeDescription("String", , New StringQualifiers(20)));
	VT.Columns.Add("documentSummary",       New TypeDescription("String", , New StringQualifiers(100)));
	VT.Columns.Add("sum",                   New TypeDescription("Number", New NumberQualifiers(10, 2)));
	VT.Columns.Add("processed",             New TypeDescription("Boolean"));
	VT.Columns.Add("conception",            New TypeDescription("String", , New StringQualifiers(36)));
	VT.Columns.Add("comment",               New TypeDescription("String", , New StringQualifiers(100)));
	VT.Columns.Add("sumWithoutNds",         New TypeDescription("Number", New NumberQualifiers(10, 2)));
	VT.Columns.Add("invoiceIncomingNumber", New TypeDescription("String", , New StringQualifiers(100)));
	VT.Columns.Add("assignedStoreUUID",     New TypeDescription("String", , New StringQualifiers(36)));
	VT.Columns.Add("conceptionRef");
	VT.Columns.Add("counteragentRef");
	VT.Columns.Add("store",                 New TypeDescription("String", , New StringQualifiers(100)));
	Return VT;

EndFunction

Procedure FillInvoicesFromIIKO(invoicesVT, periodStart, periodEnd, invoicesType, invoicesTypeNumber)

	invoicesRequest = GetInvoices(periodStart, EndOfDay(periodEnd), invoicesType);
	If Not invoicesRequest.success Then
		Return;
	EndIf;

	returnValue = invoicesRequest.returnValue;
	For Each invoiceData In returnValue Do
		stores = like_CoreAPI.SafeGet(invoiceData, "assignedStores", New Array);
		If stores.Count() = 0 Then
			stores = New Array;
			stores.Add("");
		EndIf;
		For Each storeUUID In stores Do
			row = invoicesVT.Add();
			row.documentID            = like_CoreAPI.SafeGet(invoiceData, "documentID", "");
			row.date                  = like_Common.iikoDateTimeTo1C(like_CoreAPI.SafeGet(invoiceData, "date", ""));
			row.number                = like_CoreAPI.SafeGet(invoiceData, "number", "");
			row.type                  = invoicesTypeNumber;
			row.documentSummary       = like_CoreAPI.SafeGet(invoiceData, "documentSummary", "");
			row.comment               = like_CoreAPI.SafeGet(invoiceData, "comment", "");
			row.counteragent          = like_CoreAPI.SafeGet(invoiceData, "counteragent", "");
			row.conception            = like_CoreAPI.SafeGet(invoiceData, "conception", "");
			row.sum                   = Number(like_CoreAPI.SafeGet(invoiceData, "sum", "0"));
			row.sumWithoutNds         = Number(like_CoreAPI.SafeGet(invoiceData, "sumWithoutNds", "0"));
			row.processed             = like_CoreAPI.SafeGet(invoiceData, "processed", False);
			row.invoiceIncomingNumber = like_CoreAPI.SafeGet(invoiceData, "invoiceIncomingNumber", "");
			row.assignedStoreUUID     = storeUUID;
		EndDo;
	EndDo;

EndProcedure

Function like_GetInvoicesAndStores(incomingVT, outgoingVT)

	invoicesQuery = New Query("SELECT
	                          |	iiVT.type AS type,
	                          |	iiVT.documentID AS documentID,
	                          |	iiVT.date AS date,
	                          |	iiVT.counteragent AS counteragent,
	                          |	iiVT.number AS number,
	                          |	iiVT.documentSummary AS documentSummary,
	                          |	iiVT.sum AS sum,
	                          |	iiVT.processed AS processed,
	                          |	iiVT.conception AS conception,
	                          |	iiVT.comment AS comment,
	                          |	iiVT.sumWithoutNds AS sumWithoutNds,
	                          |	iiVT.invoiceIncomingNumber AS invoiceIncomingNumber,
	                          |	iiVT.assignedStoreUUID AS assignedStoreUUID
	                          |INTO tmpIncomingInvoices
	                          |FROM
	                          |	&incomingVT AS iiVT
	                          |;
	                          |
	                          |////////////////////////////////////////////////////////////////////////////////
	                          |SELECT
	                          |	oiVT.type AS type,
	                          |	oiVT.documentID AS documentID,
	                          |	oiVT.date AS date,
	                          |	oiVT.counteragent AS counteragent,
	                          |	oiVT.number AS number,
	                          |	oiVT.documentSummary AS documentSummary,
	                          |	oiVT.sum AS sum,
	                          |	oiVT.processed AS processed,
	                          |	oiVT.conception AS conception,
	                          |	oiVT.comment AS comment,
	                          |	oiVT.sumWithoutNds AS sumWithoutNds,
	                          |	oiVT.invoiceIncomingNumber AS invoiceIncomingNumber,
	                          |	oiVT.assignedStoreUUID AS assignedStoreUUID
	                          |INTO tmpOutgoingInvoices
	                          |FROM
	                          |	&outgoingVT AS oiVT
	                          |;
	                          |
	                          |////////////////////////////////////////////////////////////////////////////////
	                          |SELECT
	                          |	t.type, t.documentID, t.date, t.counteragent, t.number,
	                          |	t.documentSummary, t.sum, t.processed, t.conception,
	                          |	t.comment, t.sumWithoutNds, t.invoiceIncomingNumber,
	                          |	t.assignedStoreUUID
	                          |INTO tmpInvoices
	                          |FROM
	                          |	tmpIncomingInvoices AS t
	                          |
	                          |UNION
	                          |
	                          |SELECT
	                          |	t.type, t.documentID, t.date, t.counteragent, t.number,
	                          |	t.documentSummary, t.sum, t.processed, t.conception,
	                          |	t.comment, t.sumWithoutNds, t.invoiceIncomingNumber,
	                          |	t.assignedStoreUUID
	                          |FROM
	                          |	tmpOutgoingInvoices AS t
	                          |;
	                          |
	                          |////////////////////////////////////////////////////////////////////////////////
	                          |SELECT DISTINCT
	                          |	iVT.type AS type,
	                          |	iVT.documentID AS documentID,
	                          |	iVT.date AS date,
	                          |	iVT.counteragent AS counteragent,
	                          |	iVT.number AS number,
	                          |	iVT.documentSummary AS documentSummary,
	                          |	iVT.sum AS sum,
	                          |	iVT.processed AS processed,
	                          |	iVT.conception AS conception,
	                          |	CASE
	                          |		WHEN iVT.comment = ""ОбъектXDTO""
	                          |				OR iVT.comment = ""XDTODataObject""
	                          |			THEN """"
	                          |		ELSE iVT.comment
	                          |	END AS comment,
	                          |	iVT.sumWithoutNds AS sumWithoutNds,
	                          |	CASE
	                          |		WHEN iVT.invoiceIncomingNumber = ""ОбъектXDTO""
	                          |				OR iVT.invoiceIncomingNumber = ""XDTODataObject""
	                          |			THEN """"
	                          |		ELSE iVT.invoiceIncomingNumber
	                          |	END AS invoiceIncomingNumber,
	                          |	Conceptions.Ref AS conceptionRef,
	                          |	Counteragents.Ref AS counteragentRef
	                          |INTO Invoices
	                          |FROM
	                          |	tmpInvoices AS iVT
	                          |		LEFT JOIN Catalog.like_conceptions AS Conceptions
	                          |		ON iVT.conception = Conceptions.UUID
	                          |		INNER JOIN Catalog.like_users AS Counteragents
	                          |		ON iVT.counteragent = Counteragents.UUID
	                          |;
	                          |
	                          |////////////////////////////////////////////////////////////////////////////////
	                          |SELECT
	                          |	iVT.documentID AS documentID,
	                          |	Stores.Ref AS storeRef
	                          |FROM
	                          |	tmpInvoices AS iVT
	                          |		INNER JOIN Catalog.like_stores AS Stores
	                          |		ON iVT.assignedStoreUUID = Stores.UUID");
	invoicesQuery.SetParameter("incomingVT", incomingVT);
	invoicesQuery.SetParameter("outgoingVT", outgoingVT);
	iqResult = invoicesQuery.ExecuteBatchWithIntermediateData();
	Return New Structure("invoicesVT, storesVT", iqResult[3].Unload(), iqResult[4].Unload());

EndFunction

Procedure like_FillConcatenatedStores(concatenatedStores, storesVT)

	invoicesIDs = storesVT.Copy(, "documentID");
	invoicesIDs.GroupBy("documentID");
	For Each strInvoiceID In invoicesIDs Do
		invoiceStores = storesVT.FindRows(New Structure("documentID", strInvoiceID.documentID));
		stores = New Array;
		For Each invoiceStore In invoiceStores Do
			stores.Add(invoiceStore.storeRef);
		EndDo;
		newString = concatenatedStores.Add();
		newString.documentID = strInvoiceID.documentID;
		newString.store = StrConcat(stores, ", ");
	EndDo;

EndProcedure