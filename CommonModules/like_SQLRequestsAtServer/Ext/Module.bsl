///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021, ООО Изи Клауд, https://izi.cloud
// All rights reserved. This program and accompanying materials 
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

// sqlParameters - map with values to fill brackets sections in request template
Function RequestSQL(sqlRequest, sqlParameters = Undefined) Export
	
	ActiveConnection = like_ConnectionAtServer.GetActiveConnecton();
	If ActiveConnection = Undefined Then
		LogWrite(NStr("en = 'No active connection'; ru = 'Подключение неактивно'"));
		Return Undefined;
	EndIf;
	
	ConnectionFields = like_ConnectionAtServer.GetConnectionFields(ActiveConnection);
	
	ObjectFields = like_CommonAtServer.GetObjectFieldsStructure();
	ObjectFields.ConProps  	 = ConnectionFields;
	ObjectFields.Resource 	 = "/resto/service/maintance/sql.jsp";
	ObjectFields.Namespace 	 = "https://izi.cloud/iiko/read/sql";
	ObjectFields.TypeName 	 = "root";
	ObjectFields.RequestType = "GET";
	
	If sqlParameters <> Undefined Then
		For each parameter In sqlParameters Do
			sqlRequest = StrReplace(sqlRequest, "["+String(parameter.Key)+"]", parameter.Value);
		EndDo;	
	EndIf;
	Params = New Map;
	Params.Insert("sql", sqlRequest);
	ObjectFields.Parameters  = Params;
	
	ObjectFields.isGZIP		 = False;
	ObjectFields.Headers     = like_Common.GetIIKOHeaders(ConnectionFields, ObjectFields.isGZIP);
	
	IIKOObject = like_CommonAtServer.GetIIKOObject(ObjectFields);	
	If IIKOObject = Undefined Then
		LogWrite(NStr("en = 'Receiving data from IIKO server error'; ru = 'Ошибка получения данных с сервера IIKO'"));
		Return Undefined;	
	EndIf;
	
	Return IIKOObject;
	
EndFunction

Function SQLXDTO2Table(XDTOObject, sqlTable) Export
	
	If XDTOObject.resultSet.Properties().Get("row") = Undefined Then
		Return sqlTable;
	EndIf;
	
	rows = XDTOObject.resultSet.row;
	If TypeOf(rows) = Type("XDTOList") Then
		For each row In rows Do  
			nRow = sqlTable.Add();
			FillPropertyValues(nRow, row);
		EndDo;
	ElsIf TypeOf(rows) = Type("XDTODataObject") Then
		nRow = sqlTable.Add();
		FillPropertyValues(nRow, rows);	
	EndIf;
	
	Return sqlTable;
	
EndFunction

Procedure LogWrite(message)
	
	like_CommonAtServer.LogWrite(message);
	
EndProcedure