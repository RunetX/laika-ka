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

	invoicesList = ThisObject["like_invoicesList"];
	invoicesList.Clear();
	For Each row In result.invoicesVT Do
		newRow = invoicesList.Add();
		FillPropertyValues(newRow, row);
	EndDo;

	ThisObject["like_sumSum"]          = result.sumSum;
	ThisObject["like_sumSumWithoutNds"] = result.sumSumWithoutNds;
	ThisObject["like_count"]           = result.count;

EndProcedure

&AtClient
Procedure like_NotificationProcessing(EventName, Parameter, Source)
	If EventName = "like_InvoicesSent" Or EventName = "EndOfMatching" Then
		like_UpdateInvoicesListAtServer();
	EndIf;
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
