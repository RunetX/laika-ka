///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019-2023, Tian Semen Sergeevich (semen@tyan.pw), https://tyan.pw
// All rights reserved. This program and accompanying materials 
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

Function GetEntitiesVersion(connection) Export
	
	EntitiesQuery = New Query("SELECT
	                          |	like_entititesVersions.entityVersion AS entityVersion
	                          |FROM
	                          |	InformationRegister.like_entititesVersions AS like_entititesVersions
	                          |WHERE
	                          |	like_entititesVersions.connection = &connection");
	EntitiesQuery.SetParameter("connection", connection);
	EntitiesSelection = EntitiesQuery.Execute().Select();
	EntitiesSelection.Next();
	Return EntitiesSelection.entityVersion;
	
EndFunction

Function GetXMLFromXDTO(XDTOObject)

	Return like_CommonAtServer.XDTO2XML(XDTOObject);
	
EndFunction

Function GetXMLEntitiesUpdate(connection)
	
	argsType = XDTOFactory.Type("https://izi.cloud/iiko/reading/entitiesUpdate", "args");
	args = XDTOFactory.Create(argsType); 
	
	eVersion = GetEntitiesVersion(connection);
	args.entities_version = eVersion;
	args.client_type = "BACK";
	args.enable_warnings = False;	
	args.request_watchdog_check_results = False;
	args.use_raw_entities = True;
	args.fromRevision = eVersion;
	args.timeoutMillis = 30000;
	args.useRawEntities = True;	
	
	return getXMLfromXDTO(args);
	
EndFunction

Function GetExeEntityStructure()
	
	Return like_CommonAtServer.GetStructureWithFields("connection, item, catalogName, isContainer");
	
EndFunction

Function FindByIDAndConnection(catalogName, UUID, connection) 
	
	FindQuery = New Query("SELECT
	                      |	like_catalog.Ref AS Ref
	                      |FROM
	                      |	Catalog.[catalogName] AS like_catalog
	                      |WHERE
	                      |	like_products.UUID = &UUID
	                      |	AND like_catalog.connection = &connection");
	FindQuery.Text = StrReplace(FindQuery.Text, "[catalogName]", CatalogName);
	FindQuery.SetParameter("UUID", UUID);
	FindQuery.SetParameter("connection", connection);
	FindSelection = FindQuery.Execute().Select();
	FindSelection.Next();
	Return FindSelection.Ref;
	
EndFunction

Function Description(dscKey)
	
	Return like_TypesAndDescriptionsAtServer.GetDescription(dscKey);
	
EndFunction

Function GetEntititesTableDefinition()
	
	// value table section
	entitiesTable = New ValueTable;
	entitiesTable.Columns.Add("connection", 			Description("connection"));
	entitiesTable.Columns.Add("entityType", 			Description("shortString"));
	entitiesTable.Columns.Add("catalogName",			Description("shortString"));
	entitiesTable.Columns.Add("isContainer", 			Description("boolean"));
	entitiesTable.Columns.Add("revision", 				Description("revision"));
	entitiesTable.Columns.Add("id", 					Description("UUID"));
	entitiesTable.Columns.Add("ref",					Description("catalogs"));
	entitiesTable.Columns.Add("deleted", 				Description("boolean"));
	entitiesTable.Columns.Add("code", 					Description("shortString"));
	entitiesTable.Columns.Add("num",					Description("shortString"));
	entitiesTable.Columns.Add("description",			Description("longString"));
	entitiesTable.Columns.Add("parentID", 				Description("UUID"));
	entitiesTable.Columns.Add("parent", 				Description("parent"));
	entitiesTable.Columns.Add("accountingCategoryID", 	Description("UUID"));
	entitiesTable.Columns.Add("accountingCategory",		Description("accountingCategory"));
	entitiesTable.Columns.Add("isCash",					Description("boolean"));
	entitiesTable.Columns.Add("mainUnitID", 			Description("UUID"));
	entitiesTable.Columns.Add("mainUnit", 				Description("measureUnit"));
	entitiesTable.Columns.Add("productType",			Description("productType"));
	entitiesTable.Columns.Add("userSupplierType", 		Description("userSupplierType"));
	entitiesTable.Columns.Add("userIsClient", 			Description("boolean"));
	entitiesTable.Columns.Add("userIsEmployee", 		Description("boolean"));
	entitiesTable.Columns.Add("userIsPluginUser", 		Description("boolean"));
	entitiesTable.Columns.Add("userIsSupplier", 		Description("boolean"));
	entitiesTable.Columns.Add("userIsSystem", 			Description("boolean"));
	
	Return entitiesTable;
	
EndFunction

Function GetEntitiesConformityTable()
	
	entitiesConformityTable = New ValueTable;
	entitiesConformityTable.Columns.Add("type");
	entitiesConformityTable.Columns.Add("catalogName");
	entitiesConformityTable.Columns.Add("isContainer");
	entitiesConformityTable.Columns.Add("connection");
	entitiesConformityTable.Columns.Add("item");
	
	conformityData = "STORE;like_stores;0|"+
					 "ACCOUNT;like_accounts;0|"+
					 "ACCOUNTINGCATEGORY;like_accountingCategories;0|"+
					 "CASHPAYMENTTYPE;like_paymentTypes;0|"+
					 "CASHREGISTER;like_cashRegisters;0|"+
					 "CONCEPTION;like_conceptions;0|"+  
					 "DEPARTMENT;like_departments;0|"+
					 "MEASUREUNIT;like_measureUnits;0|"+
					 "NONCASHPAYMENTTYPE;like_paymentTypes;0|"+
					 "PRODUCT;like_products;0|"+
					 "PRODUCTGROUP;like_products;1|"+
					 "USER;like_users;0";
	conformityRows = StrSplit(conformityData, "|");
	For each cRow In conformityRows Do
		rowCells = StrSplit(cRow, ";");
		newConformity 			  = entitiesConformityTable.Add();
		newConformity.type 		  = rowCells[0];
		newConformity.catalogName = rowCells[1];
		newConformity.isContainer = Boolean(Number(rowCells[2]));
	EndDo;
	
	Return entitiesConformityTable;
	
EndFunction

Function GetStringValue(value)
	
	Return ?(TypeOf(value) = Type("String"), value, "");
	
EndFunction

Procedure ExeItem(connection, item, ecTable, entitiesTable)
	
	foundType 	  = ecTable.Find(Upper(item.type), "type");
	
	If ValueIsFilled(foundType) Then
		r			= item.r;
		catalogName = foundType.catalogName;
		
		newEntity = entitiesTable.Add();
		newEntity.connection  = connection;
		newEntity.entityType  = foundType.type;
		newEntity.catalogName = foundType.catalogName;
		newEntity.isContainer = foundType.isContainer;
		newEntity.revision	  = Number(r.revision);
		newEntity.id		  = item.id;
		newEntity.deleted	  = r.deleted;
		If foundType.type <> "CASHREGISTER" AND foundType.type <> "DEPARTMENT" Then
			newEntity.code	  = GetStringValue(r.code);
			newEntity.description = r.name.customValue;
		ElsIf foundType.type = "CASHREGISTER" Then
			newEntity.code	  = GetStringValue(r.number);
			newEntity.description = r.name.customValue;
		ElsIf foundType.type = "DEPARTMENT" Then
			newEntity.code	  = GetStringValue(r.departmentId);
			newEntity.description = r.name;
		EndIf;
		
		If  foundType.type = "ACCOUNT" OR
			foundType.type = "PRODUCT" OR
			foundType.type = "PRODUCTGROUP" OR
			foundType.type = "STORE" Then
			
			newEntity.parentID = GetStringValue(r.parent);
		EndIf;
		
		If foundType.type = "CASHPAYMENTTYPE" Then
			newEntity.isCash = True;
		EndIf;
		
		If foundType.type = "PRODUCT" OR
		   foundType.type = "PRODUCTGROUP" Then
		   
			newEntity.accountingCategoryID = GetStringValue(r.accountingCategory);
			newEntity.num				   = GetStringValue(r.num);
		EndIf;
		
		If foundType.type = "PRODUCT" Then
			newEntity.mainUnitID		   = GetStringValue(r.mainUnit);
			newEntity.productType          = Enums.like_productTypes[r.type];
		EndIf;
		
		If foundType.type = "USER" Then
			supplierType = GetStringValue(r.supplierType);
			newEntity.userSupplierType  =  ?(ValueIsFilled(supplierType), Enums.like_supplierTypes[supplierType], Enums.like_supplierTypes.EmptyRef());
			
			newEntity.userIsClient 		= r.client;
			newEntity.userIsEmployee	= r.employee;
			newEntity.userIsPluginUser	= r.pluginUser;
			newEntity.userIsSupplier	= r.supplier;
			newEntity.userIsSystem      = r.system;
		EndIf;
	EndIf;

EndProcedure

Procedure SetEntititesVersion(connection, eVersion)
	
	manager = InformationRegisters.like_entititesVersions.CreateRecordSet();
	filter = manager.Filter;
	filter.connection.Set(connection);
	manager.Read();
	                  
	If manager.Count() = 1 Then
		manager[0].entityVersion = eVersion;	
		manager.Write();
	EndIf;	
	
EndProcedure

Function FillRefs(entitiesTable)
	
	fQuery = New Query("SELECT
	                   |	entitiesTable.connection AS connection,
	                   |	entitiesTable.entityType AS entityType,
	                   |	entitiesTable.catalogName AS catalogName,
	                   |	entitiesTable.isContainer AS isContainer,
	                   |	entitiesTable.revision AS revision,
	                   |	entitiesTable.id AS id,
	                   |	entitiesTable.deleted AS deleted,
	                   |	entitiesTable.code AS code,
					   |	entitiesTable.num AS num,
	                   |	entitiesTable.description AS description,
	                   |	entitiesTable.parentID AS parentID,
	                   |	entitiesTable.accountingCategoryID AS accountingCategoryID,
	                   |	entitiesTable.isCash AS isCash,
	                   |	entitiesTable.mainUnitID AS mainUnitID,
	                   |	entitiesTable.productType AS productType,
	                   |	entitiesTable.userSupplierType AS userSupplierType,
	                   |	entitiesTable.userIsClient AS userIsClient,
	                   |	entitiesTable.userIsEmployee AS userIsEmployee,
	                   |	entitiesTable.userIsPluginUser AS userIsPluginUser,
	                   |	entitiesTable.userIsSupplier AS userIsSupplier,
	                   |	entitiesTable.userIsSystem AS userIsSystem
	                   |INTO eTable
	                   |FROM
	                   |	&entitiesTable AS entitiesTable
	                   |;
	                   |
	                   |////////////////////////////////////////////////////////////////////////////////
	                   |SELECT
	                   |	Accounts.UUID AS UUID,
	                   |	Accounts.Ref AS Ref,
	                   |	Accounts.revision AS revision
	                   |INTO tmpRefs
	                   |FROM
	                   |	eTable AS eTable
	                   |		INNER JOIN Catalog.like_accounts AS Accounts
	                   |		ON eTable.id = Accounts.UUID
	                   |			AND eTable.connection = Accounts.connection
	                   |WHERE
	                   |	eTable.entityType = ""ACCOUNT""
	                   |
	                   |UNION
	                   |
	                   |SELECT
	                   |	accountingCategories.UUID,
	                   |	accountingCategories.Ref,
	                   |	accountingCategories.revision
	                   |FROM
	                   |	eTable AS eTable
	                   |		INNER JOIN Catalog.like_accountingCategories AS accountingCategories
	                   |		ON eTable.id = accountingCategories.UUID
	                   |			AND eTable.connection = accountingCategories.connection
	                   |WHERE
	                   |	eTable.entityType = ""ACCOUNTINGCATEGORY""
	                   |
	                   |UNION
	                   |
	                   |SELECT
	                   |	paymentTypes.UUID,
	                   |	paymentTypes.Ref,
	                   |	paymentTypes.revision
	                   |FROM
	                   |	eTable AS eTable
	                   |		INNER JOIN Catalog.like_paymentTypes AS paymentTypes
	                   |		ON eTable.id = paymentTypes.UUID
	                   |			AND eTable.connection = paymentTypes.connection
	                   |WHERE
	                   |	(eTable.entityType = ""CASHPAYMENTTYPE""
	                   |			OR eTable.entityType = ""NONCASHPAYMENTTYPE"")
	                   |
	                   |UNION
	                   |
	                   |SELECT
	                   |	like_cashRegisters.UUID,
	                   |	like_cashRegisters.Ref,
	                   |	like_cashRegisters.revision
	                   |FROM
	                   |	eTable AS eTable
	                   |		INNER JOIN Catalog.like_cashRegisters AS like_cashRegisters
	                   |		ON eTable.id = like_cashRegisters.UUID
	                   |			AND eTable.connection = like_cashRegisters.connection
	                   |WHERE
	                   |	eTable.entityType = ""CASHREGISTER""
	                   |
	                   |UNION
	                   |
	                   |SELECT
	                   |	like_conceptions.UUID,
	                   |	like_conceptions.Ref,
	                   |	like_conceptions.revision
	                   |FROM
	                   |	eTable AS eTable
	                   |		INNER JOIN Catalog.like_conceptions AS like_conceptions
	                   |		ON eTable.id = like_conceptions.UUID
	                   |			AND eTable.connection = like_conceptions.connection
	                   |WHERE
	                   |	eTable.entityType = ""CONCEPTION""
	                   |
	                   |UNION
	                   |
	                   |SELECT
	                   |	like_departments.UUID,
	                   |	like_departments.Ref,
	                   |	like_departments.revision
	                   |FROM
	                   |	eTable AS eTable
	                   |		INNER JOIN Catalog.like_departments AS like_departments
	                   |		ON eTable.id = like_departments.UUID
	                   |			AND eTable.connection = like_departments.connection
	                   |WHERE
	                   |	eTable.entityType = ""DEPARTMENT""
	                   |
	                   |UNION
	                   |
	                   |SELECT
	                   |	like_measureUnits.UUID,
	                   |	like_measureUnits.Ref,
	                   |	like_measureUnits.revision
	                   |FROM
	                   |	eTable AS eTable
	                   |		INNER JOIN Catalog.like_measureUnits AS like_measureUnits
	                   |		ON eTable.id = like_measureUnits.UUID
	                   |			AND eTable.connection = like_measureUnits.connection
	                   |WHERE
	                   |	eTable.entityType = ""MEASUREUNIT""
	                   |
	                   |UNION
	                   |
	                   |SELECT
	                   |	like_products.UUID,
	                   |	like_products.Ref,
	                   |	like_products.revision
	                   |FROM
	                   |	eTable AS eTable
	                   |		INNER JOIN Catalog.like_products AS like_products
	                   |		ON eTable.id = like_products.UUID
	                   |			AND eTable.connection = like_products.connection
	                   |WHERE
	                   |	eTable.entityType = ""PRODUCT""
	                   |
	                   |UNION
	                   |
	                   |SELECT
	                   |	like_products.UUID,
	                   |	like_products.Ref,
	                   |	like_products.revision
	                   |FROM
	                   |	eTable AS eTable
	                   |		INNER JOIN Catalog.like_products AS like_products
	                   |		ON eTable.id = like_products.UUID
	                   |			AND eTable.connection = like_products.connection
	                   |WHERE
	                   |	eTable.entityType = ""PRODUCTGROUP""
	                   |
	                   |UNION
	                   |
	                   |SELECT
	                   |	like_stores.UUID,
	                   |	like_stores.Ref,
	                   |	like_stores.revision
	                   |FROM
	                   |	eTable AS eTable
	                   |		INNER JOIN Catalog.like_stores AS like_stores
	                   |		ON eTable.id = like_stores.UUID
	                   |			AND eTable.connection = like_stores.connection
	                   |WHERE
	                   |	eTable.entityType = ""STORE""
	                   |
	                   |UNION
	                   |
	                   |SELECT
	                   |	like_users.UUID,
	                   |	like_users.Ref,
	                   |	like_users.revision
	                   |FROM
	                   |	eTable AS eTable
	                   |		INNER JOIN Catalog.like_users AS like_users
	                   |		ON eTable.id = like_users.UUID
	                   |			AND eTable.connection = like_users.connection
	                   |WHERE
	                   |	eTable.entityType = ""USER""
	                   |;
	                   |
	                   |////////////////////////////////////////////////////////////////////////////////
	                   |SELECT
	                   |	eT.connection AS connection,
	                   |	eT.entityType AS entityType,
	                   |	eT.catalogName AS catalogName,
	                   |	eT.isContainer AS isContainer,
	                   |	eT.revision AS revision,
	                   |	eT.id AS UUID,
	                   |	tmpRefs.Ref AS Ref,
	                   |	eT.deleted AS DeletionMark,
	                   |	eT.code AS Code,
					   |	eT.num AS Num,
	                   |	eT.description AS Description,
	                   |	eT.parentID AS parentID,
	                   |	eT.accountingCategoryID AS accountingCategoryID,
	                   |	eT.isCash AS isCash,
	                   |	eT.mainUnitID AS mainUnitID,
	                   |	eT.productType AS type,
	                   |	eT.userSupplierType AS supplierType,
	                   |	eT.userIsClient AS client,
	                   |	eT.userIsEmployee AS employee,
	                   |	eT.userIsPluginUser AS pluginUser,
	                   |	eT.userIsSupplier AS supplier,
	                   |	eT.userIsSystem AS system
	                   |FROM
	                   |	eTable AS eT
	                   |		LEFT JOIN tmpRefs AS tmpRefs
	                   |		ON eT.id = tmpRefs.UUID");
	fQuery.SetParameter("entitiesTable", entitiesTable);
	Return fQuery.Execute().Unload();
	
EndFunction

Function MajorVersion(connectionVersion)

	versionParts = StrSplit(connectionVersion, ".");
	
	If Not versionParts.Count() > 0 Then
		Raise NStr("ru = 'Не удалось получить части версии'");
	EndIf;
	
	Return Number(versionParts[0]);
	
EndFunction

Procedure Update(parameters, resultLink, interactive = False) Export

	ActiveConnection = like_ConnectionAtServer.GetActiveConnecton();
	If ActiveConnection = Undefined Then
		Return;
	EndIf;

	If Not (Interactive Or ActiveConnection.backgroundUpdate) Then
		Return;
	EndIf;

	// 1. Получить текущую revision с сервиса (сервис хранит состояние синхронизации)
	revision = like_CoreAPI.GetEntitiesRevision();

	// 2. Построить XML-запрос к IIKO с revision от сервиса
	XMLPackage = GetXMLEntitiesUpdateWithRevision(ActiveConnection, revision);
	ConnectionFields = like_ConnectionAtServer.GetConnectionFields(ActiveConnection);

	ObjectFields = like_CommonAtServer.GetObjectFieldsStructure();
	ObjectFields.ConProps    = ConnectionFields;
	ObjectFields.Resource    = "/resto/services/update";
	ObjectFields.RequestType = "POST";
	ObjectFields.Headers     = like_Common.getIIKOHeaders(ConnectionFields);
	ObjectFields.Body        = XMLPackage;
	ObjectFields.isGZIP      = True;
	ObjectFields.Namespace   = "https://izi.cloud/iiko/reading/entitiesUpdate";
	ObjectFields.TypeName    = "entitiesUpdateResponse";
	Params = New Map;
	Params.Insert("methodName", "waitEntitiesUpdate");
	ObjectFields.Parameters  = Params;

	// 3. Получить XDTO-ответ от IIKO и разобрать локально (в LAN — быстро)
	IIKOResponse = like_CommonAtServer.GetIikoObject(ObjectFields);
	If IIKOResponse = Undefined Then
		Return;
	EndIf;

	newRevision = IIKOResponse.entitiesUpdate.revision;
	updateItems = IIKOResponse.entitiesUpdate.items.i;

	// 4. Разобрать сущности и записать в справочники 1С
	ExeItems(updateItems, ActiveConnection, newRevision);

	// 5. Сохранить состояние на сервисе (только revision + UUID для трекинга)
	persistObjects = BuildPersistObjects(ActiveConnection, newRevision);
	like_CoreAPI.PersistEntities(newRevision, persistObjects);

EndProcedure

// Строит XML-тело запроса к IIKO с явно переданной revision.
// В отличие от GetXMLEntitiesUpdate, не читает revision из БД 1С —
// она теперь хранится на сервисе.
Function GetXMLEntitiesUpdateWithRevision(connection, revision)

	argsType = XDTOFactory.Type("https://izi.cloud/iiko/reading/entitiesUpdate", "args");
	args = XDTOFactory.Create(argsType);

	args.entities_version               = revision;
	args.client_type                    = "BACK";
	args.enable_warnings                = False;
	args.request_watchdog_check_results = False;
	args.use_raw_entities               = True;
	args.fromRevision                   = revision;
	args.timeoutMillis                  = 30000;
	args.useRawEntities                 = True;

	Return like_CommonAtServer.XDTO2XML(args);

EndFunction

Procedure ExeItems(updateItems, connection, revision) Export
	
	ecTable 	  = GetEntitiesConformityTable();
	entitiesTable = GetEntititesTableDefinition();
	
	If TypeOf(updateItems) = Type("XDTOList") Then
		For each item In updateItems Do  
			ExeItem(connection, item, ecTable, entitiesTable);
		EndDo;
	ElsIf TypeOf(updateItems) = Type("XDTODataObject") Then
		ExeItem(connection, updateItems, ecTable, entitiesTable);	
	EndIf;

	entitiesTable = FillRefs(entitiesTable);
	
	For each entityItem In entitiesTable Do
		
		BeginTransaction();
		
		Try
		
			If entityItem.Ref = Null Then
				If entityItem.isContainer Then
					entity = Catalogs[entityItem.catalogName].CreateFolder();
				Else
					entity = Catalogs[entityItem.catalogName].CreateItem();
				EndIf;                                                        
				newRef = Catalogs[entityItem.catalogName].GetRef(New UUID(entityItem.UUID));
				entity.SetNewObjectRef(newRef);
				entity.revision   = -1;
			Else
				entity = entityItem.Ref.GetObject();
			EndIf;

			If entityItem.revision > entity.revision Then
				excludeFields = ?(entityItem.isContainer, "accountingCategoryID,mainUnitID,num,type", "");
				FillPropertyValues(entity, entityItem,, excludeFields);
				
				If entityItem.Ref = Null Then
					If entity.Metadata().Attributes.Find("ParentID") <> Undefined Then
						If ValueIsFilled(entity.ParentID) Then
							entity.Parent = Catalogs[entityItem.catalogName].GetRef(New UUID(entity.ParentID));
						EndIf;
					EndIf;
					
					If entity.Metadata().Attributes.Find("accountingCategoryID") <> Undefined Then
						If ValueIsFilled(entity.accountingCategoryID) Then
							entity.accountingCategory = Catalogs.like_accountingCategories.GetRef(New UUID(entity.accountingCategoryID));
						EndIf;
					EndIf;
					
					If entity.Metadata().Attributes.Find("mainUnitID") <> Undefined Then
						If ValueIsFilled(entity.mainUnitID) Then
							entity.measureUnit = Catalogs.like_measureUnits.GetRef(New UUID(entity.mainUnitID));
						EndIf;
					EndIf;
				EndIf;
				
				entity.Write();
			EndIf;	
			
			CommitTransaction();
				
		Except
			
			If TransactionActive() Then
				RollbackTransaction();
			EndIf;
			
			WriteLogEvent("Object writing", EventLogLevel.Error, entity, entityItem, ErrorDescription()); 
			
		EndTry;
			
	EndDo;
	
	SetEntititesVersion(connection, revision);	
	
EndProcedure

// Собирает массив объектов для отправки на сервис (трекинг состояния).
// Вызывается после ExeItems — читает то, что было обработано.
Function BuildPersistObjects(connection, revision)

	// Для простоты — отправляем только revision без списка объектов.
	// Сервис обновит entity_versions. Object_matching на сервисе
	// используется только для фильтрации при облачном парсинге (sync),
	// а при локальном парсинге фильтрация делается в 1С по revision в справочниках.
	Return New Array;

EndFunction

Procedure BackgroundUpdate() Export
	
	ProcedureParameters = New Structure;
    ExecuteParameters = ДлительныеОперации.ПараметрыВыполненияВФоне(New UUID("a6930c4c-9137-11e9-bc42-526af7764f64"));
	ДлительныеОперации.ВыполнитьВФоне("like_EntitiesAtServer.Update", ProcedureParameters, ExecuteParameters);
	
EndProcedure