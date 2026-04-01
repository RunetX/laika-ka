Procedure Order1CFromIiko(DocumentID) Export

	docData = like_DocumentAtServer.GetDocument(DocumentID, "https://izi.cloud/iiko/reading/productionOrder");

	If Not docData.success Then
		Raise docData.errorString;
		Return;
	EndIf;

	orderData	= OrderDataFromPackage(docData.returnValue);
	mobileOrder = MobileOrder(orderData);
	messages = New Array;
	If mobileOrder <> Undefined Then
		МобильноеПриложениеЗаказыКлиентовПереопределяемый.СоздатьОбновитьЗаказКлиента(
			mobileOrder, messages);
	Else
		Raise NStr("ru = 'Не удалось сформировать мобильный заказ'");
	EndIf;

EndProcedure

Function MobileOrder(orderData)

	activeConnection = like_ConnectionAtServer.GetActiveConnecton();
	settings = like_Orders.OrdersSettings(activeConnection);
	If Not ValueIsFilled(settings.Организация) Then
		Raise NStr("ru = 'Не удалось получить настройку загрузки заказов'");
	EndIf;
	
	URIName = "http://www.1c.ru/CustomerOrders/Exchange";
	objectType = ФабрикаXDTO.Тип(URIName, "DocumentObject.ЗаказКлиента");
	MobileOrder = ФабрикаXDTO.Создать(objectType);

	dateTimeCreated = orderData.date;
	docDate  		= BegOfDay(dateTimeCreated);
	priceType 		= IdStrByRef(settings.ВидЦены);
	store 			= "00000000-0000-0000-0000-000000000000";
	goodsObjectType = ФабрикаXDTO.Тип(URIName, "DocumentTabularSectionRow.ЗаказКлиента.Товары");

	MobileOrder.Date								= dateTimeCreated;
	MobileOrder.DeletionMark						= False;
	//MobileOrder.Number
	MobileOrder.Posted								= True;
	MobileOrder.Ref									= orderData.id;
	MobileOrder.Валюта								= IdStrByRef(settings.Валюта);
	MobileOrder.ВидЦены								= priceType;
	MobileOrder.ДатаОплаты							= docDate;
	MobileOrder.ДатаОтгрузки						= docDate;
	MobileOrder.ДатаПредоплатыПоДокументу			= docDate;
	MobileOrder.ДатаСледующегоПлатежа				= docDate;
	MobileOrder.ДокументОснование					= "00000000-0000-0000-0000-0000000000000000";
	MobileOrder.ЖелаемаяДатаОтгрузки				= docDate;
	client = IdStrByRef(settings.Клиент);
	MobileOrder.Клиент								= client;
	Контрагент = ПартнерыИКонтрагенты.ПолучитьКонтрагентаПартнераПоУмолчанию(settings.Клиент);
	MobileOrder.Контрагент							= IdStrByRef(Контрагент);
	MobileOrder.Организация							= IdStrByRef(settings.Организация);
	MobileOrder.Самовывоз							= False;
	MobileOrder.Склад								= store;
	MobileOrder.СостояниеДокумента					= "Горящие";
	MobileOrder.СостояниеДокументаИБ				= "НеПередан";
	MobileOrder.СтатусДокумента						= "НеСогласован";
	MobileOrder.СтатусОбмена						= "КОбмену";
	MobileOrder.ФормаОплаты							= "Наличная";

	goodsMatchingTable = GoodsMatchingTable(orderData);
	For each item In orderData.items Do

		matching = goodsMatchingTable.Find(item.product, "productID");
		If Not ValueIsFilled(matching) Or (matching.ref1C = Null) Then
			Message(NStr("ru = 'Не найдено сопосталение для товара '") + item.product);
			Continue;
		EndIf;
		
		НовыйТовар = ФабрикаXDTO.Создать(goodsObjectType);
		НовыйТовар.ВидЦены				= priceType;
		НовыйТовар.Количество			= 1;
		НовыйТовар.КоличествоУпаковок	= 1;
		НовыйТовар.Номенклатура			= IdStrByRef(matching.ref1C);
		НовыйТовар.Склад				= store;
		НовыйТовар.Упаковка				= "8bc3c66a-1769-4d03-91b7-802e4948fed1";

		MobileOrder.Товары.Добавить(НовыйТовар);

	EndDo;

	Return MobileOrder;

EndFunction

&AtServer
Function IdStrByRef(ref)

	Return String(ref.UUID());

EndFunction

&AtServer
Function OrderDataFromPackage(package)

	orderData = New Structure;
	orderData.Insert("date", like_Common.iikoDateTimeTo1C(package.createdInfo.date));
	orderData.Insert("documentNumber", package.documentNumber);
	orderData.Insert("id", package.eid);
	orderData.Insert("status", package.status);
	orderData.Insert("storeFrom", package.storeFrom);

	items = New Array;
	For each orderItem In package.items.i Do

		If orderItem.amount = "0E-9" Then
			Continue;
		EndIf;

		newItem = OrderItemModel();
		FillPropertyValues(newItem, orderItem);
		items.Add(newItem);

	EndDo;

	orderData.Insert("items", items);

	Return orderData;

EndFunction

&AtServer
Function OrderItemModel()

	orderItem = New Structure;
	orderItem.Insert("amount");
	orderItem.Insert("amountUnit");
	orderItem.Insert("product");

	Return orderItem;

EndFunction

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
	selection.Next();
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