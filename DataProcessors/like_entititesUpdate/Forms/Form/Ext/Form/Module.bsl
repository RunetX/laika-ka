&AtClient
Procedure entitiesUpdate(Command)
	
	ActiveConnection = like_ConnectionAtServer.GetActiveConnecton();
	If ActiveConnection = Undefined Then
		Message(NStr("en = 'Activate connection first'; ru = 'Для запуска активируйте подключение'"));
		Return;
	EndIf;
	
	like_EntitiesAtServer.Update(,,True);
	
EndProcedure

&AtClient
Procedure customersUpdate(Command)
	
	ActiveConnection = like_ConnectionAtServer.GetActiveConnecton();
	If ActiveConnection = Undefined Then
		Message(NStr("en = 'Activate connection first'; ru = 'Для запуска активируйте подключение'"));
		Return;
	EndIf;
	
	like_CustomersAtServer.UpdateCustomers();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateActiveConnectionStatus();
	AttachIdleHandler("UpdateActiveConnectionStatus", 5);
	
EndProcedure

&AtClient
Procedure UpdateActiveConnectionStatus() Export
	
	ActiveConnection = like_ConnectionAtServer.GetActiveConnecton();
	If ActiveConnection <> Undefined Then
		Items.ActiveConnectionStatus.Title = NStr("en = 'Connected to '; ru = 'Подключено к '") 
													+ ActiveConnection;
		Object.connection = ActiveConnection;
		Items.Connect.Title = NStr("en = 'Disconnect'; ru = 'Отключиться'");
	Else
		Items.ActiveConnectionStatus.Title = NStr("en = 'No active connections'; ru = 'Нет активных соединений'");
	EndIf;
	
EndProcedure

&AtClient
Procedure Connect(Command)
	
	ActiveConnection = like_ConnectionAtServer.GetActiveConnecton();
	If ActiveConnection = Undefined Then
		If Not Object.connection.IsEmpty() Then
			like_ConnectionAtServer.SetActiveConnection(Object.connection);
			Items.Connect.Title = NStr("en = 'Disconnect'; ru = 'Отключиться'");
		Else
			Message(NStr("en = 'Choose connection to activate'; ru = 'Выберите подключение для активации'"));
		EndIf;
	Else
		like_ConnectionAtServer.HaltActiveConnection();
		Items.Connect.Title = NStr("en = 'Connect'; ru = 'Подключиться'");
	EndIf;
	
EndProcedure
