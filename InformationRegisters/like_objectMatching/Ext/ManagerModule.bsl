Procedure MatchingAdd(connection,
	ref1C, 
	likeRef, 
	docType, 
	matchingType) Export
	
	newMathing = InformationRegisters.like_objectMatching.CreateRecordManager();
	newMathing.connection	= connection;
	newMathing.ref1C 		= ref1C;
	newMathing.docType		= docType;
	newMathing.likeRef		= likeRef;
	newMathing.matchingType = matchingType;
	newMathing.Write();
	
EndProcedure