
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ActiveConnection = like_ConnectionAtServer.GetActiveConnecton();
    
    GroupFilter = List.Filter.Items.Add(Type("DataCompositionFilterItem"));
	GroupFilter.LeftValue = New DataCompositionField("connection");
	GroupFilter.ComparisonType = DataCompositionComparisonType.InHierarchy;
	GroupFilter.RightValue = ActiveConnection;
	
    AppearanceItem = List.ConditionalAppearance.Items.Add();
	AppearanceItem.Appearance.SetParameterValue("Visible", False);
    
	AppearanceItem = List.ConditionalAppearance.Items.Add();
	AppearanceItem.Appearance.SetParameterValue("Visible", True);
	AppearanceItem.Appearance.SetParameterValue("Show", True);
	
	GroupFilter = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	GroupFilter.LeftValue = New DataCompositionField("connection");
	GroupFilter.ComparisonType = DataCompositionComparisonType.InHierarchy;
	GroupFilter.RightValue = ActiveConnection;

EndProcedure
