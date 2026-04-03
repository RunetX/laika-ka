///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019-2025, Tian Semen Sergeevich (semen@tyan.pw), https://tyan.pw
// All rights reserved. This program and accompanying materials
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Period = "year";
	UpdatePriceLabel();
	LoadLicenseInfo();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	// nothing
EndProcedure

// ============================================================
// КОМАНДЫ
// ============================================================

&AtClient
Procedure Pay(Command)

	If Not ValueIsFilled(Period) Then
		ShowMessageBox(, NStr("ru = 'Выберите период оплаты.'"));
		Return;
	EndIf;

	Result = CreatePaymentAtServer(Period);
	If Not Result.Success Then
		ShowMessageBox(, NStr("ru = 'Не удалось создать платёж. Проверьте ключ лицензии и подключение к интернету.'"));
		Return;
	EndIf;

	PaymentId = Result.PaymentId;

	// Генерируем QR из строки данных.
	GenerateQRAtServer(Result.QRCodeData);

	// Показываем группу QR.
	Items.GroupQR.Visible = True;
	Items.ButtonPay.Enabled = False;
	Items.LabelStatus.Title = NStr("ru = 'Статус: ожидание оплаты...'");

	// Запускаем опрос статуса каждые 3 секунды.
	AttachIdleHandler("PollPaymentStatus", 3, False);

EndProcedure

// ============================================================
// ОПРОС СТАТУСА
// ============================================================

&AtClient
Procedure PollPaymentStatus()

	If Not ValueIsFilled(PaymentId) Then
		DetachIdleHandler("PollPaymentStatus");
		Return;
	EndIf;

	Result = GetPaymentStatusAtServer(PaymentId);
	If Not Result.Success Then
		Return;
	EndIf;

	If Result.Status = "succeeded" Then
		DetachIdleHandler("PollPaymentStatus");
		Items.LabelStatus.Title = NStr("ru = 'Оплата прошла успешно!'");
		Items.ButtonPay.Enabled = True;
		LoadLicenseInfoAtServer();
		ShowMessageBox(, NStr("ru = 'Оплата прошла! Подписка продлена.'"));
	ElsIf Result.Status = "canceled" Then
		DetachIdleHandler("PollPaymentStatus");
		Items.LabelStatus.Title = NStr("ru = 'Платёж отменён.'");
		Items.ButtonPay.Enabled = True;
		Items.GroupQR.Visible = False;
	EndIf;

EndProcedure

// ============================================================
// СЕРВЕРНЫЕ ВЫЗОВЫ
// ============================================================

&AtServer
Function CreatePaymentAtServer(period)
	Return like_CoreAPI.CreatePayment(period);
EndFunction

&AtServer
Function GetPaymentStatusAtServer(paymentId)
	Return like_CoreAPI.GetPaymentStatus(paymentId);
EndFunction

&AtServer
Procedure LoadLicenseInfo()
	LoadLicenseInfoAtServer();
EndProcedure

&AtServer
Procedure LoadLicenseInfoAtServer()
	status = like_CoreAPI.GetLicenseStatus();
	If status.Success Then
		If status.Plan = "demo" Then
			maxDocs = 0;
			If status.Features <> Undefined And status.Features["max_documents"] <> Undefined Then
				maxDocs = status.Features["max_documents"];
			EndIf;
			Items.LabelPlan.Title = NStr("ru = 'Тариф: демо (документов: '")
				+ Format(status.DocCount, "NG=0") + " / " + Format(maxDocs, "NG=0") + ")";
		Else
			Items.LabelPlan.Title = NStr("ru = 'Тариф: '") + status.Plan;
		EndIf;
		If ValueIsFilled(status.ExpiresAt) Then
			Items.LabelExpires.Title = NStr("ru = 'Действует до: '") + Left(status.ExpiresAt, 10);
		Else
			Items.LabelExpires.Title = NStr("ru = 'Действует до: бессрочно'");
		EndIf;
	Else
		Items.LabelPlan.Title = NStr("ru = 'Тариф: не удалось получить'");
		Items.LabelExpires.Title = NStr("ru = 'Действует до: —'");
	EndIf;
EndProcedure

&AtServer
Procedure GenerateQRAtServer(qrData)
	If Not ValueIsFilled(qrData) Then
		Return;
	EndIf;

	// QR-код: показываем данные для ручного ввода / сканирования.
	// QRCodeGenerator (платформа 8.3.22+) может быть недоступен.
	Items.LabelScanQR.Title = qrData;
EndProcedure

&AtServer
Procedure UpdatePriceLabel()
	If Period = "year" Then
		Items.LabelPrice.Title = NStr("ru = 'Стоимость: 9 900 руб. за год'");
	ElsIf Period = "month" Then
		Items.LabelPrice.Title = NStr("ru = 'Стоимость: 990 руб. за месяц'");
	Else
		Items.LabelPrice.Title = NStr("ru = 'Стоимость: —'");
	EndIf;
EndProcedure

&AtClient
Procedure PeriodSelectorOnChange(Item)
	UpdatePriceLabelAtServer();
EndProcedure

&AtServer
Procedure UpdatePriceLabelAtServer()
	UpdatePriceLabel();
EndProcedure
