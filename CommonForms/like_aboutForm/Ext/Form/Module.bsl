&AtClient
Procedure LinkClick(Item)
	RunApp(cfgLink);
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	extensions = ConfigurationExtensions.Get(New Structure("Name", "Лайка"));
	If ValueIsFilled(extensions) Then
		cExtension = New ConfigurationMetadataObject(extensions[0].GetData());
		
		Items.cfgCaption.Title = cExtension.Synonym + " " + cExtension.Version + ?(ValueIsFilled(cExtension.Comment)," (" + cExtension.Comment + ")", "");
		cfgLink = cExtension.ConfigurationInformationAddress;
		Items.Link.Title = cfgLink;
		Items.Description.Title = cExtension.BriefInformation;
	EndIf;
EndProcedure