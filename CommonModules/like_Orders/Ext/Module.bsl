Procedure Order1CFromIiko(DocumentID) Export

	// 1. Получить rawXML от IIKO
	rawXML = like_DocumentAtServer.GetDocumentRawXML(DocumentID);
	If rawXML = Undefined Then
		Raise NStr("en = 'Failed to get document from IIKO'; ru = 'Не удалось получить документ из IIKO'");
	EndIf;

	// 2. Разобрать на сервисе
	connectionID = String(like_ConnectionAtServer.GetActiveConnecton().UUID());
	parseResult = like_CoreAPI.ParseOrder(rawXML, connectionID);
	If Not parseResult.Success Then
		Raise NStr("en = 'Failed to parse order'; ru = 'Не удалось разобрать заказ'");
	EndIf;

	// 3. Создать мобильный заказ в 1С через адаптер
	activeConnection = like_ConnectionAtServer.GetActiveConnecton();
	settings = OrdersSettings(activeConnection);
	If settings = Undefined Or Not ValueIsFilled(settings.Организация) Then
		Raise NStr("ru = 'Не заполнены настройки загрузки заказов (регистр like_ordersSettings)'");
	EndIf;

	messages = New Array;
	mobileOrder = like_Adapter.CreateMobileOrder(parseResult.Order, settings);
	If mobileOrder <> Undefined Then
		МобильноеПриложениеЗаказыКлиентовПереопределяемый.СоздатьОбновитьЗаказКлиента(
			mobileOrder, messages);
	Else
		Raise NStr("ru = 'Не удалось сформировать мобильный заказ'");
	EndIf;

EndProcedure

Function OrdersSettings(connection) Export

	query = New Query;
	query.SetParameter("connection", connection);
	query.Text = "SELECT TOP 1
	 |	like_ordersSettings.Валюта AS Валюта,
	 |	like_ordersSettings.ВидЦены AS ВидЦены,
	 |	like_ordersSettings.Клиент AS Клиент,
	 |	like_ordersSettings.Организация AS Организация
	 |FROM
	 |	InformationRegister.like_ordersSettings AS like_ordersSettings
	 |WHERE
	 |	like_ordersSettings.connection = &connection";
	selection = query.Execute().Select();
	If Not selection.Next() Then
		Return Undefined;
	EndIf;
	Return selection;

EndFunction

Function GoodsMatchingTable(orderData)

	productsTable = 
		like_TypesAndDescriptionsAtServer.GetTableWithColumns("productID;UUID");

	For each item In orderData.items Do
		newTableItem = productsTable.Add();
		newTableItem.productID = item.product;
	EndDo;

	productsTable.GroupBy("productID");

	matchingQuery = New Query;
	matchingQuery.SetParameter("mTable", productsTable);
	matchingQuery.Text = "SELECT
	|	mT.productID AS productID
	|INTO tmT
	|FROM
	|	&mTable AS mT
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	tmT.productID AS productID,
	|	like_objectMatching.ref1C AS ref1C
	|FROM
	|	tmT AS tmT
	|		LEFT JOIN Catalog.like_products AS like_products
	|		ON tmT.productID = like_products.UUID
	|		LEFT JOIN InformationRegister.like_objectMatching AS like_objectMatching
	|		ON (like_objectMatching.likeRef = like_products.Ref)";
	Return matchingQuery.Execute().Unload();

EndFunction