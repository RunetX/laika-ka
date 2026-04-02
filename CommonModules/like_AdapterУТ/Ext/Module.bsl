///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019-2025, Tian Semen Sergeevich (semen@tyan.pw), https://tyan.pw
// All rights reserved. This program and accompanying materials
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

// Адаптер для конфигурации "Управление торговлей".
// Заглушка — реализация по запросу.

// ============================================================
// ПУБЛИЧНЫЙ ИНТЕРФЕЙС
// ============================================================

Procedure WriteEntities(upsertList) Export
	Raise NStr("en = 'Adapter for UT is not yet implemented.';
	           |ru = 'Адаптер для УТ ещё не реализован. Обратитесь в поддержку.'");
EndProcedure

Function CreateMobileOrder(order, settings) Export
	Raise NStr("en = 'Adapter for UT is not yet implemented.';
	           |ru = 'Адаптер для УТ ещё не реализован. Обратитесь в поддержку.'");
EndFunction
