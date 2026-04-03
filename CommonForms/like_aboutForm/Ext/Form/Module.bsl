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
	RefreshLicenseStatusAtServer();
EndProcedure

&AtServer
Procedure RefreshLicenseStatusAtServer()
	If Not ValueIsFilled(LicenseKeyValue) Then
		LicenseStatusText = NStr("ru = 'Ключ не установлен'");
		LicenseStatusColor = "gray";
		Return;
	EndIf;

	status = like_CoreAPI.GetLicenseStatus();
	If status.Success Then
		planLabel = Upper(status.Plan);
		If ValueIsFilled(status.ExpiresAt) Then
			LicenseStatusText = NStr("ru = 'План: '") + planLabel + NStr("ru = ' | Действует до: '") + Left(status.ExpiresAt, 10);
		Else
			LicenseStatusText = NStr("ru = 'План: '") + planLabel + NStr("ru = ' | Бессрочная'");
		EndIf;
		If status.Plan = "demo" Then
			LicenseStatusText = LicenseStatusText + NStr("ru = ' | Документов: '") + status.DocCount + "/100";
		EndIf;
		LicenseStatusColor = "green";
	Else
		LicenseStatusText = NStr("ru = 'Ключ недействителен или сервис недоступен'");
		LicenseStatusColor = "red";
	EndIf;
EndProcedure

&AtClient
Procedure SaveLicenseKey(Command)
	keyToSave = TrimAll(LicenseKeyValue);

	If Not ValueIsFilled(keyToSave) Then
		ShowMessageBox(, NStr("ru = 'Введите ключ лицензии.'"));
		Return;
	EndIf;

	SaveLicenseKeyAtServer(keyToSave);
	RefreshLicenseStatusAtServer();

	If LicenseStatusColor = "green" Then
		ShowMessageBox(, NStr("ru = 'Ключ сохранён и проверен.'"));
	Else
		ShowMessageBox(, NStr("ru = 'Ключ сохранён, но проверка не прошла. Убедитесь что ключ верный и сервис доступен.'"));
	EndIf;
EndProcedure

&AtServerNoContext
Procedure SaveLicenseKeyAtServer(licenseKey)
	Constants.like_LicenseKey.Set(licenseKey);
EndProcedure

&AtClient
Procedure RefreshStatus(Command)
	RefreshLicenseStatusAtServer();
EndProcedure
