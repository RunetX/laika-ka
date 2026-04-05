Procedure MatchingAdd(connection, ref1C, docStruct) Export

	// Запись в локальный регистр (fallback)
	newMathing = InformationRegisters.like_documentsMatching.CreateRecordManager();
	newMathing.connection = connection;
	newMathing.ref1C 	  = ref1C;
	FillPropertyValues(newMathing, docStruct);
	newMathing.Write();

	// Dual-write: дублируем на Go сервис (primary storage)
	connectionID = String(connection.UUID());
	items = New Array;
	item = New Map;
	item.Insert("ref1C",       String(ref1C.UUID()));
	item.Insert("ref1CType",   like_Common.TypeNameShort(ref1C));
	item.Insert("yearCreated", String(docStruct.yearCreated));
	item.Insert("docNumber",   docStruct.number);
	item.Insert("docType",     docStruct.type);
	items.Add(item);
	like_CoreAPI.SaveDocumentMatchings(connectionID, items);

EndProcedure