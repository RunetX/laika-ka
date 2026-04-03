&AtClient
Procedure RunTests(Command)
	RunTestsAtServer();
EndProcedure

&AtServer
Procedure RunTestsAtServer()

	results.Clear();
	processor = DataProcessors.like_tests.Create();
	testsList = New Array;
	processor.ЗаполнитьНаборТестов(testsList);

	passed = 0;
	failed = 0;

	For Each testName In testsList Do
		newRow = results.Add();
		newRow.testName = testName;
		Try
			Execute("processor." + testName + "()");
			newRow.result = "OK";
			newRow.error  = "";
			passed = passed + 1;
		Except
			newRow.result = "FAIL";
			newRow.error  = ErrorDescription();
			failed = failed + 1;
		EndTry;
	EndDo;

	summary = "Тестов: " + testsList.Count()
		+ " | Пройдено: " + passed
		+ " | Провалено: " + failed;

EndProcedure
