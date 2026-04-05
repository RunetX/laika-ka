///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021, ООО Изи Клауд, https://izi.cloud
// All rights reserved. This program and accompanying materials 
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

Function GetCustomersRevision(connection) Export
	
	customersQuery = New Query("SELECT
	                          |	like_customersRevisions.customersRevision AS customersRevision,
	                          |	like_customersRevisions.streetsRevision AS streetsRevision
	                          |FROM
	                          |	InformationRegister.like_customersRevisions AS like_customersRevisions
	                          |WHERE
	                          |	like_customersRevisions.connection = &connection");
	customersQuery.SetParameter("connection", connection);
	customersSelection = customersQuery.Execute().Select();
	customersSelection.Next();
	Return New Structure("customersRevision, streetsRevision", customersSelection.customersRevision, customersSelection.streetsRevision);
	
EndFunction

Procedure SetCustomersRevision(connection, customersRevision)
	
	manager = InformationRegisters.like_customersRevisions.CreateRecordSet();
	filter = manager.Filter;
	filter.connection.Set(connection);
	manager.Read();
	                  
	If manager.Count() = 1 Then
		manager[0].customersRevision = customersRevision.customersRevision;	
		manager[0].streetsRevision	 = customersRevision.streetsRevision;
		manager.Write();
	EndIf;	
	
EndProcedure

Function GetXMLCustomers(connection)
	
	customersRevision = GetCustomersRevision(connection);
	requestType = XDTOFactory.Type("https://izi.cloud/iiko/reading/customers", "requestType");
	request = XDTOFactory.Create(requestType);
	If customersRevision.customersRevision = Undefined Then
		request.customersLocalRevision = -1;
		request.streetsLocalRevision = -1;
	Else
		request.customersLocalRevision = customersRevision.customersRevision;
		request.streetsLocalRevision = customersRevision.streetsRevision;
	EndIf;
	
	argsType = XDTOFactory.Type("https://izi.cloud/iiko/reading/customers", "args");
	args = XDTOFactory.Create(argsType);
	
	args.entities_version = like_EntitiesAtServer.GetEntitiesVersion(connection);
	args.client_type = "BACK";
	args.enable_warnings = False;	
	args.request_watchdog_check_results = False;
	args.use_raw_entities = True;
	args.request = request;
	
	return like_CommonAtServer.XDTO2XML(args);
	
EndFunction

Procedure UpdateCustomers() Export
	
	ActiveConnection = like_ConnectionAtServer.GetActiveConnecton();
	If ActiveConnection = Undefined Then
		Return;
	EndIf;
	
	ConnectionFields = like_ConnectionAtServer.GetConnectionFields(ActiveConnection);
	
	ObjectFields = like_CommonAtServer.GetObjectFieldsStructure();
	ObjectFields.ConProps  	 = ConnectionFields;
	ObjectFields.Resource 	 = "/resto/services/brdDataLoading";
	ObjectFields.Namespace 	 = "https://izi.cloud/iiko/reading/customersResponse";
	ObjectFields.TypeName 	 = "result";
	ObjectFields.RequestType = "POST";
	Params = New Map;
	Params.Insert("methodName", "getAllBrdData");
	ObjectFields.Parameters  = Params;
	ObjectFields.Headers     = like_Common.getIIKOHeaders(ConnectionFields);
	ObjectFields.Body		 = GetXMLCustomers(ActiveConnection);
	ObjectFields.isGZIP		 = True;
	
	IIKOObject = like_CommonAtServer.GetIIKOObject(ObjectFields);
	If IIKOObject = Undefined Then
		Return;
	EndIf;
	
	If IIKOObject.success Then
		ExeItems(IIKOObject, ActiveConnection);	
	EndIf;
	
EndProcedure

Procedure ExeItems(IIKOObject, ActiveConnection)
	
	If IIKOObject.returnValue.customers.Properties().Get("i") = Undefined Then
		like_CommonAtServer.LogWrite("Customers list have no items.");
		Return;
	EndIf;
	customers = IIKOObject.returnValue.customers.i;
	
	If TypeOf(customers) = Type("XDTOList") Then
		For each customer In customers Do  
			ExeItem(ActiveConnection, customer);
		EndDo;
	ElsIf TypeOf(customers) = Type("XDTODataObject") Then
		ExeItem(ActiveConnection, customers);	
	EndIf;
	
	SetCustomersRevision(ActiveConnection, New Structure("customersRevision, streetsRevision",
														  IIKOObject.ReturnValue.customersLocalRevision, 
														  IIKOObject.ReturnValue.streetsLocalRevision));
	
EndProcedure
  
Procedure ExeItem(connection, customer)
	
	foundCustomer = Catalogs.like_customers.FindByAttribute("UUID", customer.eid);
	If foundCustomer.isEmpty() Then
		customerObject = Catalogs.like_customers.CreateItem();
	Else
		customerObject = foundCustomer.GetObject();
	EndIf;
	
	customerObject.UUID 		= customer.eid;
	customerObject.Description  = customer.name;
	customerObject.DeletionMark = customer.deleted;
	customerObject.revision		= customer.revision;
	customerObject.connection   = connection;
	customerObject.Write();
	
EndProcedure
													  