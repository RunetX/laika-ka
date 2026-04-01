#Region EventHandlers

&After("ПередНачаломРаботыСистемы")
Procedure like_BeforeStart()
	
	like_StandartSubsystemsAtClient.BeforeStart();	
	
EndProcedure

#EndRegion