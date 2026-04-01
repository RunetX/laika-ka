///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019-2025, Tian Semen Sergeevich (semen@tyan.pw), https://tyan.pw
// All rights reserved. This program and accompanying materials
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

// ============================================================
// КОМАНДЫ
// ============================================================

&AtClient
Procedure Activate(Command)

	If Not ValueIsFilled(Email) Then
		ShowMessageBox(, NStr("ru = 'Укажите Email.'"));
		Return;
	EndIf;

	If Not ValueIsFilled(CustomerName) Then
		ShowMessageBox(, NStr("ru = 'Укажите название организации.'"));
		Return;
	EndIf;

	Result = ActivateDemoAtServer(CustomerName, Email);
	If Not Result.Success Then
		ShowMessageBox(, NStr("ru = 'Не удалось активировать демо. Проверьте подключение к интернету.'"));
		Return;
	EndIf;

	// Сохраняем полученный ключ в константу.
	SaveLicenseKeyAtServer(Result.LicenseKey);

	Items.ButtonActivate.Enabled = False;
	Items.LabelResult.Visible = True;
	Items.LabelResult.Title = NStr("ru = 'Демо активировано! Ключ лицензии сохранён. Действует до: '")
		+ Left(Result.ExpiresAt, 10);

	ShowMessageBox(, NStr("ru = 'Демо-режим активирован! Вы можете приступать к работе.'"));

EndProcedure

// ============================================================
// СЕРВЕРНЫЕ ВЫЗОВЫ
// ============================================================

&AtServerNoContext
Function ActivateDemoAtServer(name, email)
	Return like_CoreAPI.ActivateDemo(name, email);
EndFunction

&AtServerNoContext
Procedure SaveLicenseKeyAtServer(licenseKey)
	Constants.like_LicenseKey.Set(licenseKey);
EndProcedure
