#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	documentsListRef = ThisForm.Parameters.documentsListRef;
	documentsList    = GetFromTempStorage(ThisForm.Parameters.documentsListRef);

	If documentsList.Count() = 0 Then
		Return;
	EndIf;

	activeConnection = like_ConnectionAtServer.GetActiveConnecton();

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
	suppliersStores.Load(	GetUnmatchedItemsByType(unmatchedObjects, Type("CatalogRef.Партнеры")));
	
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
	ThisForm.Close();
	Notify("EndOfMatching", documentsListRef);

EndProcedure

&AtClient
Procedure CancelChanges(Command)

	ThisForm.Close();

EndProcedure

#EndRegion

#Region Private

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
Procedure SaveTableValuesToRegister(connection, table, docType = "", matchingType = Undefined)

	If Not ValueIsFilled(matchingType) Then
		matchingType = Enums.like_matchingTypes.EmptyRef();
	EndIf;
	
	For Each Row In table Do
		InformationRegisters.like_objectMatching.MatchingAdd(connection, Row.ref1C, Row.likeRef, docType, matchingType);	
	EndDo;

EndProcedure

&AtServer
Procedure SaveValuesAtServer()

	connection = like_ConnectionAtServer.GetActiveConnecton();

	SaveTableValuesToRegister(connection, measureUnits);
	SaveTableValuesToRegister(connection, products);

	If docType = "Приобретение" Then
		SaveTableValuesToRegister(connection, stores,	 docType);
		SaveTableValuesToRegister(connection, suppliers, docType);
	ElsIf docType = "Отгрузка" Then
		SaveTableValuesToRegister(connection, stores,	 docType);
		SaveTableValuesToRegister(connection, suppliers, docType);
		SaveTableValuesToRegister(connection, suppliersConceptions, docType, Enums.like_matchingTypes.partnerConception);
	ElsIf docType = "Реализация" Then
		SaveTableValuesToRegister(connection, organizations,   docType);
		SaveTableValuesToRegister(connection, suppliersStores, docType);
		SaveTableValuesToRegister(connection, suppliersConceptions, docType, Enums.like_matchingTypes.partnerConception);
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