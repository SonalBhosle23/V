/****** Object:  StoredProcedure [CSIS].[Extract_WaterConsumptionKeys]    Script Date: 20/02/2020 3:51:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP PROCEDURE IF EXISTS [CSIS].[Extract_WaterConsumptionKeys]
GO
CREATE PROCEDURE [CSIS].[Extract_WaterConsumptionKeys]
	
	AS
/*************************************************************************************************************************************************
Description: [CSIS].[Extract_WaterConsumptionKey] from EDS
			Data is extracted from  CSIS.InvoiceLine Tables.

Author:           V Bhosle
Creation Date:    26 Nov 2019


Change Log
=================================================================================================================================================
Date		Author		Description
=================================================================================================================================================
26 NOV 2019 VBhosle 	Initial version
17 Jan 2020 VBhosle		Added CSCSISProduct Invoice and CurrentPropertyExtract Tables with the where conditions
30Jan2020	SKennedy	Updated join to CRM.CurrentPropertyExtract so that it gets the last property for the account
07Feb2020	SKennedy	Added ETLSourceKey4
20Feb2020	SKennedy	Exclude records from CSIS.InvoiceLine where EffectiveDate is prior to the PeriodEndDate
						CSIS did not record the actual consumption dates for these records
=================================================================================================================================================
*************************************************************************************************************************************************/
SET NOCOUNT ON;

SELECT  
	 CONVERT (VARCHAR (50), IL.[FinancialAccountNum])		AS ETLSourceKey1
	, CONVERT (VARCHAR (50), IL.FinancialTransactionID)		AS ETLSourceKey2
	, CONVERT (VARCHAR (50), IL.BillLineSeqNum)				AS ETLSourceKey3
	, CONVERT (VARCHAR (8),IL.[PeriodStartDate], 112)		AS ETLSourceKey4
	FROM CSIS.InvoiceLine IL
	 Inner JOIN MDS.CSCSISProduct PRO
		ON PRO.RateID = IL.RateID
	
	INNER JOIN CSIS.Invoice I
		on IL.FinancialAccountNum = I.FinancialAccountNum
		and IL.BillHeaderNum = I.BillHeaderNum
		and IL.EffectiveDate = I.EffectiveDate

	INNER JOIN [CRM].[CurrentPropertyExtract] PEX
		ON PEX.FinancialAccountNumber = IL.FinancialAccountNum
		AND PEX.ExternalAccountNumberWETCALC = (SELECT MAX (PEX2.ExternalAccountNumberWETCALC)
													 FROM [CRM].[CurrentPropertyExtract] PEX2
													 WHERE PEX2.FinancialAccountNumber = PEX.FinancialAccountNumber
												)
	where
		PRO.ProductCategory = 'Water'
		and PRO.ProductType = 'Potable Water' 
		and PRO.ChargeType = 'Variable Charge'
		and IL.Quantity is not null
		AND IL.EffectiveDate >= IL.PeriodEndDate

GO
