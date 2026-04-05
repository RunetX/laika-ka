&AtServer
Function GetInvoicesAndStores(incomingInvoicesValueTable, outgoingInvoicesValueTable)
	
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
	                          |	&incomingInvoicesValueTable AS iiVT
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
	                          |	&outgoingInvoicesValueTable AS oiVT
	                          |;
	                          |
	                          |////////////////////////////////////////////////////////////////////////////////
	                          |SELECT
	                          |	tmpIncomingInvoices.type AS type,
	                          |	tmpIncomingInvoices.documentID AS documentID,
	                          |	tmpIncomingInvoices.date AS date,
	                          |	tmpIncomingInvoices.counteragent AS counteragent,
	                          |	tmpIncomingInvoices.number AS number,
	                          |	tmpIncomingInvoices.documentSummary AS documentSummary,
	                          |	tmpIncomingInvoices.sum AS sum,
	                          |	tmpIncomingInvoices.processed AS processed,
	                          |	tmpIncomingInvoices.conception AS conception,
	                          |	tmpIncomingInvoices.comment AS comment,
	                          |	tmpIncomingInvoices.sumWithoutNds AS sumWithoutNds,
	                          |	tmpIncomingInvoices.invoiceIncomingNumber AS invoiceIncomingNumber,
	                          |	tmpIncomingInvoices.assignedStoreUUID AS assignedStoreUUID
	                          |INTO tmpInvoices
	                          |FROM
	                          |	tmpIncomingInvoices AS tmpIncomingInvoices
	                          |
	                          |UNION
	                          |
	                          |SELECT
	                          |	tmpOutgoingInvoices.type,
	                          |	tmpOutgoingInvoices.documentID,
	                          |	tmpOutgoingInvoices.date,
	                          |	tmpOutgoingInvoices.counteragent,
	                          |	tmpOutgoingInvoices.number,
	                          |	tmpOutgoingInvoices.documentSummary,
	                          |	tmpOutgoingInvoices.sum,
	                          |	tmpOutgoingInvoices.processed,
	                          |	tmpOutgoingInvoices.conception,
	                          |	tmpOutgoingInvoices.comment,
	                          |	tmpOutgoingInvoices.sumWithoutNds,
	                          |	tmpOutgoingInvoices.invoiceIncomingNumber,
	                          |	tmpOutgoingInvoices.assignedStoreUUID
	                          |FROM
	                          |	tmpOutgoingInvoices AS tmpOutgoingInvoices
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
	invoicesQuery.SetParameter("incomingInvoicesValueTable", incomingInvoicesValueTable);
	invoicesQuery.SetParameter("outgoingInvoicesValueTable", outgoingInvoicesValueTable); 
	iqResult = invoicesQuery.ExecuteBatchWithIntermediateData();	
	Return New Structure("invoicesVT, storesVT", iqResult[3].Unload(), iqResult[4].Unload());	
	
EndFunction

&AtServer
Procedure FillConcatenatedStores(concatenatedStores, storesVT)
	
	invoicesIDs = storesVT.Copy(, "documentID");
	invoicesIDs.GroupBy("documentID");
	For each strInvoiceID In invoicesIDs Do
		invoiceStores = storesVT.FindRows(New Structure("documentID", strInvoiceID.documentID));
		stores = New Array;
		For each invoiceStore In invoiceStores Do
			stores.Add(invoiceStore.storeRef);	
		EndDo;
		newString = concatenatedStores.Add();
		newString.documentID = strInvoiceID.documentID;
		newString.store = StrConcat(stores, ", ");
	EndDo;
	
EndProcedure

&AtServer
Procedure FillCatalogsData(concatenatedStores, incomingInvoicesValueTable, outgoingInvoicesValueTable)
	
	invoicesAndStores  = GetInvoicesAndStores(incomingInvoicesValueTable, outgoingInvoicesValueTable);
	FillConcatenatedStores(concatenatedStores, invoicesAndStores.storesVT);
	invoicesQuery = New Query("SELECT
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
	                          |INTO tmpInvoices
	                          |FROM
	                          |	&iVT AS iVT
	                          |;
	                          |
	                          |////////////////////////////////////////////////////////////////////////////////
	                          |SELECT
	                          |	sVT.documentID AS documentID,
	                          |	sVT.store AS store
	                          |INTO tmpStores
	                          |FROM
	                          |	&sVT AS sVT
	                          |;
	                          |
	                          |////////////////////////////////////////////////////////////////////////////////
	                          |SELECT
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
	                          |	iVT.counteragentRef AS counteragentRef,
	                          |	sVT.store AS store
	                          |FROM
	                          |	tmpInvoices AS iVT
	                          |		INNER JOIN tmpStores AS sVT
	                          |		ON iVT.documentID = sVT.documentID");
	invoicesQuery.SetParameter("iVT", invoicesAndStores.invoicesVT);
	invoicesQuery.SetParameter("sVT", concatenatedStores);
	invoicesList.Load(invoicesQuery.Execute().Unload());
	invoicesList.Sort("date Desc");
	
	sumSum 			 = "Итого: " + invoicesList.Total("sum");
	sumSumWithoutNds = "Итого: " + invoicesList.Total("sumWithoutNds");
	count			 = "Кол-во: " + invoicesList.Count();
	
EndProcedure

&AtServer
Procedure FillCurrentString(invoicesValueTable, currentString, invoicesTypeNumber)
		
	stores = currentString.assignedStores.i;
	
	If TypeOf(stores) = Type("XDTOList") Then
		For each store In stores Do
			invoice = invoicesValueTable.Add();
			FillPropertyValues(invoice, currentString,,"date");
			invoice.date = like_Common.iikoDateTimeTo1C(currentString.date);
			invoice.type = invoicesTypeNumber;
			invoice.assignedStoreUUID = store;
		EndDo;	
	ElsIf TypeOf(stores) = Type("String") Then
		invoice = invoicesValueTable.Add();
		FillPropertyValues(invoice, currentString,,"date");
		invoice.date = like_Common.iikoDateTimeTo1C(currentString.date);
		invoice.type = invoicesTypeNumber;
		invoice.assignedStoreUUID = stores;		
	EndIf;
	
EndProcedure

&AtServer
Procedure GetInvoices(invoicesValueTable, invoicesType, invoicesTypeNumber)
	
	invoicesRequest = like_InvoicesAtServer.GetInvoices(period.StartDate, EndOfDay(period.EndDate), invoicesType);
	If invoicesRequest.success Then
		returnValue = invoicesRequest.returnValue;	
		If TypeOf(returnValue) = Type("XDTOList") Then
			For each iiko_invoice In returnValue Do
				FillCurrentString(invoicesValueTable, iiko_invoice, invoicesTypeNumber);
			EndDo;	
		ElsIf TypeOf(returnValue) = Type("XDTODataObject") Then
			FillCurrentString(invoicesValueTable, returnValue, invoicesTypeNumber);	
		EndIf;
	Else
		Message(invoicesRequest.errorString);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateInvoicesListAtServer()
	If Not (loadIncomingInvoices OR loadOutgoingInvoices) Then
		Message(NStr("en = 'Check any invoice type to load'; ru = 'Для загрузки выберите хотя бы один тип накладных'"));
		Return;
	EndIf;
	
	invoicesList.Clear();
	incomingInvoicesValueTable = invoicesList.Unload();
	outgoingInvoicesValueTable = invoicesList.Unload();
	concatenatedStores		   = invoicesList.Unload().Copy(, "documentID, store");
	
	If loadIncomingInvoices Then
		GetInvoices(incomingInvoicesValueTable, "INCOMING_INVOICE", 0);
	EndIf;
	If loadOutgoingInvoices Then
		GetInvoices(outgoingInvoicesValueTable, "OUTGOING_INVOICE", 1);
	EndIf;
	
	FillCatalogsData(concatenatedStores, incomingInvoicesValueTable, outgoingInvoicesValueTable);
EndProcedure

&AtClient
Procedure UpdateInvoicesList(Command)
	UpdateInvoicesListAtServer();
EndProcedure

&AtClient
Procedure invoicesListSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	
	If Item.CurrentData.type = 0 Then	
		OpenForm("DataProcessor.like_invoicesDownload.Form.like_incomingInvoiceForm", New Structure("UUID", Item.CurrentData.documentID), Item);
	Else
		OpenForm("DataProcessor.like_invoicesDownload.Form.like_outgoingInvoiceForm", New Structure("UUID", Item.CurrentData.documentID), Item);
	EndIf;
EndProcedure

&AtClient
Procedure periodOnChange(Item)
	UpdateInvoicesListAtServer();
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	loadIncomingInvoices = True;
	loadOutgoingInvoices = True;
EndProcedure

&AtClient
Procedure invoicesListDrag(Item, DragParameters, StandardProcessing, Row, Field)
	Message(Item.CurrentData.documentID);
EndProcedure
