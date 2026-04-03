///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019-2023, Tian Semen Sergeevich (semen@tyan.pw), https://tyan.pw
// All rights reserved. This program and accompanying materials 
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

Function GetReadingDocumentXML(connection, documentId)
	
	argsType = XDTOFactory.Type("https://izi.cloud/iiko/reading/document", "args");
	args = XDTOFactory.Create(argsType); 
	
	eVersion = like_EntitiesAtServer.GetEntitiesVersion(connection);
	args.entities_version = eVersion;
	args.client_type 	  = "BACK";
	args.enable_warnings  = False;	
	args.request_watchdog_check_results = True;
	args.use_raw_entities = True;
	args.id 		  	  = documentId;	
	
	return like_CommonAtServer.XDTO2XML(args);
	
EndFunction

// GetDocumentRawXML возвращает сырой XML ответа IIKO для документа по ID.
// Заменяет GetDocument — парсинг выполняется на стороне сервиса через like_CoreAPI.
Function GetDocumentRawXML(documentId) Export

	ActiveConnection = like_ConnectionAtServer.GetActiveConnecton();
	If ActiveConnection = Undefined Then
		Return Undefined;
	EndIf;

	XMLPackage       = GetReadingDocumentXML(ActiveConnection, documentId);
	ConnectionFields = like_ConnectionAtServer.GetConnectionFields(ActiveConnection);

	ObjectFields = like_CommonAtServer.GetObjectFieldsStructure();
	ObjectFields.ConProps    = ConnectionFields;
	ObjectFields.Resource    = "/resto/services/document";
	ObjectFields.RequestType = "POST";
	ObjectFields.Headers     = like_Common.GetIikoHeaders(ConnectionFields);
	ObjectFields.Body        = XMLPackage;
	ObjectFields.isGZIP      = True;
	Params = New Map;
	Params.Insert("methodName", "getAbstractDocument");
	ObjectFields.Parameters  = Params;

	Return like_CommonAtServer.GetIikoRawXML(ObjectFields);

EndFunction

// GetDocument оставлен для обратной совместимости с формами, которые ещё не переведены.
// Будет удалён после полного рефакторинга форм.
Function GetDocument(documentId, namespace) Export

	ActiveConnection = like_ConnectionAtServer.GetActiveConnecton();
	If ActiveConnection = Undefined Then
		Return New Structure("success, errorString", False, "No active connection");
	EndIf;

	XMLPackage       = GetReadingDocumentXML(ActiveConnection, documentId);
	ConnectionFields = like_ConnectionAtServer.GetConnectionFields(ActiveConnection);

	ObjectFields = like_CommonAtServer.GetObjectFieldsStructure();
	ObjectFields.ConProps    = ConnectionFields;
	ObjectFields.Resource    = "/resto/services/document";
	ObjectFields.RequestType = "POST";
	ObjectFields.Headers     = like_Common.GetIikoHeaders(ConnectionFields);
	ObjectFields.Body        = XMLPackage;
	ObjectFields.isGZIP      = True;
	Params = New Map;
	Params.Insert("methodName", "getAbstractDocument");
	ObjectFields.Parameters  = Params;

	// Получаем сырой XML и отправляем на Go-сервис для парсинга.
	rawXML = like_CommonAtServer.GetIikoRawXML(ObjectFields);
	If rawXML = Undefined Then
		Return New Structure("success, errorString", False,
			NStr("en = 'Error receiving document from IIKO'; ru = 'Ошибка получения документа из IIKO'"));
	EndIf;

	parseResult = like_CoreAPI.ParseInvoice(rawXML);
	If Not parseResult.Success Then
		Return New Structure("success, errorString", False,
			NStr("en = 'Error parsing invoice'; ru = 'Ошибка разбора накладной'"));
	EndIf;

	// Применить сопутствующие обновления справочников.
	If parseResult.EntityUpsert.Count() > 0 Then
		like_Adapter.WriteEntities(parseResult.EntityUpsert);
	EndIf;

	Return New Structure("success, returnValue", True, parseResult.Invoice);

EndFunction

Function GetDocumentMatching(ref1C) Export
	
	matchingQuery = New Query;
	matchingQuery.Text = 
		"SELECT TOP 1
		|	like_documentsMatching.yearCreated AS yearCreated,
		|	like_documentsMatching.number AS number,
		|	like_documentsMatching.type AS type
		|FROM
		|	InformationRegister.like_documentsMatching AS like_documentsMatching
		|WHERE
		|	like_documentsMatching.ref1C = &ref1C";
	
	matchingQuery.SetParameter("ref1C", ref1C);
	queryResult = matchingQuery.Execute();
	selectionDetailRecords = queryResult.Select();
	
	If selectionDetailRecords.Next() Then
		Return selectionDetailRecords;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function GetDocumentTypeMatching(ref1C)
	
	If TypeOf(ref1C) = Type("DocumentRef.ПриобретениеТоваровУслуг") Then
		Return "IncomingInvoice";
	ElsIf TypeOf(ref1C) = Type("DocumentRef.РеализацияТоваровУслуг") Then
		Return "IncomingInvoice";
	EndIf;
	
	Return Undefined;
	
EndFunction

Function GetDocumentDateCreatedAndUUID(documentMatching) Export
	
	SQLQuery = "SELECT * FROM [doc_type] WHERE documentNumber='[doc_number]' AND status<>'2' AND (dateCreated BETWEEN('[year]0101 00:00:00.000') AND ('[year]1231 23:59:59.999'))";
	
	queryParameters = New Map;
	queryParameters.Insert("doc_type", 	documentMatching.type);
	queryParameters.Insert("doc_number",documentMatching.number);
	queryParameters.Insert("year", 		Format(documentMatching.yearCreated, "DF=yyyy"));
	
	entityObj = like_SQLRequestsAtServer.RequestSQL(SQLQuery, queryParameters);
	
	If entityObj = Undefined Then
		Return Undefined;
	EndIf;
	
	documentTable = like_TypesAndDescriptionsAtServer.GetTableWithColumns("id;UUID"+
																		  "|documentNumber;shortString"+
																		  "|dateCreated;shortString"+
																		  "|accountTo;UUID"+
																		  "|revenueAccount;UUID");	
	documentTable = like_SQLRequestsAtServer.SQLXDTO2Table(entityObj, documentTable);
	If documentTable.Count()=0 Then
		WriteLogEvent(NStr("en = 'Get IIKO document data'; ru = 'Получение данных о документе IIKO'"),
					 EventLogLevel.Error,,,
					 NStr("en = 'Failed to execute query to get document data by number '; 
						  |ru = 'Не удалось выполнить запрос на получение данных документа по номеру '")
					 + documentMatching.number);
		Return Undefined;
	EndIf;
	
	Возврат documentTable[0];
	
EndFunction

Function GetDocumentXDTO(connection, ref1C, matchedObjects)

	If TypeOf(ref1C) = Type("DocumentRef.ПриобретениеТоваровУслуг") Then
		documentStructure = like_InvoicesAtServer.GetInvoiceNumberAndID(connection, ref1C);
		Return like_InvoicesAtServer.GetIncomingInvoiceXDTO(ref1C, documentStructure, matchedObjects);
	ElsIf TypeOf(ref1C) = Type("DocumentRef.РеализацияТоваровУслуг") Then
		documentStructure = like_InvoicesAtServer.GetInvoiceNumberAndID(connection, ref1C);
		Return like_InvoicesAtServer.IncomingInvoiceXDTOBySalesDocument(ref1C, documentStructure, matchedObjects);
	ElsIf TypeOf(ref1C) = Type("DocumentRef.ОтгрузкаТоваровСХранения") Then
		documentStructure = like_InvoicesAtServer.GetInvoiceNumberAndID(connection, ref1C);
		Return like_InvoicesAtServer.IncomingInvoiceXDTOByShipmentOfGoods(ref1C, documentStructure, matchedObjects);
	Else
		Return Undefined;
	EndIf;

EndFunction

Function GetMatchedObjects(connection, tableManager, docType) Export

	matchedObjectsQuery = New Query;
	matchedObjectsQuery.TempTablesManager = tableManager;
	matchedObjectsQuery.Text = "SELECT
	                           |	typeDependentRequisites.ref1C AS ref1C,
							   |	typeDependentRequisites.mType AS mType,
	                           |	like_objectMatching.likeRef AS likeRef
	                           |FROM
	                           |	typeDependentRequisites AS typeDependentRequisites
	                           |		LEFT JOIN InformationRegister.like_objectMatching AS like_objectMatching
	                           |		ON typeDependentRequisites.ref1C = like_objectMatching.ref1C
							   |			AND typeDependentRequisites.mType = like_objectMatching.matchingType
	                           |			AND (like_objectMatching.connection = &connection)
	                           |			AND (like_objectMatching.docType = &docType)
	                           |
	                           |UNION
	                           |
	                           |SELECT
	                           |	typeUndependentRequisites.ref1C,
							   |  	VALUE(Enum.like_matchingTypes.EmptyRef),
	                           |	like_objectMatching.likeRef
	                           |FROM
	                           |	typeUndependentRequisites AS typeUndependentRequisites
	                           |		LEFT JOIN InformationRegister.like_objectMatching AS like_objectMatching
	                           |		ON typeUndependentRequisites.ref1C = like_objectMatching.ref1C
	                           |			AND (like_objectMatching.connection = &connection)";
	matchedObjectsQuery.SetParameter("connection", connection);
	matchedObjectsQuery.SetParameter("docType", docType);
	Return matchedObjectsQuery.Execute().Unload();

EndFunction

Function GetUnmatchedObjects(connection, tableManager, docType) Export
	
	unmatchedObjectsQuery = New Query;
	unmatchedObjectsQuery.TempTablesManager = tableManager;
	unmatchedObjectsQuery.Text = "SELECT
	                             |	typeDependentRequisites.ref1C AS ref1C,
								 |	typeDependentRequisites.mType AS mType,
	                             |	like_objectMatching.likeRef AS likeRef
	                             |FROM
	                             |	typeDependentRequisites AS typeDependentRequisites
	                             |		LEFT JOIN InformationRegister.like_objectMatching AS like_objectMatching
	                             |		ON typeDependentRequisites.ref1C = like_objectMatching.ref1C
								 |			AND typeDependentRequisites.mType = like_objectMatching.matchingType
	                             |			AND (like_objectMatching.connection = &connection)
	                             |			AND (like_objectMatching.docType = &docType)
	                             |WHERE
	                             |	like_objectMatching.likeRef IS NULL
	                             |
	                             |UNION
	                             |
	                             |SELECT
	                             |	typeUndependentRequisites.ref1C,
								 |  VALUE(Enum.like_matchingTypes.EmptyRef),
	                             |	like_objectMatching.likeRef
	                             |FROM
	                             |	typeUndependentRequisites AS typeUndependentRequisites
	                             |		LEFT JOIN InformationRegister.like_objectMatching AS like_objectMatching
	                             |		ON typeUndependentRequisites.ref1C = like_objectMatching.ref1C
	                             |			AND (like_objectMatching.connection = &connection)
	                             |WHERE
	                             |	like_objectMatching.likeRef IS NULL";
	unmatchedObjectsQuery.SetParameter("connection", connection);
	unmatchedObjectsQuery.SetParameter("docType", docType);
	Return unmatchedObjectsQuery.Execute().Unload();
	
EndFunction

Function GetUnmatchedCount(documentsList) Export
	
	If documentsList.Count() = 0 Then
		Return 0;
	EndIf;

	If TypeOf(documentsList[0]) = Type("DocumentRef.ПриобретениеТоваровУслуг") Then
		tableManager = like_InvoicesAtServer.GetIncomingInvoicesRequisites(documentsList);
		docType = "Приобретение";
	ElsIf TypeOf(documentsList[0]) = Type("DocumentRef.РеализацияТоваровУслуг") Then
		tableManager = like_InvoicesAtServer.GetSaleOfGoodsDocumentRequisites(documentsList);
		docType = "Реализация";
	ElsIf TypeOf(documentsList[0]) = Type("DocumentRef.ОтгрузкаТоваровСХранения") Then
		tableManager = like_InvoicesAtServer.ShipmentOfGoodsFromStorageRequisites(documentsList);
		docType = "Отгрузка";
	EndIf;
	
	connection = like_ConnectionAtServer.GetActiveConnecton();

	unmatchedObjects = GetUnmatchedObjects(connection, tableManager, docType);
	
	Return unmatchedObjects.Count();
	
EndFunction

Procedure SaveOrUpdateDocument(connection, ref1C, matchedObjects) Export
	
	iikoPackageObjectType = XDTOFactory.Type("https://izi.cloud/iiko/package", "args");
	iikoPackage = XDTOFactory.Create(iikoPackageObjectType);
	iikoPackage.entities_version 				= like_EntitiesAtServer.GetEntitiesVersion(connection);
	iikoPackage.client_type 	 				= "BACK";
	iikoPackage.enable_warnings  				= False;
	iikoPackage.request_watchdog_check_results 	= False;
	
	XMLParameters = like_CreatingObjects.GetXMLRequestParameters("saveOrUpdateDocument");

	Try
		iikoPackage.document = GetDocumentXDTO(connection, ref1C, matchedObjects);
	Except
		WriteLogEvent(NStr("en = 'IIKO document creating'; ru = 'Создание документа IIKO'"),
					 EventLogLevel.Error,
					 ref1C,
					 NStr("en = 'Failed to generate XDTO of IIKO document'; ru = 'Не удалось сформировать XDTO документа IIKO'") +
						ErrorDescription());
		Return;
	EndTry;
	
	result = like_CreatingObjects.SendPackage2IIKO(connection, XMLParameters, like_CommonAtServer.XDTO2XML(iikoPackage));
	
	If result = Undefined Then
		
		logString = NStr("en = 'Error creating/modifying document. See the log for details.'; 
|ru = 'Ошибка создания/изменения документа. См. детали в журнале регистрации'");
		like_Common.UsrMessage(logString);
		
		Return;
		
	EndIf;
	
	If result.success = "true" Then
		// AddDocumentMatching
		InformationRegisters.like_documentsMatching.MatchingAdd(connection, 
																ref1C, 
																New Structure("yearCreated,number,type",
																	BegOfYear(ref1C.Дата),
																	result.returnValue.documentNumber,
																	GetDocumentTypeMatching(ref1C)));
		logString = NStr("en = 'Document successfully created'; ru = 'Документ успешно изменен'") + " №" + result.returnValue.documentNumber;	
		WriteLogEvent(NStr("en = 'IIKO. document creating'; ru = 'Создание(изменение) документа IIKO'"),
						EventLogLevel.Information,
						ref1C,,
						logString);
		like_Common.UsrMessage(logString);
	Else
		logString = NStr("en = 'Failed to create IIKO document'; ru = 'Не удалось изменить документ IIKO'") + " " + result.errorString;
		WriteLogEvent(NStr("en = 'IIKO. document creating'; ru = 'Создание(изменение) документа IIKO'"),
						EventLogLevel.Error,
						ref1C,,
						logString);	
		like_Common.UsrMessage(logString);
	EndIf;
	
EndProcedure