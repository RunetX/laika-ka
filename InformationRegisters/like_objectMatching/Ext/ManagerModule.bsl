Procedure MatchingAdd(connection,
	ref1C,
	likeRef,
	docType,
	matchingType) Export

	// Запись в локальный регистр (fallback)
	newMathing = InformationRegisters.like_objectMatching.CreateRecordManager();
	newMathing.connection	= connection;
	newMathing.ref1C 		= ref1C;
	newMathing.docType		= docType;
	newMathing.likeRef		= likeRef;
	newMathing.matchingType = matchingType;
	newMathing.Write();

	// Dual-write: дублируем на Go сервис (primary storage)
	connectionID = String(connection.UUID());
	items = New Array;
	item = New Map;
	item.Insert("ref1C",        String(ref1C.UUID()));
	item.Insert("ref1CType",    like_Common.TypeNameShort(ref1C));
	item.Insert("docType",      docType);
	item.Insert("matchingType", String(matchingType));
	item.Insert("likeRef",      String(likeRef.UUID()));
	item.Insert("likeRefType",  like_Common.TypeNameShort(likeRef));
	items.Add(item);
	like_CoreAPI.SaveRefMatchings(connectionID, items);

EndProcedure

Procedure ClearLikeObjectMatchingDuplicates() Export

	Query = New Query(
        "SELECT
        |   lom.connection,
        |   lom.ref1C,
        |   lom.docType,
        |   lom.matchingType,
        |   lom.likeRef
        |FROM
        |   InformationRegister.like_objectMatching AS lom
        |ORDER BY
        |   lom.connection,
        |   lom.ref1C,
        |   lom.docType,
        |   lom.matchingType,
        |   lom.likeRef");

    Selection = Query.Execute().Select();
    RecordSet = InformationRegisters.like_objectMatching.CreateRecordSet();

    lastKey = Undefined;
    
    While Selection.Next() Do

        currentKey = New Structure("connection, ref1C, docType, matchingType",
            Selection.connection,
            Selection.ref1C,
            Selection.docType,
            Selection.matchingType);

        If lastKey <> Undefined And currentKey = lastKey Then
            
            row = RecordSet.Add();
            row.likeRef = Selection.likeRef;
            row.RecordDeletion = True;

        Else
            lastKey = currentKey;
        EndIf;

    EndDo;

    If RecordSet.Count() > 0 Then
        RecordSet.Write();
    EndIf;

EndProcedure

Procedure RefillMatchings() Export
	
	// Select all unique key combinations
	Query = New Query("SELECT DISTINCT * FROM InformationRegister.like_objectMatching");
	ExportData = Query.Execute().Unload();

	// Completely clear the register
	RecordSet = InformationRegisters.like_objectMatching.CreateRecordSet();
	RecordSet.Write(); 

	// Write data back
	For Each Row In ExportData Do
	    NewRecord = RecordSet.Add();
	    FillPropertyValues(NewRecord, Row);
	    Try
	        RecordSet.Write(False); // Write one record at a time
	    Except
	        Message("Duplicate found! " + Row.ref1C);
	    EndTry;
	    RecordSet.Clear();
	EndDo;
	
EndProcedure