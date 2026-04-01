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
	invoiceVT 	  = invoiceData.Unload();
	
	For each invoiceItem In d.items.i Do
	
		newInvoiceStr = invoiceVT.Add();
		
		newInvoiceStr.number 		 		 	= d.documentNumber;
		newInvoiceStr.date	 		 		 	= like_Common.iikoDateTimeTo1C(d.dateIncoming);
		newInvoiceStr.conceptionUUID 		 	= ?(ValueIsFilled(d.conception.__content), d.conception.__content, 
													like_InvoicesAtServer.FindByCodeAndConnection("like_conceptions", "no_concept"));
		newInvoiceStr.comment				 	= d.comment.__content;
		newInvoiceStr.supplierUUID			 	= d.supplier;
		newInvoiceStr.defaultStoreUUID		 	= d.defaultStore.__content;
		newInvoiceStr.revenueAccountUUID		= d.revenueAccount;
		newInvoiceStr.accountToUUID				= d.accountTo;
		
		newInvoiceStr.eid						= invoiceItem.eid;
		newInvoiceStr.code						= invoiceItem.code;
		newInvoiceStr.productUUID				= invoiceItem.product;
		newInvoiceStr.amount					= invoiceItem.amount;
		newInvoiceStr.amountUnitUUID			= invoiceItem.amountUnit;
		newInvoiceStr.storeUUID					= invoiceItem.store;
		newInvoiceStr.price						= invoiceItem.price;
		newInvoiceStr.priceWithoutNds			= invoiceItem.sumWithoutNds/invoiceItem.amount;
		newInvoiceStr.sum						= invoiceItem.sum;
		newInvoiceStr.ndsPercent				= invoiceItem.ndsPercent;
		newInvoiceStr.ndsSum 					= invoiceItem.sum - invoiceItem.sumWithoutNds;
		newInvoiceStr.sumWithoutNds				= invoiceItem.sumWithoutNds;
		
	EndDo;

	invoiceVT = FillInvoiceData(invoiceVT);
	If ValueIsFilled(invoiceVT) Then
		FillPropertyValues(ThisForm, invoiceVT[0]);
		invoiceItems.Load(invoiceVT);
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	Title = NStr("en = 'Outgoing invoice №'; ru = 'Расходная накладная №'") + Format(Number, "NGS=' '; NG=0") + NStr("en = ' from '; ru = ' от '") + Date;
	
	If defaultStore.IsEmpty() Then
		Items.defaultStore.Enabled = False;	
	Else
		Items.invoiceItemsstore.Visible = False;
	EndIf;
EndProcedure
