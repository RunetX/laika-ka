///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021, ООО Изи Клауд, https://izi.cloud
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
	
	XMLPackage = getReadingInvoicesXML(ActiveConnection, dateFrom, dateTo, docType);	
	ConnectionFields = like_ConnectionAtServer.GetConnectionFields(ActiveConnection);
	
	ObjectFields = like_CommonAtServer.GetObjectFieldsStructure();
	ObjectFields.ConProps  	 = ConnectionFields;
	ObjectFields.Resource 	 = "/resto/services/document";
	ObjectFields.Namespace 	 = "https://izi.cloud/iiko/reading/invoicesResponse";
	ObjectFields.TypeName 	 = "result";
	ObjectFields.RequestType = "POST";
	Params = New Map;
	Params.Insert("methodName", "getIncomingDocumentsRecordsByDepartments");
	ObjectFields.Parameters  = Params;
	ObjectFields.Headers     = like_Common.GetIIKOHeaders(ConnectionFields);
	ObjectFields.Body		 = XMLPackage;
	ObjectFields.isGZIP		 = True;
	
	IIKOObject = like_CommonAtServer.GetIIKOObject(ObjectFields);	
	If IIKOObject = Undefined Then
		Return New Structure("success, errorString", False, NStr("en = 'Receiving data from IIKO server error'; ru = 'Ошибка получения данных с сервера IIKO'"));	
	EndIf;
	
	If IIKOObject.success Then
		updateItems = IIKOObject.entitiesUpdate.items;
		If updateItems.Properties().Get("i") <> Undefined Then
			like_EntitiesAtServer.ExeItems(updateItems.i, ActiveConnection, IIKOObject.entitiesUpdate.revision);
		EndIf;
		If IIKOObject.returnValue.Properties().Get("i") <> Undefined Then
			Return New Structure("success, returnValue", True, IIKOObject.returnValue.i);
		Else
			Return New Structure("success, errorString", False, NStr("en = 'No invoices '; ru = 'Нет накладных типа '") + docType);
		EndIf;
	Else
		Return New Structure("success, errorString", False, IIKOObject.errorString); 
	EndIf;	
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
	FindSelection.Next();
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
   |	Goods.Номенклатура.ЕдиницаИзмерения
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
	document.defaultStore 			= like_CommonAtServer.GetMatchedObject(matchedObjects, ref1C.Партнер).UUID;
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