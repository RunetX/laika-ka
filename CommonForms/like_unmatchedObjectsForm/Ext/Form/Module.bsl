#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	documentsListRef = ThisForm.Parameters.documentsListRef;
	documentsList    = GetFromTempStorage(ThisForm.Parameters.documentsListRef);

	If Parameters.Property("sendAfterMatch") Then
		sendAfterMatch = Parameters.sendAfterMatch;
	EndIf;

	If documentsList.Count() = 0 Then
		Return;
	EndIf;

	activeConnection = like_ConnectionAtServer.GetActiveConnecton();
	SetConnectionFilter(activeConnection);

	If TypeOf(documentsList[0]) = Type("DocumentRef.ПриобретениеТоваровУслуг") Then

		unmatchedObjects = LoadUnmatchedIncomingInvoices(activeConnection, documentsList);	

	ElsIf TypeOf(documentsList[0]) = Type("DocumentRef.РеализацияТоваровУслуг") Then

		unmatchedObjects = LoadUnmatchedSaleOfGoodsDocument(activeConnection, documentsList);
		
	ElsIf TypeOf(documentsList[0]) = Type("DocumentRef.ОтгрузкаТоваровСХранения") Then

		unmatchedObjects = LoadUnmatchedShipmentOfGoodsFromStorage(activeConnection, documentsList);
		
	EndIf;

	measureUnits.Load(
		GetUnmatchedItemsByType(unmatchedObjects, 
			Type("CatalogRef.УпаковкиЕдиницыИзмерения")));
	products.Load(
		GetUnmatchedItemsByType(unmatchedObjects, 
			Type("CatalogRef.Номенклатура")));

EndProcedure

&AtServer
Function LoadUnmatchedIncomingInvoices(activeConnection, documentsList)
	
	tableManager = like_InvoicesAtServer.GetIncomingInvoicesRequisites(documentsList);
	docType = "Приобретение";

	unmatchedObjects = like_DocumentAtServer.GetUnmatchedObjects(activeConnection, tableManager, docType);

	stores.Load(		GetUnmatchedItemsByType(unmatchedObjects, Type("CatalogRef.Склады")));
	suppliers.Load(		GetUnmatchedItemsByType(unmatchedObjects, Type("CatalogRef.Партнеры")));
	
	Return unmatchedObjects;
	
EndFunction

&AtServer
Function LoadUnmatchedSaleOfGoodsDocument(activeConnection, documentsList)

	tableManager = like_InvoicesAtServer.GetSaleOfGoodsDocumentRequisites(documentsList);
	docType = "Реализация";

	unmatchedObjects = like_DocumentAtServer.GetUnmatchedObjects(activeConnection, tableManager, docType);

	organizations.Load(		GetUnmatchedItemsByType(unmatchedObjects, Type("CatalogRef.Организации")));
	suppliersStores.Load(	GetUnmatchedItemsByType(unmatchedObjects, Type("CatalogRef.Контрагенты")));
	
	unmatchedConceptions = GetUnmatchedItemsByType(unmatchedObjects,
		Type("CatalogRef.Партнеры"), 
		Enums.like_matchingTypes.partnerConception);
	suppliersConceptions.Load(unmatchedConceptions);
	
	Return unmatchedObjects;
	
EndFunction

&AtServer
Function LoadUnmatchedShipmentOfGoodsFromStorage(activeConnection, documentsList)
	
	tableManager = like_InvoicesAtServer.ShipmentOfGoodsFromStorageRequisites(documentsList);
	docType = "Отгрузка";
	
	unmatchedObjects = like_DocumentAtServer.GetUnmatchedObjects(activeConnection,
		tableManager,
		docType);

	unmatchedStores = GetUnmatchedItemsByType(unmatchedObjects, Type("CatalogRef.Склады"));	
	stores.Load(unmatchedStores);
	
	unmatchedSuppliers = GetUnmatchedItemsByType(unmatchedObjects, Type("CatalogRef.Партнеры"));
	suppliers.Load(unmatchedSuppliers);
	
	unmatchedConceptions = GetUnmatchedItemsByType(unmatchedObjects,
		Type("CatalogRef.Партнеры"), 
		Enums.like_matchingTypes.partnerConception);
	suppliersConceptions.Load(unmatchedConceptions);
	
	Return unmatchedObjects;
	
EndFunction

&AtClient
Procedure OnOpen(Cancel)

	Items.GroupMeasureUnits.Visible 		= measureUnits.Count()>0;
	Items.GroupProducts.Visible				= products.Count()>0;
	Items.GroupStores.Visible				= stores.Count()>0;
	Items.GroupSuppliers.Visible			= suppliers.Count()>0;
	Items.GroupSuppliersStores.Visible  	= suppliersStores.Count()>0;
	Items.GroupSuppliersConceptions.Visible = suppliersConceptions.Count()>0;
	Items.GroupOrganizations.Visible		= organizations.Count()>0;

EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SaveValues(Command)

	If AreThereUnmatched() Then
		Message(NStr("en = 'Please match all the values to continue'; ru = 'Сопоставьте, пожалуйста, все значения, чтобы продолжить'"));
		Return;
	EndIf;

	SaveValuesAtServer();

	If sendAfterMatch Then
		SendInvoicesAfterMatchAtServer(documentsListRef);
	EndIf;

	ThisForm.Close();
	Notify("EndOfMatching", documentsListRef);

EndProcedure

&AtClient
Procedure CancelChanges(Command)

	ThisForm.Close();

EndProcedure

&AtServer
Procedure MatchProductsByNumAtServer()
	
	adCode = ChartsOfCharacteristicTypes.ДополнительныеРеквизитыИСведения.FindByAttribute("ИдентификаторДляФормул", 
		"ДополнительныйКод2");
	productsList = products.Unload(, "ref1C");
	
	matchingQuery = New Query;
	matchingQuery.SetParameter("productsList", productsList);
	matchingQuery.SetParameter("Property", adCode);
	matchingQuery.Text = "SELECT
	|	Nomenclature.Ссылка AS Ref
	|INTO tmpNomenclature
	|FROM
	|	Catalog.Номенклатура AS Nomenclature
	|WHERE
	|	Nomenclature.Ссылка IN(&productsList)
	|;
	|////////////////////////////////////////////////////////////////////////////////;
	|SELECT
	|	tmpNomenclature.Ref AS Ref,
	|	NomenclatureAdditionalRequsities.Свойство AS Свойство,
	|	NomenclatureAdditionalRequsities.Значение AS Value
	|INTO tmpAdditionalRequsities
	|FROM
	|	tmpNomenclature AS tmpNomenclature
	|	LEFT JOIN Catalog.Номенклатура.ДополнительныеРеквизиты AS NomenclatureAdditionalRequsities
	|		ON tmpNomenclature.Ref = NomenclatureAdditionalRequsities.Ссылка
	|		AND (NomenclatureAdditionalRequsities.Свойство = &Property)
	|;
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	tmpAdditionalRequsities.Ref AS ref1C,
	|	like_products.Ref AS likeRef
	|FROM
	|	tmpAdditionalRequsities AS tmpAdditionalRequsities
	|		LEFT JOIN Catalog.like_products AS like_products
	|		ON (like_products.num = tmpAdditionalRequsities.Value)
	|		AND like_products.connection = &connection";
	matchingQuery.SetParameter("connection", like_ConnectionAtServer.GetActiveConnecton());
	matchingTable = matchingQuery.Execute().Unload();
	products.Load(matchingTable);
	
EndProcedure

&AtClient
Procedure MatchProductsByNum(Command)
	MatchProductsByNumAtServer();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConnectionFilter(activeConnection)
	connectionParam = New ChoiceParameter("Filter.connection", activeConnection);

	likeRefFields = New Array;
	likeRefFields.Add("storeslikeRef");
	likeRefFields.Add("measureUnitslikeRef");
	likeRefFields.Add("supplierslikeRef");
	likeRefFields.Add("suppliersStoreslikeRef");
	likeRefFields.Add("suppliersConceptionslikeRef");
	likeRefFields.Add("organizationslikeRef");

	For Each fieldName In likeRefFields Do
		formItem = Items.Find(fieldName);
		If formItem = Undefined Then
			Continue;
		EndIf;
		existingParams = New Array;
		For Each param In formItem.ChoiceParameters Do
			existingParams.Add(param);
		EndDo;
		existingParams.Add(connectionParam);
		formItem.ChoiceParameters = New FixedArray(existingParams);
		formItem.ChoiceHistoryOnInput = ChoiceHistoryOnInput.DontUse;
	EndDo;

	// products — ChoiceForm = ListForm, т.к. ChoiceParameters не фильтрует автоформу выбора
	productsField = Items.Find("productslikeRef");
	If productsField <> Undefined Then
		productsField.ChoiceForm = "Catalog.like_products.Form.ListForm";
		productsField.ChoiceHistoryOnInput = ChoiceHistoryOnInput.DontUse;
	EndIf;
EndProcedure

&AtServerNoContext
Procedure SendInvoicesAfterMatchAtServer(documentsListRef)

	documentsList = GetFromTempStorage(documentsListRef);

	If documentsList.Count() = 0 Then
		Return;
	EndIf;

	If TypeOf(documentsList[0]) = Type("DocumentRef.РеализацияТоваровУслуг") Then
		like_InvoicesAtServer.SendSalesInvoices2IIKO(documentsList);
	Else
		like_InvoicesAtServer.SendInvoices2IIKO(documentsList);
	EndIf;

EndProcedure

&AtServerNoContext
Function GetUnmatchedItemsByType(unmatchedObjects, typeFilter, matchingType = Undefined)
	
	If Not ValueIsFilled(matchingType) Then
		matchingType = Enums.like_matchingTypes.EmptyRef();
	EndIf;
	
	typedQuery = New Query("SELECT
   |	uo.Ref1C AS Ref1C,
   |	uo.mType AS mType,
   |	uo.likeRef AS likeRef
   |INTO tmpUO
   |FROM
   |	&unmatchedObjects AS uo
   |;
   |
   |////////////////////////////////////////////////////////////////////////////////
   |SELECT
   |	tmpUO.Ref1C AS Ref1C,
   |	tmpUO.likeRef AS likeRef
   |FROM
   |	tmpUO AS tmpUO
   |WHERE
   |	VALUETYPE(tmpUO.Ref1C) = &typeFilter
   |	AND tmpUO.mType = &matchingType");
	typedQuery.SetParameter("unmatchedObjects", unmatchedObjects);
	typedQuery.SetParameter("typeFilter", typeFilter);
	typedQuery.SetParameter("matchingType", matchingType);
	Return typedQuery.Execute().Unload();
	
EndFunction

&AtServer
Procedure CollectMatchingsFromTable(allItems, connection, table, docType = "", matchingType = Undefined)

	If Not ValueIsFilled(matchingType) Then
		matchingType = Enums.like_matchingTypes.EmptyRef();
	EndIf;

	For Each Row In table Do
		If Not ValueIsFilled(Row.likeRef) Then
			Continue;
		EndIf;

		// Валидация: позиция IIKO не помечена на удаление
		likeObject = Row.likeRef.GetObject();
		If likeObject <> Undefined And likeObject.DeletionMark Then
			Message(NStr("ru = 'Позиция помечена на удаление в IIKO: '") + String(Row.likeRef));
			Continue;
		EndIf;

		item = New Map;
		item.Insert("ref1C",        String(Row.ref1C.UUID()));
		item.Insert("ref1CType",    like_Common.TypeNameShort(Row.ref1C));
		item.Insert("docType",      docType);
		item.Insert("matchingType", String(matchingType));
		item.Insert("likeRef",      String(Row.likeRef.UUID()));
		item.Insert("likeRefType",  like_Common.TypeNameShort(Row.likeRef));
		allItems.Add(item);

		// Локальный регистр (fallback)
		InformationRegisters.like_objectMatching.MatchingAdd(connection, Row.ref1C, Row.likeRef, docType, matchingType);
	EndDo;

EndProcedure

&AtServer
Procedure SaveValuesAtServer()

	connection = like_ConnectionAtServer.GetActiveConnecton();
	connectionID = String(connection.UUID());
	allItems = New Array;

	CollectMatchingsFromTable(allItems, connection, measureUnits);
	CollectMatchingsFromTable(allItems, connection, products);

	If docType = "Приобретение" Then
		CollectMatchingsFromTable(allItems, connection, stores, docType);
		CollectMatchingsFromTable(allItems, connection, suppliers, docType);
	ElsIf docType = "Отгрузка" Then
		CollectMatchingsFromTable(allItems, connection, stores, docType);
		CollectMatchingsFromTable(allItems, connection, suppliers, docType);
		CollectMatchingsFromTable(allItems, connection, suppliersConceptions, docType, Enums.like_matchingTypes.partnerConception);
	ElsIf docType = "Реализация" Then
		CollectMatchingsFromTable(allItems, connection, organizations, docType);
		CollectMatchingsFromTable(allItems, connection, suppliersStores, docType);
		CollectMatchingsFromTable(allItems, connection, suppliersConceptions, docType, Enums.like_matchingTypes.partnerConception);
	EndIf;

	// Один батч-запрос на Go сервис
	If allItems.Count() > 0 Then
		like_CoreAPI.SaveRefMatchings(connectionID, allItems);
	EndIf;

EndProcedure

&AtClient
Function AreThereUnmatchedInTheTable(table)

	If table.Count()=0 Then
		Return False;
	EndIf;

	foundValue = Undefined;
	For Each Row In table Do

		If Row.Property("likeRef", foundValue) And foundValue.isEmpty() Then
			Return True;
		EndIf;

	EndDo;

	Return False;

EndFunction

&AtClient
Function AreThereUnmatched()

	If docType = "Приобретение" Then
		
		Return AreThereUnmatchedInTheTable(measureUnits)
				Or AreThereUnmatchedInTheTable(products) 
				Or AreThereUnmatchedInTheTable(stores)
				Or AreThereUnmatchedInTheTable(suppliers);
				
	ElsIf docType = "Отгрузка" Then
		
		Return AreThereUnmatchedInTheTable(measureUnits)
				Or AreThereUnmatchedInTheTable(products)
				Or AreThereUnmatchedInTheTable(stores)
				Or AreThereUnmatchedInTheTable(suppliers)
				Or AreThereUnmatchedInTheTable(suppliersConceptions);
		
	Else
		
		Return AreThereUnmatchedInTheTable(measureUnits)
				Or AreThereUnmatchedInTheTable(products)
				Or AreThereUnmatchedInTheTable(organizations)
				Or AreThereUnmatchedInTheTable(suppliersStores)
				Or AreThereUnmatchedInTheTable(suppliersConceptions);
				
	EndIf;

EndFunction

#EndRegion