&AtServerNoContext
Function GetUnmatchedItemsByType(unmatchedObjects, typeFilter)
	
	typedQuery = New Query("SELECT
	                       |	uo.Ref1C AS Ref1C,
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
	                       |	VALUETYPE(tmpUO.Ref1C) = &typeFilter");
	typedQuery.SetParameter("unmatchedObjects", unmatchedObjects);
	typedQuery.SetParameter("typeFilter", typeFilter);
	Return typedQuery.Execute().Unload();
	
EndFunction

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	documentsListRef = ThisForm.Parameters.documentsListRef;
	documentsList    = GetFromTempStorage(ThisForm.Parameters.documentsListRef);

	If documentsList.Count() = 0 Then
		Return;
	EndIf;

	activeConnection = like_ConnectionAtServer.GetActiveConnecton();

	If TypeOf(documentsList[0]) = Type("DocumentRef.ПриобретениеТоваровУслуг") Then

		tableManager = like_InvoicesAtServer.GetIncomingInvoicesRequisites(documentsList);
		matchingType = "Приобретение";

		unmatchedObjects = like_DocumentAtServer.GetUnmatchedObjects(activeConnection, tableManager, matchingType);

		stores.Load(		GetUnmatchedItemsByType(unmatchedObjects, Type("CatalogRef.Склады")));
		suppliers.Load(		GetUnmatchedItemsByType(unmatchedObjects, Type("CatalogRef.Контрагенты")));

	ElsIf TypeOf(documentsList[0]) = Type("DocumentRef.РеализацияТоваровУслуг") Then

		tableManager = like_InvoicesAtServer.GetSaleOfGoodsDocumentRequisites(documentsList);
		matchingType = "Реализация";

		unmatchedObjects = like_DocumentAtServer.GetUnmatchedObjects(activeConnection, tableManager, matchingType);

		organizations.Load(		GetUnmatchedItemsByType(unmatchedObjects, Type("CatalogRef.Организации")));
		suppliersStores.Load(	GetUnmatchedItemsByType(unmatchedObjects, Type("CatalogRef.Контрагенты")));
		
	ElsIf TypeOf(documentsList[0]) = Type("DocumentRef.ОтгрузкаТоваровСХранения") Then

		tableManager = like_InvoicesAtServer.ShipmentOfGoodsFromStorageRequisites(documentsList);
		matchingType = "Отгрузка";
		
		unmatchedObjects = like_DocumentAtServer.GetUnmatchedObjects(activeConnection, tableManager, matchingType);

		stores.Load(		GetUnmatchedItemsByType(unmatchedObjects, Type("CatalogRef.Склады")));
		suppliers.Load(		GetUnmatchedItemsByType(unmatchedObjects, Type("CatalogRef.Контрагенты")));
		
	EndIf;

	measureUnits.Load(
		GetUnmatchedItemsByType(unmatchedObjects, 
			Type("CatalogRef.УпаковкиЕдиницыИзмерения")));
	products.Load(
		GetUnmatchedItemsByType(unmatchedObjects, 
			Type("CatalogRef.Номенклатура")));

EndProcedure

&AtServer
Procedure SaveTableValuesToRegister(connection, table, docType = "")

	For Each Row In table Do
		InformationRegisters.like_objectMatching.MatchingAdd(connection, Row.ref1C, Row.likeRef, docType);	
	EndDo;

EndProcedure

&AtServer
Procedure SaveValuesAtServer()

	connection = like_ConnectionAtServer.GetActiveConnecton();

	SaveTableValuesToRegister(connection, measureUnits);
	SaveTableValuesToRegister(connection, products);

	If matchingType = "Приобретение" Or matchingType = "Отгрузка" Then
		SaveTableValuesToRegister(connection, stores,	 matchingType);
		SaveTableValuesToRegister(connection, suppliers, matchingType);
	ElsIf matchingType = "Реализация" Then
		SaveTableValuesToRegister(connection, organizations,   matchingType);
		SaveTableValuesToRegister(connection, suppliersStores, matchingType);
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

	If matchingType = "Приобретение" Or matchingType = "Отгрузка" Then
		Return AreThereUnmatchedInTheTable(measureUnits) Or
				AreThereUnmatchedInTheTable(products) Or
				AreThereUnmatchedInTheTable(stores) Or
				AreThereUnmatchedInTheTable(suppliers);
	Else
		Return AreThereUnmatchedInTheTable(measureUnits) Or
				AreThereUnmatchedInTheTable(products) Or
				AreThereUnmatchedInTheTable(organizations) Or
				AreThereUnmatchedInTheTable(suppliersStores);
	EndIf;

EndFunction

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

&AtClient
Procedure OnOpen(Cancel)

	Items.GroupMeasureUnits.Visible 	= measureUnits.Count()>0;
	Items.GroupProducts.Visible			= products.Count()>0;
	Items.GroupStores.Visible			= stores.Count()>0;
	Items.GroupSuppliers.Visible		= suppliers.Count()>0;
	Items.GroupSuppliersStores.Visible  = suppliersStores.Count()>0;
	Items.GroupOrganizations.Visible	= organizations.Count()>0;

EndProcedure
