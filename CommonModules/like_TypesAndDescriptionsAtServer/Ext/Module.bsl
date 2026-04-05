///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021, ООО Изи Клауд, https://izi.cloud
// All rights reserved. This program and accompanying materials 
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

Function GetDescriptionMap() Export
	
	descriptions = New Map;
	
	// qualifiers section
	boolIntQualifier			  = New NumberQualifiers(1, 0, AllowedSign.Nonnegative);
	smallIntQualifier			  = New NumberQualifiers(5, 0, AllowedSign.Nonnegative);
	revisionQualifier     		  = New NumberQualifiers(10, 0, AllowedSign.Any);
	sumQualifier				  = New NumberQualifiers(10, 3, AllowedSign.Any);
	shortStringQualifier  		  = New StringQualifiers(30,  AllowedLength.Variable);
	longStringQualifier   		  = New StringQualifiers(100, AllowedLength.Variable);
	UUIDQualifier		  		  = New StringQualifiers(36,  AllowedLength.Fixed);
	shortDateQualifier			  = New DateQualifiers(DateFractions.Date);
	longDateQualifier             = New DateQualifiers(DateFractions.DateTime);
	// types description section
	descriptions.Insert("connection", 	New TypeDescription("CatalogRef.like_connections"));
	descriptions.Insert("shortString", 	New TypeDescription("String", , shortStringQualifier));
	descriptions.Insert("longString", 	New TypeDescription("String", , longStringQualifier));
	descriptions.Insert("boolInt",		New TypeDescription("Number",	boolIntQualifier));
	descriptions.Insert("smallInt",		New TypeDescription("Number",	smallIntQualifier));
	descriptions.Insert("revision", 	New TypeDescription("Number", 	revisionQualifier));
	descriptions.Insert("sum",			New TypeDescription("Number",	sumQualifier));
	descriptions.Insert("UUID", 		New TypeDescription("String", , UUIDQualifier));
	descriptions.Insert("boolean", 		New TypeDescription("Boolean"));
	descriptions.Insert("shortDate",	New TypeDescription("Date", , , shortDateQualifier));
	descriptions.Insert("longDate",		New TypeDescription("Date", , , longDateQualifier));
	parentTypes			   		  = New Array;
	parentTypes.Add("CatalogRef.like_accounts");
	parentTypes.Add("CatalogRef.like_products");
	parentTypes.Add("CatalogRef.like_stores");
	descriptions.Insert("parent", 		New TypeDescription(parentTypes));
	parentTypes.Add("CatalogRef.like_accountingCategories");
	parentTypes.Add("CatalogRef.like_conceptions");
	parentTypes.Add("CatalogRef.like_measureUnits");
	parentTypes.Add("CatalogRef.like_paymentTypes");
	parentTypes.Add("CatalogRef.like_users");
	descriptions.Insert("catalogs", 			New TypeDescription(parentTypes));
	descriptions.Insert("accountingCategory", 	New TypeDescription("CatalogRef.like_accountingCategories"));
	descriptions.Insert("cashRegister",			New TypeDescription("CatalogRef.like_cashRegisters"));
	descriptions.Insert("conception",			New TypeDescription("CatalogRef.like_conceptions"));
	descriptions.Insert("customer",				New TypeDescription("CatalogRef.like_customers"));
	descriptions.Insert("department",			New TypeDescription("CatalogRef.like_departments"));
	descriptions.Insert("measureUnit", 			New TypeDescription("CatalogRef.like_measureUnits"));
	descriptions.Insert("paymentType",			New TypeDescription("CatalogRef.like_paymentTypes"));
	descriptions.Insert("product",				New TypeDescription("CatalogRef.like_products"));
	descriptions.Insert("store",				New TypeDescription("CatalogRef.like_stores"));
	descriptions.Insert("productType", 			New TypeDescription("EnumRef.like_productTypes"));
	descriptions.Insert("userSupplierType", 	New TypeDescription("EnumRef.like_supplierTypes"));
	
	Return descriptions;
	
EndFunction

Function GetDescription(descriptionKey) Export
	
	Return GetDescriptionMap().Get(descriptionKey);
	
EndFunction

Function GetTableWithColumns(columnsString) Export
	
	dsc = GetDescriptionMap();
	newTable = New ValueTable;
	For each nameType In StrSplit(columnsString, "|") Do		
		nameTypeList = StrSplit(nameType, ";");
		newTable.Columns.Add(nameTypeList[0], dsc.Get(nameTypeList[1]));	
	EndDo;
	Return newTable;
	
EndFunction