
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	FormParameters = New Structure("", );
	OpenForm("CommonForm.like_aboutForm", 
			FormParameters, 
			CommandExecuteParameters.Source, 
			CommandExecuteParameters.Uniqueness, 
			CommandExecuteParameters.Window, 
			CommandExecuteParameters.URL,
			,
			FormWindowOpeningMode.LockOwnerWindow);
EndProcedure
