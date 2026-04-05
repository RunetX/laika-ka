Procedure MatchingAdd(connection,
	ref1C, 
	likeRef, 
	docType, 
	matchingType) Export

	selection = InformationRegisters.like_objectMatching.Select(,
		New Structure("connection, ref1C, docType, matchingType",
			connection,
			ref1C,
			docType,
			matchingType));

	recordSet = InformationRegisters.like_objectMatching.CreateRecordSet();

	While selection.Next() Do
		row = recordSet.Add();
		row.Ref = selection.Ref;
		row.RecordDeletion = True;
	EndDo;

	If recordSet.Count() > 0 Then
		recordSet.Write();
	EndIf;

	newMatching = InformationRegisters.like_objectMatching.CreateRecordManager();
	newMatching.connection   = connection;
	newMatching.ref1C        = ref1C;
	newMatching.docType      = docType;
	newMatching.likeRef      = likeRef;
	newMatching.matchingType = matchingType;
	newMatching.Write();

EndProcedure

Procedure ClearLikeObjectMatchingDuplicates() Export

    // Перед запуском обязательно сделайте копию базы!

    // Отберём все записи с сортировкой по ключу и Ref
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

        // Первую запись по комбинации ключа оставляем (она с минимальным Ref),
        // все последующие по этой же комбинации помечаем на удаление.
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