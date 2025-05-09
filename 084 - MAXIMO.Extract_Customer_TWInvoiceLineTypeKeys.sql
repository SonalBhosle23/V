/****** Object:  StoredProcedure [MAXIMO].[Extract_Customer_TWInvoiceLineTypeKeys]    Script Date: 5/02/2020 9:21:12 AM ******/
DROP PROCEDURE if exists  [MAXIMO].[Extract_Customer_TWInvoiceLineTypeKeys]
GO

/****** Object:  StoredProcedure [MAXIMO].[Extract_Customer_TWInvoiceLineTypeKeys]    Script Date: 5/02/2020 9:21:12 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [MAXIMO].[Extract_Customer_TWInvoiceLineTypeKeys]
	
	AS
/*************************************************************************************************************************************************
Description: [Maximo].[Extract_Customer_TWInvoiceLineTypeKeys]
			Data is extracted from MAXIMO.sawchargeparms and MAXIMO.sawcosting.

Author:           V Bhosle
Creation Date:    22 Jan 2020


Change Log
=================================================================================================================================================
Date		Author		Description
22Jan2020	VBhosle		Initial version

=================================================================================================================================================
*************************************************************************************************************************************************/
SET NOCOUNT ON;
select InvoiceLineCode,FinancialYear
from
(
	SELECT  

	ISNULL (CP.[chargeparamid],  C.[sawflmparamnum]) 	AS InvoiceLineCode
	, ISNULL (' ' + C.sawfinyear, '')					AS FinancialYear
	
   
	FROM [MAXIMO].[sawchargeparams] CP
	FULL OUTER JOIN [MAXIMO].[sawcostings] c
		ON C.[sawflmparamnum] = CP.[sawflmparamnum]
	)KEYS
where KEYS.InvoiceLineCode != 'NULL'

GO


