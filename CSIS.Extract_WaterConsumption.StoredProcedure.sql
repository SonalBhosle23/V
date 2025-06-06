/****** Object:  StoredProcedure [CSIS].[Extract_WaterConsumption]    Script Date: 20/02/2020 3:51:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP PROCEDURE if exists [CSIS].[Extract_WaterConsumption]
GO
CREATE PROCEDURE [CSIS].[Extract_WaterConsumption]
	@ETLUpdated	DATETIME2 = '1 Jan 2019 16:23:48.5200000'
	AS
/*************************************************************************************************************************************************
Description: [CSIS].[Extract_WaterConsumption] from EDS
			Data is extracted from CSIS.InvoiceLine 
									CRM.[CurrentPropertyExtract]
									and MDS.[CSProduct]
Author:           V Bhosle
Creation Date:    26 Nov 2019

Parameters
	@ETLChanged : the start date for data extraction.  Records with ETLChanged > than this value are extracted

Change Log
=================================================================================================================================================
Date		Author		Description
=================================================================================================================================================
26 Nov 2019 VBhosle 	Initial version
07 Jan 2020 VBhosle		Renamed CSProduct to CSCSISProduct
30Jan2020	SKennedy	removed columns RateID and OtherChargeClassification
						Changed value used for ETLSource to 'CSIS Billed Consumption'
						Updated join to CRM.CurrentPropertyExtract so that it gets the last property for the account
07Feb2020	SKennedy	Added ETLSourceKey4
20Feb2020	SKennedy	Exclude records from CSIS.InvoiceLine where EffectiveDate is prior to the PeriodEndDate
						CSIS did not record the actual consumption dates for these records

=================================================================================================================================================
*************************************************************************************************************************************************/


; with AverageBS as
		(
		SELECT  
			 AB.LandUseTypeInd
			, AB.QuarterCalendarKey
			, CONVERT (DATE, CONVERT (VARCHAR, AB.[QuarterCalendarKey]) , 112)	AS StartDate
			, DATEADD (DAY, -1, DATEADD (Quarter, 1,  CONVERT (DATE, CONVERT (VARCHAR, AB.[QuarterCalendarKey]) , 112)) )	AS EndDate
			, AB.AverageBillSize		AS AverageBillSize 
			, AB.ETLUpdated				AS ETLUpdated
			FROM CSIS.AverageBillSize AB
		 )

	
select  

		'CSIS Billed Consumption'								AS [ETLSource]
		,PEX.MosaicType2018										AS [MosaicType2018]
		,PEX.OwnerMosaicTypeCode2018							AS [MosaicType2018Owner]
		, CONVERT (VARCHAR (10), IL.[FinancialAccountNum])		AS ETLSourceKey1
		, CONVERT (VARCHAR (10), IL.FinancialTransactionID)		AS ETLSourceKey2
		, CONVERT (VARCHAR (10), IL.BillLineSeqNum)				AS ETLSourceKey3
		, CONVERT (VARCHAR (8),IL.[PeriodStartDate], 112)		AS ETLSourceKey4
	--	,IL.RateID												AS [RateID]
		,IL.Quantity											AS [WaterConsumption]
		, CASE 
				WHEN IL.EffectiveDate < ISNULL ( PEX.[PropertyCancelledDate] , '31 Dec 3999')
				AND IL.EffectiveDate <= PEX.ExternalAccountNumberWETCALC 
				THEN 'Active'
				ELSE 'Inactive'
			END AS PropertyActive
		
		, CONVERT (VARCHAR (30), CASE WHEN IL.WaterUseTierNumber IS NULL THEN 'Not Applicable'
								ELSE 'Water use tier ' + CONVERT (VARCHAR, IL.WaterUseTierNumber)	
								END 
				) AS WateUseCategory
		,IL.PropertyNumber
		,IL.ExternalAccountNumber
		,'Billed'AS [WaterConsumptionType]
		, CASE WHEN I.AverageBillCurrentDueAmt  <= AB.AverageBillSize 
                    THEN 'Low'
                 ELSE 'High'
                END AS BillSize 
		,CONVERT (int, convert(varchar(8),IL.[PeriodStartDate],112))				as [ReadingStartDateCalendarKey]
		,CONVERT (int, convert(varchar(8),IL.[PeriodEndDate],112))					as [ReadingEndDateCalendarKey]
		,CONVERT (int, convert(varchar(8),IL.[EffectiveDate],112))					as [EffectiveDateCalendarKey]
		,CONVERT (VARCHAR (30), ISNULL (PRO.ProductCategory, N''))					AS ProductCategory
		,CONVERT (VARCHAR (30), ISNULL (PRO.ProductSubType, N''))					AS ProductSubType
		,CONVERT (VARCHAR (30), ISNULL (PRO.ProductType, N''))						AS ProductType
		
		,CONVERT (VARCHAR (30), ISNULL (PRO.ChargeType, N''))						AS BillCategory
		,ETLDate.ETLChanged as ETLSourceUpdated 	 
	
from 
	CSIS.InvoiceLine IL
	INNER JOIN MDS.CSCSISProduct PRO
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

	LEFT JOIN AverageBS AB
		ON IL.EffectiveDate BETWEEN  AB.StartDate and AB.EndDate
			AND AB.LandUseTypeInd = ISNULL (PEX.LandUseTypeInd, 'R')
	
	outer apply (SELECT MAX (X.ETLChanged ) AS ETLChanged 
                 FROM (SELECT IL.ETLUpdated  AS ETLChanged
						 UNION 
						 SELECT PEX.ETLChanged  AS ETLChanged
						 UNION 
						 SELECT PRO.ETLUpdated  AS ETLChanged
						 UNION  
						 SELECT I.ETLUpdated  	AS ETLChanged
						 UNION	
						 Select AB.ETLUpdated  AS ETLChanged					 
                   ) X
                 ) AS ETLDate
	
	
	WHERE 
		  
		   PRO.ProductCategory = 'Water'
			and PRO.ProductType = 'Potable Water' 
			and PRO.ChargeType = 'Variable Charge'
			and IL.Quantity is not null
			and ETLDate.ETLChanged > @ETLUpdated
		AND IL.EffectiveDate >= IL.PeriodEndDate
			--and I.FinancialAccountNum in (993858, 175895, 300589, 533258, 232669, 601178, 958541, 1015315, 1083235, 1315904, 216994)









GO
