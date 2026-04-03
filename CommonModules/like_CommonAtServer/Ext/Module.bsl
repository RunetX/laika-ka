///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019-2023, Tian Semen Sergeevich (semen@tyan.pw), https://tyan.pw
// All rights reserved. This program and accompanying materials 
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

Function GetHash(str) Export
	Hash = New DataHashing(HashFunction.SHA1);
	Hash.Append(Str);
	Return Lower(StrReplace(TrimAll(Hash.HashSum)," ", ""));
EndFunction

Function XML2XDTO(XML, namespace, typename) Export
	XML = like_Common.InsertAttr(XML, Typename, "xmlns", Namespace);
	XMLReader = New XMLReader;
	XMLReader.SetString(XML);
	objectType = XDTOFactory.Type(Namespace, Typename);
	Return XDTOFactory.ReadXML(XMLReader, objectType);	
EndFunction

Function XDTO2XML(XDTOObject) Export
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XDTOFactory.WriteXML(XMLWriter, XDTOObject);
	Return XMLWriter.Close();
EndFunction

Function GetStructureWithFields(fieldsString) Export
	
	Return New Structure(fieldsString);
	
EndFunction

Function GetTableDescription(columnsString) Export
	
	parametersTable = New ValueTable;
	For Each column In StrSplit(columnsString, ",") Do
		parametersTable.Columns.Add(column);
	EndDo;
	
	Return parametersTable;	
	
EndFunction

Function GetObjectFieldsStructure() Export
	
	Return GetStructureWithFields("ConProps, Resource, Namespace, TypeName, RequestType, Parameters, Headers, Body, isGZIP");
	
EndFunction

//ObjectFields - structure with fields:
// - ConProps - structure with connection properties like host, port
// - Resource - the target address of the HTTP request
// - Namespace
// - TypeName
// - RequestType - GET, POST, etc.
// - Parameters - map, contain name->value pairs for the request
// - Headers
// - Body
// - isGZIP - compression response boolean flag 
Function GetIikoObject(objectFields) Export

	XMLResponse = ExecuteIikoHTTPRequest(objectFields);
	If XMLResponse = Undefined Then
		Return Undefined;
	EndIf;
	Return XML2XDTO(XMLResponse, ObjectFields.Namespace, ObjectFields.TypeName);

EndFunction

Function GetIikoDate(date1C, ms) Export

	dWriter = New JSONWriter;
	dWriter.SetString();
	JSONCfg = New JSONSerializerSettings;
	JSONCfg.DateSerializationFormat = JSONDateFormat.ISO;
	JSONCfg.DateWritingVariant = JSONDateWritingVariant.LocalDateWithOffset;
	WriteJSON(dWriter, date1C, JSONCfg);
	IIKODate = dWriter.Close();
	IIKODate = Mid(IIKODate, 2, 25);
	datePart1 = Left(IIKODate, 19);
	datePart2 = Right(IIKODate, 6);
	Return datePart1 + "." + ms + datePart2;

EndFunction

Function GetIikoRawXML(objectFields) Export

	Return ExecuteIikoHTTPRequest(objectFields);

EndFunction

Function ExecuteIikoHTTPRequest(objectFields)

	ParametersString = "";
	If objectFields.Parameters <> Undefined Then
		ParametersArray = New Array;
		For Each Parameter In objectFields.Parameters Do
			ParametersArray.Add(Parameter.Key + "=" + EncodeString(Parameter.Value, StringEncodingMethod.URLEncoding));
		EndDo;
		ParametersString = "?" + StrConcat(ParametersArray, "&");
	EndIf;

	IIKORequest = New HTTPRequest(objectFields.Resource + ParametersString, objectFields.Headers);
	If objectFields.Body <> Undefined Then
		IIKORequest.SetBodyFromString(objectFields.Body);
	EndIf;

	cp = objectFields.ConProps;
	If cp.isSecure Then
		IIKOConnection = New HTTPConnection(cp.host, cp.port, cp.user, cp.password,,, New OpenSSLSecureConnection());
	Else
		IIKOConnection = New HTTPConnection(cp.host, cp.port, cp.user, cp.password);
	EndIf;

	IIKOResponse = IIKOConnection.CallHTTPMethod(objectFields.RequestType, IIKORequest);

	If IIKOResponse.StatusCode <> 200 Then
		WriteLogEvent("IIKO. transport", EventLogLevel.Error,, IIKOResponse,
			NStr("en = 'Server returned HTTP '; ru = 'Сервер вернул HTTP '") + IIKOResponse.StatusCode);
		Return Undefined;
	EndIf;

	Return ?(IIKOResponse.Headers.Get("content-encoding") = "gzip",
		like_Common.DecompressGZIP(IIKOResponse.GetBodyAsBinaryData()),
		IIKOResponse.GetBodyAsString("UTF-8"));

EndFunction

Function GetMatchedObject(matchedObjects, ref1C, matchingType = Undefined) Export
	           
	If Not ValueIsFilled(matchingType) Then
		matchingType = Enums.like_matchingTypes.EmptyRef();
	EndIf;
	
	filter = New Structure("ref1C,mType", ref1C, matchingType);
	foundRows = matchedObjects.FindRows(filter);
	
	If foundRows.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	Return foundRows[0].likeRef;
	
EndFunction

Procedure LogWrite(message) Export
		
	Try		          
		File = New TextWriter(TempFilesDir()+"like.log",,,Истина);
		File.WriteLine("["+CurrentDate()+"] " + Message);
		File.Close();	
	Except
		Raise(ErrorDescription()); 
	EndTry;
	
EndProcedure