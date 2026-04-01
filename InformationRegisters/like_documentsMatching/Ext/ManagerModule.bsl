Procedure MatchingAdd(connection, ref1C, docStruct) Export
	
	newMathing = InformationRegisters.like_documentsMatching.CreateRecordManager();
	newMathing.connection = connection;
	newMathing.ref1C 	  = ref1C;
	FillPropertyValues(newMathing, docStruct);
	newMathing.Write();
	
EndProcedure