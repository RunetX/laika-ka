////////////////////////////////////////////////////////////////////////////////
// Тесты расширения Лайка
// Формат: совместим с xUnitFor1C / vanessa-runner
// Каждая экспортная процедура Тест_* — отдельный тест-кейс.
////////////////////////////////////////////////////////////////////////////////

Procedure ЗаполнитьНаборТестов(TestsSet) Export
	TestsSet.Add("Тест_Translit_Кириллица");
	TestsSet.Add("Тест_Translit_ЛатиницаИЦифры");
	TestsSet.Add("Тест_Translit_ПустаяСтрока");
	TestsSet.Add("Тест_IikoDateTimeTo1C_Стандартный");
	TestsSet.Add("Тест_IikoDateTimeTo1C_СМиллисекундами");
	TestsSet.Add("Тест_SafeGet_Map");
	TestsSet.Add("Тест_SafeGet_Structure");
	TestsSet.Add("Тест_SafeGet_Отсутствует");
	TestsSet.Add("Тест_SafeGet_НеколлекцияDefault");
	TestsSet.Add("Тест_MapToJSON");
	TestsSet.Add("Тест_GetActiveConnecton_БезПодключения");
	TestsSet.Add("Тест_GetEntitiesVersion_БезЗаписи");
	TestsSet.Add("Тест_FindByCodeAndConnection_НетСовпадения");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Translit
////////////////////////////////////////////////////////////////////////////////

Procedure Тест_Translit_Кириллица() Export
	Assert(like_Common.Translit("Привет") = "Privet",
		"Translit('Привет') должен вернуть 'Privet'");
	Assert(like_Common.Translit("Щука") = "Shchuka",
		"Translit('Щука') должен вернуть 'Shchuka'");
EndProcedure

Procedure Тест_Translit_ЛатиницаИЦифры() Export
	Assert(like_Common.Translit("ABC123") = "ABC123",
		"Translit не должен менять латиницу и цифры");
	Assert(like_Common.Translit("Test-123_ok") = "Test-123_ok",
		"Translit не должен менять спецсимволы");
EndProcedure

Procedure Тест_Translit_ПустаяСтрока() Export
	Assert(like_Common.Translit("") = "",
		"Translit пустой строки = пустая строка");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// IikoDateTimeTo1C
////////////////////////////////////////////////////////////////////////////////

Procedure Тест_IikoDateTimeTo1C_Стандартный() Export
	result = like_Common.IikoDateTimeTo1C("2026-04-03T14:30:00.000+0300");
	Assert(result = Date(2026, 4, 3, 14, 30, 0),
		"IikoDateTimeTo1C должен разобрать стандартный формат IIKO");
EndProcedure

Procedure Тест_IikoDateTimeTo1C_СМиллисекундами() Export
	result = like_Common.IikoDateTimeTo1C("2025-12-31T23:59:59.999+0300");
	Assert(result = Date(2025, 12, 31, 23, 59, 59),
		"IikoDateTimeTo1C должен отбросить миллисекунды");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SafeGet
////////////////////////////////////////////////////////////////////////////////

Procedure Тест_SafeGet_Map() Export
	m = New Map;
	m.Insert("key1", "value1");
	m.Insert("key2", 42);

	Assert(like_CoreAPI.SafeGet(m, "key1", "") = "value1",
		"SafeGet из Map должен вернуть значение");
	Assert(like_CoreAPI.SafeGet(m, "key2", 0) = 42,
		"SafeGet из Map должен вернуть числовое значение");
EndProcedure

Procedure Тест_SafeGet_Structure() Export
	s = New Structure("name, count", "test", 5);

	Assert(like_CoreAPI.SafeGet(s, "name", "") = "test",
		"SafeGet из Structure должен вернуть значение");
	Assert(like_CoreAPI.SafeGet(s, "count", 0) = 5,
		"SafeGet из Structure должен вернуть числовое значение");
EndProcedure

Procedure Тест_SafeGet_Отсутствует() Export
	m = New Map;
	Assert(like_CoreAPI.SafeGet(m, "missing", "default") = "default",
		"SafeGet должен вернуть default при отсутствии ключа в Map");

	s = New Structure;
	Assert(like_CoreAPI.SafeGet(s, "missing", 99) = 99,
		"SafeGet должен вернуть default при отсутствии ключа в Structure");
EndProcedure

Procedure Тест_SafeGet_НеколлекцияDefault() Export
	Assert(like_CoreAPI.SafeGet("строка", "key", "default") = "default",
		"SafeGet должен вернуть default для нераспознанного типа");
	Assert(like_CoreAPI.SafeGet(Undefined, "key", 0) = 0,
		"SafeGet должен вернуть default для Undefined");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// MapToJSON
////////////////////////////////////////////////////////////////////////////////

Procedure Тест_MapToJSON() Export
	m = New Map;
	m.Insert("name", "test");
	m.Insert("value", 123);

	json = like_CoreAPI.MapToJSON(m);
	Assert(Find(json, """name""") > 0, "MapToJSON должен содержать ключ name");
	Assert(Find(json, """test""") > 0, "MapToJSON должен содержать значение test");
	Assert(Find(json, "123") > 0, "MapToJSON должен содержать числовое значение");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Регрессия: unsafe .Next() — функции должны возвращать безопасные значения
////////////////////////////////////////////////////////////////////////////////

Procedure Тест_GetActiveConnecton_БезПодключения() Export
	// Если нет активного подключения, функция должна вернуть Undefined, а не упасть
	// Этот тест предполагает, что в тестовой базе может не быть активных подключений
	result = like_ConnectionAtServer.GetActiveConnecton();
	// Просто проверяем, что вызов не падает — результат может быть Undefined или ссылкой
	Assert(result = Undefined Or ValueIsFilled(result),
		"GetActiveConnecton должен вернуть Undefined или ссылку, не падать");
EndProcedure

Procedure Тест_GetEntitiesVersion_БезЗаписи() Export
	// Передаём несуществующую ссылку — должен вернуть -1, не упасть
	result = like_EntitiesAtServer.GetEntitiesVersion(Catalogs.like_connections.EmptyRef());
	Assert(result = -1,
		"GetEntitiesVersion для пустой ссылки должен вернуть -1");
EndProcedure

Procedure Тест_FindByCodeAndConnection_НетСовпадения() Export
	result = like_InvoicesAtServer.FindByCodeAndConnection("like_conceptions", "NONEXISTENT_CODE_12345");
	Assert(result = "",
		"FindByCodeAndConnection для несуществующего кода должен вернуть пустую строку");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Вспомогательные
////////////////////////////////////////////////////////////////////////////////

Procedure Assert(condition, message = "")
	If Not condition Then
		Raise "ТЕСТ ПРОВАЛЕН: " + message;
	EndIf;
EndProcedure
