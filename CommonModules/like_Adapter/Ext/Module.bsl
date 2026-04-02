///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019-2025, Tian Semen Sergeevich (semen@tyan.pw), https://tyan.pw
// All rights reserved. This program and accompanying materials
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

// Диспетчер адаптеров.
// Определяет тип конфигурации 1С и делегирует вызовы нужному адаптерному модулю.
// Все остальные модули вызывают функции этого модуля — прямых вызовов адаптеров больше нигде нет.
//
// Интерфейс адаптера (каждый like_AdapterXXX обязан реализовать):
//   WriteEntities(upsertList)                    — запись справочников по массиву структур от сервиса
//   CreateMobileOrder(order, settings) → XDTO    — формирование мобильного заказа

// ============================================================
// ПУБЛИЧНЫЙ ИНТЕРФЕЙС
// ============================================================

// Записывает массив объектов в справочники текущей конфигурации.
Procedure WriteEntities(upsertList) Export
	Module = AdapterModule();
	Module.WriteEntities(upsertList);
EndProcedure

// Создаёт XDTO-объект мобильного заказа для текущей конфигурации.
Function CreateMobileOrder(order, settings) Export
	Module = AdapterModule();
	Return Module.CreateMobileOrder(order, settings);
EndFunction

// Возвращает строковый идентификатор текущей конфигурации: "КА", "УТ" и т.д.
Function ConfigurationType() Export
	name = Metadata.Name;

	If Find(name, "КомплекснаяАвтоматизация") > 0
		Or Find(name, "ComplexAutomation") > 0 Then
		Return "КА";
	ElsIf Find(name, "УправлениеТорговлей") > 0
		Or Find(name, "TradeManagement") > 0 Then
		Return "УТ";
	EndIf;

	// Fallback — пробуем определить по наличию характерных объектов метаданных.
	If Metadata.Documents.Find("ПриобретениеТоваровУслуг") <> Undefined Then
		Return "КА";
	ElsIf Metadata.Documents.Find("ПоступлениеТоваровУслуг") <> Undefined Then
		Return "УТ";
	EndIf;

	Return "КА"; // По умолчанию — КА
EndFunction

// ============================================================
// ВНУТРЕННЯЯ ЛОГИКА
// ============================================================

// Возвращает модуль адаптера для текущей конфигурации.
Function AdapterModule()
	cfgType = ConfigurationType();

	If cfgType = "КА" Then
		Return like_AdapterКА;
	ElsIf cfgType = "УТ" Then
		Return like_AdapterУТ;
	Else
		Raise NStr("en = 'Unknown configuration type: '; ru = 'Неизвестный тип конфигурации: '") + cfgType;
	EndIf;
EndFunction
