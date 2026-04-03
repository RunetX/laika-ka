&AtClient
Procedure like_UpdateInvoicesList(Command)
	like_UpdateInvoicesListAtServer();
EndProcedure

&AtServer
Procedure like_UpdateInvoicesListAtServer()

	If Not (like_loadIncomingInvoices Or like_loadOutgoingInvoices) Then
		Message(NStr("en = 'Check any invoice type to load'; ru = 'Для загрузки выберите хотя бы один тип накладных'"));
		Return;
	EndIf;

	result = like_InvoicesAtServer.FetchInvoicesList(
		like_period.НачалоПериода,
		like_period.КонецПериода,
		like_loadIncomingInvoices,
		like_loadOutgoingInvoices);

	If result = Undefined Then
		Return;
	EndIf;

	ЗначениеВРеквизитФормы(result.invoicesVT, "like_invoicesList");
	like_sumSum          = result.sumSum;
	like_sumSumWithoutNds = result.sumSumWithoutNds;
	like_count           = result.count;

EndProcedure

&AtClient
Procedure like_InvoicesListSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;

	If Item.CurrentData = Undefined Then
		Return;
	EndIf;

	If Item.CurrentData.type = 0 Then
		OpenForm("DataProcessor.like_invoicesDownload.Form.like_incomingInvoiceForm",
			New Structure("UUID", Item.CurrentData.documentID), Item);
	Else
		OpenForm("DataProcessor.like_invoicesDownload.Form.like_outgoingInvoiceForm",
			New Structure("UUID", Item.CurrentData.documentID), Item);
	EndIf;
EndProcedure
