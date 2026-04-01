&AtServer
Procedure FillCurrentString(invoicesValueTable, currentString, invoicesTypeNumber)

	invoice = invoicesValueTable.Add();
	FillPropertyValues(invoice, currentString,,"date");
	invoice.date = like_Common.iikoDateTimeTo1C(currentString.date);
	invoice.type = invoicesTypeNumber;

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
		
		FixTable(invoicesValueTable);
	Else
		Message(invoicesRequest.errorString);
	EndIf;

EndProcedure

&AtServer
Procedure FixTable(invoicesValueTable)

	q = New Query;
	q.SetParameter("vltbl", invoicesValueTable.Unload());
	q.Text = "SELECT
	         |	VT.date AS date,
	         |	VT.number AS number,
	         |	VT.documentSummary AS documentSummary,
	         |	VT.processed AS processed,
	         |	VT.comment AS comment,
	         |	VT.type AS type,
	         |	VT.documentID AS documentID,
	         |	VT.storeFrom AS storeFrom
	         |INTO tmpVT
	         |FROM
	         |	&vltbl AS VT
	         |;
	         |
	         |////////////////////////////////////////////////////////////////////////////////
	         |SELECT
	         |	tmpVT.date AS date,
	         |	tmpVT.number AS number,
	         |	tmpVT.documentSummary AS documentSummary,
	         |	tmpVT.processed AS processed,
	         |	CASE
	         |		WHEN tmpVT.comment = ""ОбъектXDTO""
	         |				OR tmpVT.comment = ""XDTODataObject""
	         |			THEN """"
	         |		ELSE tmpVT.comment
	         |	END AS comment,
	         |	tmpVT.type AS type,
	         |	tmpVT.documentID AS documentID,
	         |	tmpVT.storeFrom AS storeFrom,
	         |	Склады.Ref AS storeFromRef
	         |FROM
	         |	tmpVT AS tmpVT
	         |		LEFT JOIN Catalog.like_stores AS Склады
	         |		ON tmpVT.storeFrom = Склады.UUID";
	invoicesValueTable.Load(q.Execute().Unload());

EndProcedure

&AtServer
Procedure UpdateInvoicesListAtServer()

	invoicesList.Clear();
	GetInvoices(invoicesList, "PRODUCTION_ORDER", 0);

EndProcedure

&AtClient
Procedure UpdateInvoicesList(Command)

	UpdateInvoicesListAtServer();

EndProcedure

&AtClient
Procedure periodOnChange(Item)
	UpdateInvoicesListAtServer();
EndProcedure

&AtClient
Procedure OrdersDownload(Command)
	
	For Each selectedRowIndex In Items.invoicesList.SelectedRows Do 
		tableItem = Items.invoicesList.RowData(selectedRowIndex);
		like_OrdersServerCall.Order1CFromIiko(tableItem.DocumentID)
	EndDo;
	
EndProcedure
