/****** Object:  StoredProcedure [MAXIMO].[Extract_Customer_TWInvoiceLineType]    Script Date: 5/02/2020 9:21:06 AM ******/
DROP PROCEDURE if exists [MAXIMO].[Extract_Customer_TWInvoiceLineType]
GO

/****** Object:  StoredProcedure [MAXIMO].[Extract_Customer_TWInvoiceLineType]    Script Date: 5/02/2020 9:21:06 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [MAXIMO].[Extract_Customer_TWInvoiceLineType]
		@ETLUpdated	DATETIME2 = '1 Jan 1900'	
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
 select
 InvoiceLineCode,
 FinancialYear,
 InvoiceLineType,
 Parameter,
 InvoiceLineGroup,
 InvoiceLineSubGroup, 
 ETLSourceUpdated  
		
 FROM
 ( 
	 SELECT  
	 ISNULL (CP.[chargeparamid],  C.[sawflmparamnum]) 	AS InvoiceLineCode
	, ISNULL (' ' + C.sawfinyear, '')					AS FinancialYear
	, ISNULL (CP.[description], C.[sawinvdesc])			AS InvoiceLineType
 
	, CASE WHEN ISNULL (CP.[sawparameter], '') <> '' THEN CP.[sawparameter]
		when c.sawmjpd = 'Biochemical Oxygen Demand' THEN 'BOD'
		when c.sawmjpd = 'Suspended Solids' THEN 'SS'
		when c.sawmjpd = 'Total Dissolved Solids' THEN 'TDS'
		when c.sawmjpd = 'TDS < 650mg/L' THEN 'TDS'
		when c.sawmjpd = 'Nitrogen' THEN 'Nitrogen'
		when c.sawmjpd = 'Total Phosphorus' THEN 'TP'
		ELSE ''
		END	AS Parameter  
	, COALESCE (C.[sawfrc],CP.[description], C.[sawinvdesc])		AS InvoiceLineGroup
	, COALESCE (C.[sawmjpd],CP.[description], C.[sawinvdesc])		AS InvoiceLineSubGroup
	,ETLDate.ETLChanged as ETLSourceUpdated 
   
	FROM [MAXIMO].[sawchargeparams] CP
	FULL OUTER JOIN [MAXIMO].[sawcostings] c
		ON C.[sawflmparamnum] = CP.[sawflmparamnum]
 
	outer Apply (SELECT MAX (X.ETLChanged ) AS ETLChanged 
                 FROM (SELECT CP.ETLUpdated  AS ETLChanged
						 UNION 
						 SELECT C.ETLUpdated  AS ETLChanged
						 				 
                   ) X
                 ) AS ETLDate
	
	
	
 )KEYS
 where KEYS.InvoiceLineCode != 'NULL'
 order by InvoiceLineGroup,Parameter desc
GO


