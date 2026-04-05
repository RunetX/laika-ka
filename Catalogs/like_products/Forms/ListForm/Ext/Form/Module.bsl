&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	like_CommonAtServer.SetupCatalogListForm(List);

	If Parameters.Property("ChoiceMode") And Parameters.ChoiceMode Then
		Items.List.ChoiceMode = True;
	EndIf;

EndProcedure
