
&AtServer
Procedure ClearMatchingDuplicatesAtServer()
	
	Try
		InformationRegisters.like_objectMatching.RefillMatchings();
	Except
		errorTemplate = NStr("en = 'An error occurred while clearing duplicate matches: %1'; ru = 'Произошла ошибка при очитске дублей соответствий: %1'");
		errorDescription = ErrorDescription();
		like_CommonAtServer.LogWrite(StrTemplate(errorTemplate, errorDescription));
		Return;
	EndTry;
	
	message = New UserMessage;
	message.Text = NStr("en = 'Duplicates cleaning completed'; ru = 'Очитска дублей выполнена'");
	
	message.Message();
	
EndProcedure

&AtClient
Procedure ClearMatchingDuplicates(Command)
	
	ClearMatchingDuplicatesAtServer();
	
EndProcedure
