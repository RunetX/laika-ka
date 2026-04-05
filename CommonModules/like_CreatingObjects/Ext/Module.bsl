///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021, ООО Изи Клауд, https://izi.cloud
// All rights reserved. This program and accompanying materials 
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

Procedure AddParameter2Table(parametersTable, pFunction, servicePath, responseNameSpace)
	
	newParameter = parametersTable.Add();
	newParameter.Function 			= pFunction;
	newParameter.ServicePath 		= servicePath;
	newParameter.ResponseNameSpace 	= responseNameSpace;
	
EndProcedure

Function GetXMLRequestParameters(methodName) Export
	
	parametersTable = like_CommonAtServer.GetTableDescription("Function,ServicePath,ResponseNameSpace");
	
	AddParameter2Table(parametersTable, 
						"createProduct", 
						"/resto/services/products",
						"https://izi.cloud/iiko/product/response");
	
	AddParameter2Table(parametersTable,
						"createProductGroup",
						"/resto/services/products",
						"https://izi.cloud/iiko/productGroup/response");
	
	AddParameter2Table(parametersTable,
						"saveCorporationSettings",
						"/resto/services/corporationSettings",
						"https://izi.cloud/iiko/CorporationSettings/response");
	
	AddParameter2Table(parametersTable,
						"createUser",
						"/resto/services/users",
						"https://izi.cloud/iiko/user/response");
	
	AddParameter2Table(parametersTable,
						"saveOrUpdateDocumentWithValidation",
						"/resto/services/document",
						"https://izi.cloud/iiko/document/response");
	
	AddParameter2Table(parametersTable,
						"saveOrUpdateDocument",
						"/resto/services/document",
						"https://izi.cloud/iiko/document/response");
	
	Return parametersTable.Find(methodName, "Function");
	
EndFunction

Function SendPackage2IIKO(connection, requestParameters, XMLBody) Export
	
	ConnectionFields = like_ConnectionAtServer.GetConnectionFields(connection);
	
	ObjectFields = like_CommonAtServer.GetObjectFieldsStructure();
	ObjectFields.ConProps  	 = ConnectionFields;
	ObjectFields.Resource 	 = requestParameters.ServicePath;
	ObjectFields.Namespace 	 = requestParameters.ResponseNameSpace;
	ObjectFields.TypeName 	 = "result";
	ObjectFields.RequestType = "POST";
	ObjectFields.Body		 = XMLBody;

	Params = New Map;
	Params.Insert("methodName", requestParameters.Function);
	ObjectFields.Parameters  = Params;
	
	ObjectFields.isGZIP		 = True;
	ObjectFields.Headers     = like_Common.GetIIKOHeaders(ConnectionFields, ObjectFields.isGZIP);
	
	IIKOObject = like_CommonAtServer.GetIIKOObject(ObjectFields);	
	If IIKOObject = Undefined Then
		WriteLogEvent(NStr("en = 'Sending XML package to iiko server'; ru = 'Отправка XML-пакета на сервер IIKO'"),
					 EventLogLevel.Error,
					 like_CreatingObjects,
					 NStr("en = 'Receiving data from IIKO server error'; ru = 'Ошибка получения данных с сервера IIKO'"));
		Return Undefined;	
	EndIf;
	
	Return IIKOObject;
	
EndFunction

Function CreateXDTOObject(typeName) Export
	                
	Return XDTOFactory.Create(XDTOFactory.Type("https://izi.cloud/iiko/package", typeName));
	
EndFunction