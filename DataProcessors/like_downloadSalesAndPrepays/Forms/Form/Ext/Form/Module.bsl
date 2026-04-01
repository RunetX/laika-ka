&AtServer
Function prepaysRequest()
	
	sqlRequest = "SELECT 
	|	AT.sum, 
	|	AT.sumNds, 
	|	AT.ndsPercent, 
	|	AT.paymentType AS paymentTypeId, 
	|	Reserve.customerId 
	|FROM AccountingTransaction AS AT
	|INNER JOIN Reserve AS Reserve
	|  	ON AT.orderId = Reserve.orderId
	|  	AND Reserve.isBanquet = '1'
	|WHERE AT.type = 'PREPAY'
	|	AND (AT.date >= CONVERT(datetime,'[startdate] 00:00:00.000', 120) 
	|	AND AT.date < CONVERT(datetime,'[enddate] 23:59:59.999', 120))";
	
	sqlParameters = New Map;
	sqlParameters.Insert("startdate", Format(prepaysDate, "DF=yyyy-MM-dd"));
	sqlParameters.Insert("enddate", Format(prepaysDate, "DF=yyyy-MM-dd"));
	
	Return like_SQLRequestsAtServer.RequestSQL(sqlRequest, sqlParameters);
	
EndFunction

&AtServer
Function GetTableWithColumns(columnsString)
	
	dsc = like_TypesAndDescriptionsAtServer.GetDescriptionMap();
	newTable = New ValueTable;
	For each nameType In StrSplit(columnsString, "|") Do		
		nameTypeList = StrSplit(nameType, ";");
		newTable.Columns.Add(nameTypeList[0], dsc.Get(nameTypeList[1]));	
	EndDo;
	Return newTable;
	
EndFunction

&AtServer
Function GetPrepaysData()
		
	prepaysObject = prepaysRequest();
	prepaysData   = GetTableWithColumns("pdate;shortDate"+
										"|sum;sum"+
										"|sumNds;sum"+
										"|ndsPercent;smallInt"+
										"|paymentTypeId;UUID"+
										"|paymentType;paymentType"+
										"|customerId;UUID"+
										"|customer;customer");
	
	If prepaysObject <> Undefined Then	
		prepaysData = like_SQLRequestsAtServer.SQLXDTO2Table(prepaysObject, prepaysData);
		prepaysQuery = New Query("SELECT
		                         |	pps.sum AS sum,
		                         |	pps.sumNds AS sumNds,
		                         |	pps.ndsPercent AS ndsPercent,
		                         |	pps.paymentTypeId AS paymentTypeId,
		                         |	pps.customerId AS customerId
		                         |INTO tmpPrepays
		                         |FROM
		                         |	&prepays AS pps
		                         |;
		                         |
		                         |////////////////////////////////////////////////////////////////////////////////
		                         |SELECT
		                         |	&pdate AS pdate,
		                         |	SUM(tPps.sum) AS sum,
		                         |	tPps.sumNds AS sumNds,
		                         |	tPps.ndsPercent AS ndsPercent,
		                         |	paymentTypes.Ref AS paymentType,
		                         |	customers.Ref AS customer
		                         |FROM
		                         |	tmpPrepays AS tPps
		                         |		INNER JOIN Catalog.like_paymentTypes AS paymentTypes
		                         |		ON tPps.paymentTypeId = paymentTypes.UUID
		                         |		INNER JOIN Catalog.like_customers AS customers
		                         |		ON tPps.customerId = customers.UUID
		                         |
		                         |GROUP BY
		                         |	tPps.sumNds,
		                         |	tPps.ndsPercent,
		                         |	paymentTypes.Ref,
		                         |	customers.Ref");
		prepaysQuery.SetParameter("prepays", prepaysData);
		prepaysQuery.SetParameter("pdate", prepaysDate);
		prepaysData = prepaysQuery.Execute().Unload();
		
		prepaysSummarySum = prepaysData.Total("sum");
	EndIf;
	
	Return prepaysData;
	
EndFunction

&AtServer
Function salesRequest()
	
	sqlRequest = "SELECT 
	|	OPE.date,
	|	OPE.department AS departmentId,
	|	OPE.cashRegister AS cashRegisterId,
	|	OPE.isBanquet,
	|	OPE.isDelivery,
	|	OPE.orderSum,
	|	OPE.orderSumAfterDiscount,
	|	OPE.session_id,
	|	OPE.sumCard,
	|	OPE.sumCash,
	|	OPE.sumCredit,
	|	OPE.sumPrepay,
	|	ISE.conception AS conceptionId,
	|	ISE.dishAmount,
	|	ISE.dishInfo AS dishId,
	|	ISE.dishSum,
	|	ISE.nds,
	|	ISE.ndsSum,
	|	ISE.orderId,
	|	ISE.store AS storeId,
	|	OC.customerId
	|FROM OrderPaymentEvent AS OPE
	|INNER JOIN ItemSaleEvent AS ISE
	|	ON OPE.[order] = ISE.orderId
	|LEFT JOIN OrderCustomer AS OC
	|	ON ISE.orderId = OC.orderId
	|WHERE (OPE.date >= CONVERT(datetime,'[startdate] 00:00:00.000', 120) 
	|   AND OPE.date <  CONVERT(datetime,'[enddate] 23:59:59.999', 120))
	|	AND ISE.deliverTime IS NOT NULL";
	
	sqlParameters = New Map;
	sqlParameters.Insert("startdate", Format(prepaysDate, "DF=yyyy-MM-dd"));
	sqlParameters.Insert("enddate", Format(prepaysDate, "DF=yyyy-MM-dd"));
	
	Return like_SQLRequestsAtServer.RequestSQL(sqlRequest, sqlParameters);
	
EndFunction

&AtServer
Function GetSalesData()
	
	salesObject = salesRequest();
	salesData = GetTableWithColumns("pdate;shortDate"+
									 "|departmentId;UUID"+
									 "|department;department"+
									 "|cashRegisterId;UUID"+
									 "|cashRegister;cashRegister"+
									 "|isBanquet;boolInt"+
									 "|isDelivery;boolInt"+
									 "|paymentType;paymentType"+
									 "|orderSum;sum"+
									 "|orderSumAfterDiscount;sum"+
									 "|session_id;UUID"+
									 "|sumCard;sum"+
									 "|sumCash;sum"+
									 "|sumCredit;sum"+
									 "|sumPrepay;sum"+
									 "|conceptionId;UUID"+
									 "|conception;conception"+
									 "|dishAmount;sum"+
									 "|dishId;UUID"+
									 "|product;product"+
									 "|dishSum;sum"+
									 "|nds;smallInt"+
									 "|ndsSum;sum"+
									 "|orderId;UUID"+
									 "|storeId;UUID"+
									 "|store;store"+
									 "|customerId;UUID"+
									 "|customer;customer");
	If salesObject <> Undefined Then
		salesData = like_SQLRequestsAtServer.SQLXDTO2Table(salesObject, salesData);	
		salesQuery = New Query("SELECT
		                       |	s.departmentId AS departmentId,
		                       |	s.cashRegisterId AS cashRegisterId,
		                       |	s.isBanquet AS isBanquet,
		                       |	s.isDelivery AS isDelivery,
		                       |	s.orderSum AS orderSum,
		                       |	s.orderSumAfterDiscount AS orderSumAfterDiscount,
		                       |	s.session_id AS session_id,
		                       |	s.sumCard AS sumCard,
		                       |	s.sumCash AS sumCash,
		                       |	s.sumCredit AS sumCredit,
		                       |	s.sumPrepay AS sumPrepay,
		                       |	s.conceptionId AS conceptionId,
		                       |	s.dishAmount AS dishAmount,
		                       |	s.dishId AS dishId,
		                       |	s.dishSum AS dishSum,
		                       |	s.nds AS nds,
		                       |	s.ndsSum AS ndsSum,
		                       |	s.orderId AS orderId,
		                       |	s.storeId AS storeId,
		                       |	s.customerId AS customerId
		                       |INTO tmpSales
		                       |FROM
		                       |	&sales AS s
		                       |;
		                       |
		                       |////////////////////////////////////////////////////////////////////////////////
		                       |SELECT
		                       |	&pdate AS pdate,
							   |	departments.Ref AS department,
							   |	cashRegisters.Ref AS cashRegister,
		                       |	Sales.isBanquet AS isBanquet,
		                       |	Sales.isDelivery AS isDelivery,
		                       |	Sales.orderSum AS orderSum,
		                       |	Sales.orderSumAfterDiscount AS orderSumAfterDiscount,
		                       |	Sales.session_id AS session_id,
		                       |	Sales.sumCard AS sumCard,
		                       |	Sales.sumCash AS sumCash,
		                       |	Sales.sumCredit AS sumCredit,
		                       |	Sales.sumPrepay AS sumPrepay,
		                       |	conceptions.Ref AS conception,
		                       |	Sales.dishAmount AS dishAmount,
							   |	products.Ref AS product,
		                       |	Sales.dishSum AS dishSum,
		                       |	Sales.nds AS nds,
		                       |	Sales.ndsSum AS ndsSum,
		                       |	Sales.orderId AS orderId,
							   |	stores.Ref AS store,
							   |	customers.Ref AS customer
		                       |INTO salesData
		                       |FROM
		                       |	tmpSales AS Sales
							   |		INNER JOIN Catalog.like_departments AS departments
							   |		ON Sales.departmentId = departments.UUID
							   |		INNER JOIN Catalog.like_cashRegisters AS cashRegisters
							   |		ON Sales.cashRegisterId = cashRegisters.UUID
							   |		LEFT JOIN Catalog.like_conceptions AS conceptions
							   |		ON Sales.conceptionId = conceptions.UUID
							   |		INNER JOIN Catalog.like_products AS products
							   |		ON Sales.dishId = products.UUID
							   |		INNER JOIN Catalog.like_stores AS stores
							   |		ON Sales.storeId = stores.UUID
							   |		LEFT JOIN Catalog.like_customers AS customers
							   |		ON Sales.customerId = customers.UUID
		                       |;
		                       |
		                       |////////////////////////////////////////////////////////////////////////////////
		                       |SELECT DISTINCT
		                       |	s.pdate AS pdate,
		                       |	s.session_id AS session_id,
		                       |	s.orderSum AS orderSum,
		                       |	s.orderSumAfterDiscount AS orderSumAfterDiscount,
		                       |	s.orderId AS orderId,
		                       |	s.sumCard AS sumCard,
		                       |	s.sumCash AS sumCash,
		                       |	s.sumCredit AS sumCredit,
		                       |	s.sumPrepay AS sumPrepay
		                       |INTO tmpSummary
		                       |FROM
		                       |	salesData AS s
		                       |;
		                       |
		                       |////////////////////////////////////////////////////////////////////////////////
		                       |SELECT
		                       |	tmpSummary.pdate AS pdate,
		                       |	SUM(tmpSummary.orderSum) AS salesSummarySum,
		                       |	SUM(tmpSummary.orderSumAfterDiscount) AS salesSummarySumAfterDiscount,
		                       |	COUNT(DISTINCT tmpSummary.orderId) AS salesSummaryOrdersNum,
		                       |	SUM(tmpSummary.sumCard) AS salesSummaryCard,
		                       |	SUM(tmpSummary.sumCash) AS salesSummaryCash,
		                       |	SUM(tmpSummary.sumCredit) AS salesSummaryCredit,
		                       |	SUM(tmpSummary.sumPrepay) AS salesSummaryPrepay
		                       |INTO salesSummary
		                       |FROM
		                       |	tmpSummary AS tmpSummary
		                       |
		                       |GROUP BY
		                       |	tmpSummary.pdate");
		salesQuery.SetParameter("sales", salesData);
		salesQuery.SetParameter("pdate", prepaysDate);  
		queryResults = salesQuery.ExecuteBatchWithIntermediateData();
		Return New Structure("Data, Summary", queryResults[1].Unload(), queryResults[3].Unload());
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtServer
Procedure requestSQLAtServer()
	
	prepays = GetPrepaysData();
	sales   = GetSalesData();
	prepaysTable.Load(prepays);
	
	If sales <> Undefined Then
		salesTable.Load(sales.Data);
		If sales.Summary.Count()>0 Then
			FillPropertyValues(ThisForm, sales.Summary[0]);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure NullSummaryData()
	
	prepaysSummarySum = 0;
	
	salesSummaryCard 			= 0;
	salesSummaryCash 			= 0;
	salesSummaryCredit 			= 0;
	salesSummaryPrepay 			= 0;
	salesSummarySum				= 0;
	salesSummarySumAfterDiscount= 0;
	salesSummaryOrdersNum 		= 0;
	
EndProcedure

&AtClient
Procedure prepaysDateOnChange(Item)
	
	If prepaysDate = Date(1, 1, 1) Then
		Message(NStr("en = 'Choose prepays date please'; ru = 'Выберите дату предоплат, пожалуйста'"));
		Return;
	EndIf;
	
	NullSummaryData();
	requestSQLAtServer();
	
EndProcedure
