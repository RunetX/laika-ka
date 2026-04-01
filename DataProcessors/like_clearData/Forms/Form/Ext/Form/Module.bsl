&AtServer
Procedure ClearCatalog(entityCatalog)
	
	Query = New Query("SELECT
	                  |	entityCatalog.Ref AS Ref
	                  |FROM
	                  |	Catalog.[catalogName] AS entityCatalog");
    Query.Text = StrReplace(Query.Text, "[catalogName]", entityCatalog);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		CurItem = Selection.Ref.GetObject();
		CurItem.DeletionMark = True;
		CurItem.Write();
	EndDo;
	
	Message(NStr("en = 'Catalog "+entityCatalog+" elements marked to delete';ru = 'Элементы справочника "+entityCatalog+" помечены на удаление'"));
	
EndProcedure

&AtServer
Procedure ClearInformationRegister(RegisterName)
	
	RecordSet = InformationRegisters[RegisterName].CreateRecordSet();
	RecordSet.Write();
	
	Message(NStr("en = 'Information register "+RegisterName+" cleared';ru = 'Регистр сведений "+RegisterName+" очищен'"));
EndProcedure

&AtServer
Procedure ClearDataAtServer()
	ClearCatalog("like_accounts");
	ClearCatalog("like_accountingCategories");
	ClearCatalog("like_cashRegisters");
	ClearCatalog("like_conceptions");
	ClearCatalog("like_customers");
	ClearCatalog("like_departments");
	ClearCatalog("like_measureUnits");
	ClearCatalog("like_paymentTypes");
	ClearCatalog("like_products");
	ClearCatalog("like_stores");
	ClearCatalog("like_users");	
	ClearInformationRegister("like_entititesVersions");
	ClearInformationRegister("like_customersRevisions");
	like_ConnectionAtServer.HaltActiveConnection();
EndProcedure

&AtClient
Procedure ClearData(Command)
	ClearDataAtServer();
EndProcedure
