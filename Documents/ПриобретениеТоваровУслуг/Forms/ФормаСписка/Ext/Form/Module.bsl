&AtClient
Procedure like_PeriodOnChange(Item)
	like_UpdateInvoicesListAtServer();
EndProcedure

&AtServer
Procedure like_UpdateInvoicesListAtServer()

	loadIncoming = ThisObject["like_loadIncomingInvoices"];
	loadOutgoing = ThisObject["like_loadOutgoingInvoices"];

	If Not (loadIncoming Or loadOutgoing) Then
		Message(NStr("en = 'Check any invoice type to load'; ru = 'Для загрузки выберите хотя бы один тип накладных'"));
		Return;
	EndIf;

	periodVal = ThisObject["like_period"];
	result = like_InvoicesAtServer.FetchInvoicesList(
		periodVal.StartDate,
		periodVal.EndDate,
		loadIncoming,
		loadOutgoing);

	If result = Undefined Then
		Return;
	EndIf;

	ValueToFormAttribute(result.invoicesVT, "like_invoicesList");
	ThisObject["like_sumSum"]          = result.sumSum;
	ThisObject["like_sumSumWithoutNds"] = result.sumSumWithoutNds;
	ThisObject["like_count"]           = result.count;

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
