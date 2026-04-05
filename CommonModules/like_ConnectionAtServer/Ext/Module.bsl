///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021, ООО Изи Клауд, https://izi.cloud
// All rights reserved. This program and accompanying materials 
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

Function GetConnectionFields(connection) Export
	
	Return New Structure("host,port,user,password,version,edition,isSecure", 
							connection.host, 
							connection.port,
							connection.login,
							connection.password,
							connection.version,
							connection.edition,
							connection.isSecure);
							
EndFunction
						
Function GetActiveConnecton() Export
	
	ConnectionQuery = New Query("SELECT TOP 1
	                            |	like_connections.Ref AS ActiveConnection
	                            |FROM
	                            |	Catalog.like_connections AS like_connections
	                            |WHERE
	                            |	like_connections.active");
	ConnectionSelection = ConnectionQuery.Execute().Select();
	ConnectionSelection.Next();
	Return ConnectionSelection.ActiveConnection;
	
EndFunction

Procedure InitEntitiesVersionsAndServerInfo(connection) Export
	
	InitEntitiesVersions(connection);
	InitServerInfo(connection);
	
EndProcedure

Procedure InitEntitiesVersions(connection)
	
	manager = InformationRegisters.like_entititesVersions.CreateRecordSet();
	filter = manager.Filter;
	filter.connection.Set(connection);
	manager.Read();
	
	If manager.Count() = 0 Then
		aRecord = manager.Add();		
		aRecord.connection = connection;
		aRecord.entityVersion = -1;	
		manager.Write();
	EndIf;
	
EndProcedure

Procedure InitServerInfo(connection)
	
	connectionObject = connection.GetObject();
	ConnectionFields = GetConnectionFields(connection);
	
	ObjectFields = like_CommonAtServer.GetObjectFieldsStructure();
	ObjectFields.ConProps  	 = ConnectionFields;
	ObjectFields.Resource 	 = "/resto/get_server_info.jsp";
	ObjectFields.Namespace 	 = "https://izi.cloud/iiko/reading/serverInfoResponse";
	ObjectFields.TypeName 	 = "r";
	ObjectFields.RequestType = "GET";
	ObjectFields.Headers     = like_Common.getIIKOHeaders(ConnectionFields);
	ObjectFields.isGZIP		 = False;	
	XDTOResponse = like_CommonAtServer.GetIIKOObject(ObjectFields);
	
	If XDTOResponse <> Undefined Then
		FillPropertyValues(connectionObject, XDTOResponse, "version,serverState");
		upCaseEdition = Upper(XDTOResponse.edition);
		connectionObject.edition = "IIKO_"+?(upCaseEdition = "DEFAULT", "RMS", upCaseEdition);
		connectionObject.Write();
	EndIf;
	
EndProcedure

Procedure ActivateDeactivateConnection(connection, state)
	
	ConnectionObject = connection.GetObject();
	ConnectionObject.active = state;
	ConnectionObject.Write();
	
EndProcedure

Procedure HaltActiveConnection() Export
	
	ActiveConnection = GetActiveConnecton();
	If ActiveConnection <> Undefined Then
		ActivateDeactivateConnection(ActiveConnection, False);
	EndIf;	
	
EndProcedure

Procedure SetActiveConnection(connection) Export
	
	HaltActiveConnection();	
	ActivateDeactivateConnection(connection, True);
	InitEntitiesVersionsAndServerInfo(connection);
	like_EntitiesAtServer.BackgroundUpdate();
	
EndProcedure