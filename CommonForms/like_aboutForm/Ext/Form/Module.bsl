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

	LicenseKeyValue = Constants.like_LicenseKey.Get();
	RefreshLicenseStatusDisplay();
EndProcedure

&AtServer
Procedure RefreshLicenseStatusDisplay()
	If Not ValueIsFilled(LicenseKeyValue) Then
		Items.LabelLicenseStatus.Title = NStr("ru = 'Ключ не установлен'");
		Return;
	EndIf;

	status = like_CoreAPI.GetLicenseStatus();
	If status.Success Then
		planLabel = Upper(status.Plan);
		If ValueIsFilled(status.ExpiresAt) Then
			statusText = NStr("ru = 'План: '") + planLabel + NStr("ru = ' | Действует до: '") + Left(status.ExpiresAt, 10);
		Else
			statusText = NStr("ru = 'План: '") + planLabel + NStr("ru = ' | Бессрочная'");
		EndIf;
		If status.Plan = "demo" Then
			statusText = statusText + NStr("ru = ' | Документов: '") + status.DocCount + "/100";
		EndIf;
		Items.LabelLicenseStatus.Title = statusText;
	Else
		Items.LabelLicenseStatus.Title = NStr("ru = 'Ключ недействителен или сервис недоступен'");
	EndIf;
EndProcedure

&AtClient
Procedure SaveLicenseKey(Command)
	licenseKeyToSave = TrimAll(LicenseKeyValue);

	If Not ValueIsFilled(licenseKeyToSave) Then
		ShowMessageBox(, NStr("ru = 'Введите ключ лицензии.'"));
		Return;
	EndIf;

	SaveLicenseKeyAtServer(licenseKeyToSave);
	RefreshLicenseStatusDisplay();
EndProcedure

&AtServerNoContext
Procedure SaveLicenseKeyAtServer(licenseKey)
	Constants.like_LicenseKey.Set(licenseKey);
EndProcedure

&AtClient
Procedure RefreshStatus(Command)
	RefreshLicenseStatusDisplay();
EndProcedure
