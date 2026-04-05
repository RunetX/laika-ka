&AtServer
Function FillInvoiceData(invoiceVT)

	fQuery = New Query("SELECT
	                   |	iVT.number AS number,
	                   |	iVT.date AS date,
	                   |	iVT.conceptionUUID AS conceptionUUID,
	                   |	iVT.comment AS comment,
	                   |	iVT.supplierUUID AS supplierUUID,
	                   |	iVT.defaultStoreUUID AS defaultStoreUUID,
	                   |	iVT.revenueAccountUUID AS revenueAccountUUID,
	                   |	iVT.accountToUUID AS accountToUUID,
	                   |	iVT.eid AS eid,
	                   |	iVT.code AS code,
	                   |	iVT.productUUID AS productUUID,
	                   |	iVT.amount AS amount,
	                   |	iVT.amountUnitUUID AS amountUnitUUID,
	                   |	iVT.storeUUID AS storeUUID,
	                   |	iVT.price AS price,
	                   |	iVT.priceWithoutNds AS priceWithoutNds,
	                   |	iVT.sum AS sum,
	                   |	iVT.ndsPercent AS ndsPercent,
	                   |	iVT.ndsSum AS ndsSum,
	                   |	iVT.sumWithoutNds AS sumWithoutNds
	                   |INTO tmpInvoice
	                   |FROM
	                   |	&invoiceVT AS iVT
	                   |;
	                   |
	                   |////////////////////////////////////////////////////////////////////////////////
	                   |SELECT
	                   |	MAX(tI.number) AS number,
	                   |	MAX(tI.date) AS date,
	                   |	MAX(tI.conceptionUUID) AS conceptionUUID,
	                   |	MAX(Conceptions.Ref) AS conception,
	                   |	MAX(tI.comment) AS comment,
	                   |	MAX(tI.supplierUUID) AS supplierUUID,
	                   |	MAX(Suppliers.Ref) AS supplier,
	                   |	MAX(tI.defaultStoreUUID) AS defaultStoreUUID,
	                   |	MAX(dStores.Ref) AS defaultStore,
	                   |	MAX(revenueAccounts.Ref) AS revenueAccount,
	                   |	MAX(accountsTo.Ref) AS accountTo,
	                   |	MAX(tI.code) AS code,
	                   |	MAX(tI.productUUID) AS productUUID,
	                   |	MAX(Products.Ref) AS product,
	                   |	MAX(tI.amount) AS amount,
	                   |	MAX(tI.amountUnitUUID) AS amountUnitUUID,
	                   |	MAX(amountUnits.Ref) AS amountUnit,
	                   |	MAX(tI.storeUUID) AS storeUUID,
	                   |	MAX(Stores.Ref) AS store,
	                   |	MAX(tI.price) AS price,
	                   |	MAX(tI.priceWithoutNds) AS priceWithoutNds,
	                   |	MAX(tI.sum) AS sum,
	                   |	MAX(tI.ndsPercent) AS ndsPercent,
	                   |	MAX(tI.ndsSum) AS ndsSum,
	                   |	MAX(tI.sumWithoutNds) AS sumWithoutNds
	                   |FROM
	                   |	tmpInvoice AS tI
	                   |		INNER JOIN Catalog.like_conceptions AS Conceptions
	                   |		ON tI.conceptionUUID = Conceptions.UUID
	                   |		INNER JOIN Catalog.like_users AS Suppliers
	                   |		ON tI.supplierUUID = Suppliers.UUID
	                   |		LEFT JOIN Catalog.like_stores AS dStores
	                   |		ON tI.defaultStoreUUID = dStores.UUID
	                   |		LEFT JOIN Catalog.like_accounts AS revenueAccounts
	                   |		ON tI.revenueAccountUUID = revenueAccounts.UUID
	                   |		LEFT JOIN Catalog.like_accounts AS accountsTo
	                   |		ON tI.accountToUUID = accountsTo.UUID
	                   |		INNER JOIN Catalog.like_products AS Products
	                   |		ON tI.productUUID = Products.UUID
	                   |		INNER JOIN Catalog.like_measureUnits AS amountUnits
	                   |		ON tI.amountUnitUUID = amountUnits.UUID
	                   |		INNER JOIN Catalog.like_stores AS Stores
	                   |		ON tI.storeUUID = Stores.UUID
	                   |
	                   |GROUP BY
	                   |	tI.eid");
	fQuery.SetParameter("invoiceVT", invoiceVT);
	Return fQuery.Execute().Unload();

EndFunction

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Not Parameters.Property("UUID") Then
		Return;
	EndIf;

	docData = like_DocumentAtServer.GetDocument(Parameters.UUID, "https://izi.cloud/iiko/reading/outgoingInvoice");
	If Not docData.success Then
		Message(docData.errorString);
		Return;
	EndIf;

	d = docData.returnValue;
	invoiceVT = invoiceData.Unload();

	docNumber        = like_CoreAPI.SafeGet(d, "documentNumber", "");
	dateIncoming     = like_CoreAPI.SafeGet(d, "dateIncoming", "");
	conceptionUUID   = like_CoreAPI.SafeGet(d, "conceptionUUID", "");
	If Not ValueIsFilled(conceptionUUID) Then
		conceptionUUID = like_InvoicesAtServer.FindByCodeAndConnection("like_conceptions", "no_concept");
	EndIf;
	commentVal       = like_CoreAPI.SafeGet(d, "comment", "");
	supplierUUID     = like_CoreAPI.SafeGet(d, "supplierUUID", "");
	defaultStoreUUID = like_CoreAPI.SafeGet(d, "defaultStoreUUID", "");
	revenueAccountUUID = like_CoreAPI.SafeGet(d, "revenueAccountUUID", "");
	accountToUUID    = like_CoreAPI.SafeGet(d, "accountToUUID", "");

	invoiceLines = like_CoreAPI.SafeGet(d, "items", New Array);
	For Each invoiceItem In invoiceLines Do

		newInvoiceStr = invoiceVT.Add();

		newInvoiceStr.number              = docNumber;
		newInvoiceStr.date                = ?(ValueIsFilled(dateIncoming), like_Common.iikoDateTimeTo1C(dateIncoming), Date(1,1,1));
		newInvoiceStr.conceptionUUID      = conceptionUUID;
		newInvoiceStr.comment             = commentVal;
		newInvoiceStr.supplierUUID        = supplierUUID;
		newInvoiceStr.defaultStoreUUID    = defaultStoreUUID;
		newInvoiceStr.revenueAccountUUID  = revenueAccountUUID;
		newInvoiceStr.accountToUUID       = accountToUUID;

		newInvoiceStr.eid            = like_CoreAPI.SafeGet(invoiceItem, "eid", "");
		newInvoiceStr.code           = like_CoreAPI.SafeGet(invoiceItem, "code", "");
		newInvoiceStr.productUUID    = like_CoreAPI.SafeGet(invoiceItem, "productUUID", "");
		itemAmount                   = Number(like_CoreAPI.SafeGet(invoiceItem, "amount", 0));
		newInvoiceStr.amount         = itemAmount;
		newInvoiceStr.amountUnitUUID = like_CoreAPI.SafeGet(invoiceItem, "amountUnitUUID", "");
		newInvoiceStr.storeUUID      = like_CoreAPI.SafeGet(invoiceItem, "storeUUID", "");
		newInvoiceStr.price          = Number(like_CoreAPI.SafeGet(invoiceItem, "price", 0));
		itemSumWithoutNds            = Number(like_CoreAPI.SafeGet(invoiceItem, "sumWithoutNds", 0));
		newInvoiceStr.priceWithoutNds = ?(itemAmount <> 0, itemSumWithoutNds / itemAmount, 0);
		newInvoiceStr.sum            = Number(like_CoreAPI.SafeGet(invoiceItem, "sum", 0));
		newInvoiceStr.ndsPercent     = Number(like_CoreAPI.SafeGet(invoiceItem, "ndsPercent", 0));
		newInvoiceStr.ndsSum         = newInvoiceStr.sum - itemSumWithoutNds;
		newInvoiceStr.sumWithoutNds  = itemSumWithoutNds;

	EndDo;

	invoiceVT = FillInvoiceData(invoiceVT);
	If ValueIsFilled(invoiceVT) Then
		FillPropertyValues(ThisForm, invoiceVT[0]);
		invoiceItems.Load(invoiceVT);
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	Title = NStr("en = 'Outgoing invoice №'; ru = 'Расходная накладная №'") + Format(Number, "NGS=' '; NG=0") + NStr("en = ' from '; ru = ' от '") + Date;

	If defaultStore.IsEmpty() Then
		Items.defaultStore.Enabled = False;
	Else
		Items.invoiceItemsstore.Visible = False;
	EndIf;
EndProcedure
