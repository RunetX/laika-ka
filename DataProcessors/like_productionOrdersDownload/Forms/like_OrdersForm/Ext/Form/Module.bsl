&AtServer
Procedure GetInvoices(invoicesValueTable, invoicesType, invoicesTypeNumber)

	invoicesRequest = like_InvoicesAtServer.GetInvoices(period.StartDate, EndOfDay(period.EndDate), invoicesType);
	If Not invoicesRequest.success Then
		Message(invoicesRequest.errorString);
		Return;
	EndIf;

	returnValue = invoicesRequest.returnValue;
	For Each invoiceData In returnValue Do
		invoice = invoicesValueTable.Add();
		invoice.date             = like_Common.iikoDateTimeTo1C(like_CoreAPI.SafeGet(invoiceData, "date", ""));
		invoice.number           = like_CoreAPI.SafeGet(invoiceData, "number", "");
		invoice.documentSummary  = like_CoreAPI.SafeGet(invoiceData, "documentSummary", "");
		invoice.processed        = like_CoreAPI.SafeGet(invoiceData, "processed", False);
		invoice.comment          = like_CoreAPI.SafeGet(invoiceData, "comment", "");
		invoice.type             = invoicesTypeNumber;
		invoice.documentID       = like_CoreAPI.SafeGet(invoiceData, "documentID", "");
		invoice.storeFrom        = like_CoreAPI.SafeGet(invoiceData, "storeFrom", "");
	EndDo;

	FixTable(invoicesValueTable);

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
	         |	tmpVT.comment AS comment,
	         |	tmpVT.type AS type,
	         |	tmpVT.documentID AS documentID,
	         |	tmpVT.storeFrom AS storeFrom,
	         |	Stores.Ref AS storeFromRef
	         |FROM
	         |	tmpVT AS tmpVT
	         |		LEFT JOIN Catalog.like_stores AS Stores
	         |		ON tmpVT.storeFrom = Stores.UUID";
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
