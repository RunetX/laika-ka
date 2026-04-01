
&AtClient
Procedure like_Send2IIKOAfter(Command)

	documentsList = New Array;
	For Each selectedRow In Items.СписокРеализацииТоваровУслуг.SelectedRows Do 
		documentsList.Add(selectedRow);
	EndDo;
	
	unmatchedCount = like_DocumentAtServer.GetUnmatchedCount(documentsList);
	
	If unmatchedCount > 0 Then
		documentsListRef = PutToTempStorage(documentsList, ThisForm.UUID);
		OpenForm("CommonForm.like_unmatchedObjectsForm", New Structure("documentsListRef", documentsListRef));
	Else
		like_InvoicesAtServer.SendSalesInvoices2IIKO(documentsList);
	EndIf;

EndProcedure

&AtClient
Procedure like_NotificationProcessingAfter(EventName, Parameter, Source)

	If EventName = "EndOfMatching" And ValueIsFilled(Parameter) Then
		documentsList = GetFromTempStorage(Parameter);
		like_InvoicesAtServer.SendSalesInvoices2IIKO(documentsList);
	EndIf;

EndProcedure
