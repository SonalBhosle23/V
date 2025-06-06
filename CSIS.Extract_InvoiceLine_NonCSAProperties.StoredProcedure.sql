/****** Object:  StoredProcedure [CSIS].[Extract_InvoiceLine_NonCSAProperties]    Script Date: 20/02/2020 3:51:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

drop PROCEDURE if exists [CSIS].[Extract_InvoiceLine_NonCSAProperties]
GO
CREATE PROCEDURE [CSIS].[Extract_InvoiceLine_NonCSAProperties]
	@ExecutionID	UNIQUEIDENTIFIER = NULL
	, @ETLUpdated	DATETIME2 = '1 Jan 2018'
	AS
/*******************************************************************************

Name:             [CSIS.[Extract_InvoiceLine_NonCSAProperties] 
Descriptive Name: Extract InvoiceLine records from CSIS_FinancialTransaction and CSIS_BASLBillLIne

Author:           S Kennedy
Creation Date:    19 Nov 2019
Version:          1.0


Modification History:
--------------------------------------------------------------------------------
Date		Name        Modification
--------------------------------------------------------------------------------
19Nov2019	SKennedy	Initial version.
27Nov2018	SKennedy	Added condition FT.BillSegSubTypeInd <> 'V'
06Dec2019	SKennedy	Updated Tier code to use the relevant CSIS tables
09Dec2019	SKennedy	Added filter on CSIS_PropertyGroup to exclude Cancelled CSA's
28Jan2020	SKennedy	Change WaterUseTier calculation to use PeriodEndDate
						Change lookup of CSIS_ExternalAccountNum to use the last record based on the value of ExternalAccountNumberWET
						Added a filter when looking up records on dbo.CSIS_BASLBillLine to exclude records for a selection of RateID's
						Changed the calculation of InvoiceLineItemAmount so that when (BillLineParm1QTY * BillLineParm2Qty) <> BillLineResultAmt
						the value from FinancialTransactionAmt is used instead on BillLineResultAmt.
						Only extract where CSIS_ExternalAccountNum.AccountTypeInd = 'P'	
03Feb2020	SKennedy	Round InvoiceLineItemAmount to 2 decimal places
14Feb2020	SKennedy	Change the check (BillLineParm1QTY * BillLineParm2Qty) <> BillLineResultAmt so that both sides of the condition
						are rounded to 2 decimal places before the comparison. Corrects BUG IMP2020-4871
20Feb2020	SKennedy	Added filters on CSIS_BASLBillLine  - BillLineFunctionCode = 'STEP'
*******************************************************************************/	
SELECT @ExecutionID = ISNULL (@ExecutionID, NEWID() );	


CREATE TABLE #TieredRateID
	(RateID				VARCHAR (3)
	, StartDate_Char	VARCHAR (10)
	, StartDate			DATE
	, EndDate			DATE
	, EndDate_CHAR		VARCHAR (10))
	;


WITH Tiers AS
	(SELECT BRC.RATE_ID
		, BRC.RATE_VERSION_WEF
		, COUNT(*) Counter 
		FROM [CSIS].[BASL_RATE_COMPONENT_B] BRC
		WHERE EXISTS (SELECT * FROM [CSIS].[BASL_RATE_COMPONENT_B] BRC2
						WHERE BRC2.RATE_ID = BRC.RATE_ID
						AND BRC2.RATE_VERSION_WEF = BRC.RATE_VERSION_WEF
						AND BRC2.RATE_COMP_FUNCTION_CODE = 'STEP')
		AND BRC.RATE_COMP_FUNCTION_CODE ='DATA'
		AND BRC.RATE_COMP_PARM_1_TYPE_IND = 'C'
		GROUP BY BRC.RATE_ID, BRC.RATE_VERSION_WEF
	) ,
	RateStartDates AS
	(
		SELECT DISTINCT 
			RC.RATE_ID
			, RC.RATE_VERSION_WEF 
			FROM [CSIS].[BASL_RATE_COMPONENT_B] RC
	)
	INSERT INTO #TieredRateID
		(RateID, StartDate, StartDate_Char, EndDate, EndDate_CHAR)
		SELECT RS.RateID
			, RC.RATE_VERSION_WEF								AS StartDate
			, CONVERT (VARCHAR (10), RC.RATE_VERSION_WEF, 112)	AS StartDate_Char
			, ISNULL ((SELECT MIN (X.RATE_VERSION_WEF) 
						FROM RateStartDates X
						WHERE X.RATE_ID = RC.RATE_ID
						AND X.RATE_VERSION_WEF > RC.RATE_VERSION_WEF
						)
					, '30 Dec 3999')
																AS EndDate
			, CONVERT (VARCHAR(10), ISNULL ((SELECT MIN (X.RATE_VERSION_WEF) 
				FROM RateStartDates X
				WHERE X.RATE_ID = RC.RATE_ID
				AND X.RATE_VERSION_WEF > RC.RATE_VERSION_WEF

				)
				, '30 Dec 3999')
				, 112)
																AS EndDate_CHAR
			FROM  dbo.CSIS_RateSchedule RS
			LEFT OUTER JOIN Tiers
				ON RS.RateID = Tiers.RATE_ID COLLATE Latin1_General_BIN
			INNER JOIN RateStartDates RC
				ON RC.RATE_ID = RS.RateID COLLATE Latin1_General_BIN
				AND RC.RATE_VERSION_WEF = ISNULL (Tiers.RATE_VERSION_WEF, RC.RATE_VERSION_WEF)
			WHERE Tiers.Counter > 1 
	;
	CREATE INDEX IX_TieredRateID_RateID_StartDate_CHAR_EndDate_CHAR	
		ON #TieredRateID (RateID, StartDate_Char, EndDate_CHAR)
 ;
 WITH InvoiceLines AS
	(SELECT  
		FT.FinancialAccountNum
		, FT.FinancialTransactionID
		, ISNULL (bbl.BillLineSeqNum, 0) BillLineSeqNum
		, FT.rateid
		, EAN.ExternalAccountNumber
		, ean.PropertyNumber
		, FT.FinancialTransDate		AS EffectiveDate
		, FT.AuthorisedDate			AS AuthorisedDate

		, FT.PeriodStartDate
		, FT.PeriodEndDate

		, FT.BillHeaderNum
		, BH.BillDueDate			AS BillDueDate
		, BH.BillHeaderDate			AS BillHeaderDate
		, BH.BillHeaderTypeInd
	 
		, CASE WHEN EXISTS (SELECT * FROM #TieredRateID TR WHERE TR.RateID = FT.RateID AND FT.PeriodEndDate BETWEEN TR.StartDate_CHAR AND TR.EndDate_CHAR)
			THEN ROW_NUMBER() OVER (PARTITION BY FT.FinancialAccountNum, FT.FinancialTransactionID ORDER BY BBL.BillLineSeqNum) 
			ELSE NULL
			END AS WaterUseTierNumber
	
		, CONVERT (DECIMAL (19,5), BBL.BillLineParm1QTY)		as Quantity
		, CONVERT (DECIMAL (19,5), BBL.BillLineParm2QTY)		AS UnitPrice
		, CONVERT (DECIMAL (19, 2) ,ROUND ( ISNULL (CASE WHEN ROUND (CONVERT (DECIMAL (19,5), BBL.BillLineParm1QTY) * CONVERT (DECIMAL (19,5), BBL.BillLineParm2Qty), 2) = ROUND (CONVERT (DECIMAL (19,5), BBL.BillLineResultAmt), 2)
													THEN CONVERT (DECIMAL (19,5), BBL.BillLineResultAmt)
													ELSE NULL END
													, CONVERT (DECIMAL (19, 2) , FT.FinancialTransactionAmt)
													)	
										, 2)
				)		AS InvoiceLineItemAmount
		, FT.FinancialTransactionAmt
	 
		 , FT.FinancialTransStatusInd
		 , FT.FinancialTransTypeInd
 
		 , FT.RateClassInd
		 , 'FinancialTransaction non CSA'					AS ETLSource
		 , CASE WHEN FT.Updated > BH.Updated THEN FT.Updated 
			ELSE BH.Updated END								AS ETLSourceUpdated1
		 , CASE WHEN BBL.Updated IS NULL THEN EAN.Updated
			WHEN EAN.Updated > BBL.Updated THEN EAN.Updated 
			ELSE BBL.Updated END							AS ETLSourceUpdated2

		FROM dbo.CSIS_FinancialTransaction FT
	 
		INNER JOIN dbo.CSIS_ExternalAccountNum EAN
			ON EAN.FinancialAccountNum = FT.FinancialAccountNum
			AND EAN.ExternalAccountNumberWET = (SELECT MAX (EAN2.ExternalAccountNumberWET)
													FROM dbo.CSIS_ExternalAccountNum EAN2
													WHERE EAN2.FinancialAccountNum = EAN.FinancialAccountNum
													AND EAN2.AccountTypeInd = EAN2.AccountTypeInd)
			AND  EAN.AccountTypeInd = 'P'	
		INNER JOIN dbo.CSIS_BillHeader BH
			ON BH.FinancialAccountNum = FT.FinancialAccountNum
			AND BH.BillHeaderNum = FT.BillHeaderNum
		LEFT OUTER JOIN dbo.CSIS_BASLBillLine BBL
			ON BBL.FinancialAccountNum = FT.FinancialAccountNum
			AND BBL.FinancialTransactionID = FT.FinancialTransactionID
			AND BBL.IncludeOnBillFlg = 'Y'
			AND BBL.BillLineFunctionCode = 'STEP'
			AND FT.RateID NOT IN ('C01', 'S01', 'WS1', '588', 'R2T','722', '719', '747','749','982', '198','589', '590','597','598' ,'724', '732', '736','742', '754', '756', 'WT1'
				)

	 
		WHERE	 FT.FinancialTransStatusInd != 'C' --–- excluding cancelled fin trans
		AND FT.FinancialTransTypeInd != 'X'--- excluding cancelled fin trans
		AND FT.FinancialTransTypeInd != 'P'--- excluding payment fin trans
		AND FT.FinancialTransTypeInd != 'Q'---excluding payment Cancellation
		AND FT.FinancialTransTypeInd != 'C' --– excluding Bill Segment Cancellation

		AND FT.BillSegSubTypeInd <> 'V'
		AND ft.FinancialTransDate >= '2004-07-00' 
		AND NOT EXISTS  (SELECT * 
							FROM  dbo.CSIS_PropertyGroup PG
							INNER JOIN  dbo.CSIS_PropertyInGroup PiGAll
								ON PiGAll.PropertyGroupNum = PG.PropertyGroupNum
							INNER JOIN dbo.CSIS_IndicatorDesc I
								ON I. IndicatorCode = 'PGS'
								AND I.IndicatorInd = PG.PropertyGroupStatusInd COLLATE Latin1_GENERAL_BIN
							WHERE PG.PropertyGroupTypeInd = 'C'
							AND I.IndicatorDesc	<> 'Cancelled           '
							AND  FT.PeriodStartDate BETWEEN PG.PropertyGroupWEF AND PG.PropertyGroupWET
							AND EAN.PropertyNumber = PiGAll.PropertyNum
						)

		)
		INSERT INTO [CSIS].[Stage_InvoiceLine]
			([FinancialAccountNum]
			, [FinancialTransactionID]
			, [BillLineSeqNum]
			, [RateID]
			, [ExternalAccountNumber]
			, [PropertyNumber]
			, EffectiveDate
			, AuthorisedDate
			, [PeriodStartDate]
			, [PeriodEndDate]
			, [BillHeaderNum]
			, [BillDueDate]
			, [BillHeaderDate]
			, BillHeaderTypeInd
			, WaterUseTierNumber
			, [Quantity]
			, [UnitPrice]
			, [InvoiceLineItemAmount]
			, [FinancialTransactionAmount]
			, FinancialTransStatusInd
			, FinancialTransTypeInd
			, RateClassInd
			, ETLSource
			, ETLSourceUpdated
			)
			SELECT 
				IL.[FinancialAccountNum]
				, IL.[FinancialTransactionID]
				, IL.[BillLineSeqNum]
				, IL.[RateID]
				, IL.[ExternalAccountNumber]
				, IL.[PropertyNumber]
				, IL.EffectiveDate
				, IL.AuthorisedDate
				, IL.[PeriodStartDate]
				, IL.[PeriodEndDate]
				, IL.[BillHeaderNum]
				, IL.[BillDueDate]
				, IL.[BillHeaderDate]
				, IL.BillHeaderTypeInd
				, IL.WaterUseTierNumber
				, IL.[Quantity]
				, IL.[UnitPrice]
				, IL.[InvoiceLineItemAmount]
				, IL.FinancialTransactionAmt
				, IL.FinancialTransStatusInd
				, IL.FinancialTransTypeInd
				, IL.RateClassInd
				, IL.ETLSource
				, CASE WHEN IL.ETLSourceUpdated1 > IL.ETLSourceUpdated2 THEN IL.ETLSourceUpdated1
					ELSE IL.ETLSourceUpdated2
					END AS ETLSourceUpdated

				FROM InvoiceLines IL
 
GO
