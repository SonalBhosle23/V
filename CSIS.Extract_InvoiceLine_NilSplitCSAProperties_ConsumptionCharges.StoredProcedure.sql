/****** Object:  StoredProcedure [CSIS].[Extract_InvoiceLine_NilSplitCSAProperties_ConsumptionCharges]    Script Date: 20/02/2020 3:51:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP PROCEDURE IF EXISTS [CSIS].[Extract_InvoiceLine_NilSplitCSAProperties_ConsumptionCharges]
GO
CREATE PROCEDURE [CSIS].[Extract_InvoiceLine_NilSplitCSAProperties_ConsumptionCharges]
	@ExecutionID	UNIQUEIDENTIFIER = NULL
	, @ETLUpdated	DATETIME2 = '1 Jan 2018'
	AS
/*******************************************************************************

Name:             CSIS.[Extract_InvoiceLine_NilSplitCSAProperties_FixedCharges] 
Descriptive Name: Extract InvoiceLine records from CSIS_FinancialTransaction 
					for properties that were in a NIL split common supply agreement
					when the charges were incurred.  Only fixed charges are extracted
					(i.e. where there are no CSIS_BASLBillLine records related 
					to the CSIS_FinancialTransaction records)

					Charges that are apportioned are those for RateIDs that 
					have RateClassInd either 'U' or 'u'.

Author:           S Kennedy
Creation Date:    12 Dec 2019
Version:          1.0


Modification History:
--------------------------------------------------------------------------------
Date          Name         Modification
--------------------------------------------------------------------------------
12Dec2019	SKennedy	Initial version.
28Jan2020	SKennedy	Change WaterUseTier calculation to use PeriodEndDate
						Change lookup of CSIS_ExternalAccountNum to use the last record based on the value of ExternalAccountNumberWET
						Added a filter when looking up records on dbo.CSIS_BASLBillLine to exclude records for a selection of RateID's
						Changed the calculation of InvoiceLineItemAmount so that when (BillLineParm1QTY * BillLineParm2Qty) <> BillLineResultAmt
						the value from FinancialTransactionAmt is used instead on BillLineResultAmt.
						Only extract where CSIS_ExternalAccountNum.AccountTypeInd = 'P'	
03Feb2020	SKennedy	Round InvoiceLineItemAmount to 2 decimal places
05Feb2020	SKennedy	UPdated mapping rules for records created for supplied properties
						Sign is reversed for FinancialTransactionID, BillHeaderNum and BillLineSeqNum
						NULL is used for AuthorisedDate
07Feb2020	SKennedy 	'1 Jan 1900' is used for BillHeaderDate, BillDueDate
14Feb2020	SKennedy	Change the check (BillLineParm1QTY * BillLineParm2Qty) <> BillLineResultAmt so that both sides of the condition
						are rounded to 2 decimal places before the comparison
20Feb2020	SKennedy	Added filters on CSIS_BASLBillLine  - BillLineFunctionCode = 'STEP'
															- IncludeOnBillFlg = 'Y'
						Round InvoiceLineItemAmount to 2 dec places
*******************************************************************************/	
SELECT @ExecutionID = ISNULL (@ExecutionID, NEWID() );	

CREATE TABLE #Properties
	(PropertyGroupNum	INT
	, PropertyNum		INT
	, PropertyRoleInd	CHAR (1)
	, PropertyRole		VARCHAR (30)
	, PropertyGroupWEF	VARCHAR (10)
	, PropertyGroupWET	VARCHAR (10)
	, PropertyCount		SMALLINT
	)
	;
CREATE TABLE #SupplyingProperties
	(PropertyGroupNum	INT
	, PropertyNum		INT
	, PropertyRoleInd	CHAR (1)
	, PropertyGroupWEF	VARCHAR (10)
	, PropertyGroupWET	VARCHAR (10)
	)
	;
CREATE TABLE #TieredRateID
	(RateID				VARCHAR (3)
	, StartDate_Char	VARCHAR (10)
	, StartDate			DATE
	, EndDate			DATE
	, EndDate_CHAR		VARCHAR (10))
	;

CREATE TABLE #Charges
	(PropertyRoleInd				CHAR (1),
	PropertyGroupNum				INT,
	
	[FinancialAccountNum]			INT,
	[FinancialTransactionID]		INT,
	[BillLineSeqNum]				INT ,
	[RateID]						CHAR(3),
	[ExternalAccountNumber]			CHAR(10) ,
	[PropertyNumber]				INT,
	[EffectiveDate]					DATE NULL,
	[AuthorisedDate]				DATE,
	[PeriodStartDate]				DATE,
	[PeriodEndDate]					DATE,
	[BillHeaderNum]					INT ,
	[BillDueDate]					DATE,
	[BillHeaderDate]				DATE,
	[BillHeaderTypeInd]				CHAR(1) ,
	[WaterUseTierNumber]			SMALLINT,
	[Quantity]						DECIMAL(19, 5),
	[UnitPrice]						DECIMAL(19, 5),
	[InvoiceLineItemAmount]			DECIMAL(19, 5),
	WaterApportionPercent			DECIMAL (10, 6),

	[FinancialTransactionAmount]	DECIMAL(19, 5) NULL,
	[FinancialTransStatusInd]		CHAR(1) ,
	[FinancialTransTypeInd]			CHAR(1),
	[RateClassInd]					CHAR(1),
	[ETLSourceUpdated]				DATETIME2
	)  ; 

CREATE INDEX IX_StageInvoiceLine_PropertyGroupNum_PropertyRole	
	ON #Charges (PropertyGroupNum, PropertyRoleInd, PropertyNumber,FinancialAccountNum, PeriodStartDate)
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
 
 -- STEP 1 - extract charges for consumption for SUPPLYING properties

INSERT INTO #SupplyingProperties
	(PropertyGroupNum, PropertyNum, PropertyRoleInd, PropertyGroupWEF, PropertyGroupWET)
	SELECT  
		PG.PropertyGroupNum
		, PiG.PropertyNum
		, PiG.PropertyRoleInd
	
		--, CASE PiG.PropertyRoleInd 
		--	WHEN 'A' THEN 'Supplying property (real)'
		--	WHEN 'B' THEN 'Supplied property'
		--	WHEN 'C' THEN 'Supplying property (psuedo)'
		--	END PropertyRole

		, PG.PropertyGroupWEF
		, PG.PropertyGroupWET
		FROM dbo.CSIS_PropertyInGroup PiG
		INNER JOIN dbo.CSIS_PropertyGroup PG
			ON PG.PropertyGroupNum = PiG.PropertyGroupNum
			AND PG.PropertyGroupTypeInd = 'C'
		INNER JOIN dbo.CSIS_IndicatorDesc I
			ON I. IndicatorCode = 'PGS'
			AND I.IndicatorInd = PG.PropertyGroupStatusInd COLLATE Latin1_GENERAL_BIN
		WHERE PG.ApportionOptionInd= 'N'
		AND I.IndicatorDesc	<> 'Cancelled           '
		AND PropertyGroupWET >= '2004-07-01'
		AND PG.PropertyGroupWEf <= PG.PropertyGroupWET 
		AND PiG.PropertyRoleInd IN ('A', 'C')
--And Pig.PropertyGroupNum BETWEEN 4143 and 5143

--and Pig.PropertyGroupNum = 57297

		;
	
	
 ;
 WITH ConsumptionCharges AS
	(
	SELECT   
		PiG.PropertyRoleInd
		, PiG.PropertyGroupNum
		, FT.FinancialAccountNum
		, FT.FinancialTransactionID
		, BBL.BillLineSeqNum										AS BillLineSeqNum
		, FT.rateid
		, EAN.ExternalAccountNumber
		, ean.PropertyNumber
	
		, FT.FinancialTransDate										AS EffectiveDate
		, FT.AuthorisedDate											AS AuthorisedDate

		, FT.PeriodStartDate
		, FT.PeriodEndDate

		, FT.BillHeaderNum
		, BH.BillDueDate											AS BillDueDate
		, BH.BillHeaderDate											AS BillHeaderDate
		, BH.BillHeaderTypeInd
	 
		, CASE WHEN EXISTS (SELECT * FROM #TieredRateID TR WHERE TR.RateID = FT.RateID AND FT.PeriodEndDate BETWEEN TR.StartDate_CHAR AND TR.EndDate_CHAR)
			THEN ROW_NUMBER() OVER (PARTITION BY FT.FinancialAccountNum, FT.FinancialTransactionID ORDER BY BBL.BillLineSeqNum) 
			ELSE NULL
			END AS WaterUseTierNumber
	
		, CONVERT (DECIMAL (19,5), BBL.BillLineParm1QTY)		AS Quantity
		, CONVERT (DECIMAL (19,5), BBL.BillLineParm2QTY)		AS UnitPrice
		, CONVERT (DECIMAL (19, 2) ,ROUND ( ISNULL (CASE WHEN ROUND (CONVERT (DECIMAL (19,5), BBL.BillLineParm1QTY) * CONVERT (DECIMAL (19,5), BBL.BillLineParm2Qty), 2) = ROUND (CONVERT (DECIMAL (19,5), BBL.BillLineResultAmt), 2)
														THEN CONVERT (DECIMAL (19,5), BBL.BillLineResultAmt)
														ELSE NULL END
													, CONVERT (DECIMAL (19, 2) , FT.FinancialTransactionAmt)
													)	
										, 2)
				   )											AS InvoiceLineItemAmount
		, FT.FinancialTransactionAmt
	 
		, FT.FinancialTransStatusInd
		, FT.FinancialTransTypeInd
 
		, FT.RateClassInd
		, CASE WHEN FT.Updated > BH.Updated THEN FT.Updated 
			ELSE BH.Updated END										AS ETLSourceUpdated1
		, EAN.Updated												AS ETLSourceUpdated2

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

		INNER JOIN #SupplyingProperties PiG
			ON PiG.PropertyNum = EAN.PropertyNumber
			AND FT.PeriodStartDate BETWEEN PiG.PropertyGroupWEF AND PiG.PropertyGroupWET
		INNER JOIN dbo.CSIS_BASLBillLine BBL
			ON BBL.FinancialAccountNum = FT.FinancialAccountNum
			AND BBL.FinancialTransactionID = FT.FinancialTransactionID
			AND FT.RateID NOT IN ('C01', 'S01', 'WS1', '588', 'R2T','722', '719', '747','749','982', '198','589', '590','597','598' ,'724', '732', '736','742', '754', '756', 'WT1'
				)
			AND BBL.IncludeOnBillFlg = 'Y'
			AND BBL.BillLineFunctionCode = 'STEP'
		INNER JOIN dbo.CSIS_RateSchedule RS
			ON RS.RateID = FT.RateID
		WHERE	 FT.FinancialTransStatusInd != 'C' --–- excluding cancelled fin trans
		AND FT.FinancialTransTypeInd != 'X'--- excluding cancelled fin trans
		AND FT.FinancialTransTypeInd != 'P'--- excluding payment fin trans
		AND FT.FinancialTransTypeInd != 'Q'---excluding payment Cancellation
		AND FT.FinancialTransTypeInd != 'C' --– excluding Bill Segment Cancellation
		AND ft.FinancialTransDate >= '2004-07-00' 
		AND RS.RateClassInd  COLLATE Latin1_General_BIN IN ('U', 'u')  
		--AND FT.BillSegSubTypeInd NOT IN ('S', 'V')

		)
		INSERT INTO #Charges
			(PropertyRoleInd
			, PropertyGroupNum
			, [FinancialAccountNum]
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
			, ETLSourceUpdated
			)
			SELECT 
				CC.PropertyRoleInd
				, CC.PropertyGroupNum
				, CC.[FinancialAccountNum]
				, CC.[FinancialTransactionID]
				, CC.[BillLineSeqNum]
				, CC.[RateID]
				, CC.[ExternalAccountNumber]
				, CC.[PropertyNumber]
				, CC.EffectiveDate
				, CC.AuthorisedDate
				, CC.[PeriodStartDate]
				, CC.[PeriodEndDate]
				, CC.[BillHeaderNum]
				, CC.[BillDueDate]
				, CC.[BillHeaderDate]
				, CC.BillHeaderTypeInd
				, CC.WaterUseTierNumber
				, CC.[Quantity]
				, CC.[UnitPrice]
				, CC.[InvoiceLineItemAmount]
				, CC.FinancialTransactionAmt
				, CC.FinancialTransStatusInd
				, CC.FinancialTransTypeInd
				, CC.RateClassInd
				, CASE WHEN CC.ETLSourceUpdated1 > CC.ETLSourceUpdated2 THEN CC.ETLSourceUpdated1
					ELSE CC.ETLSourceUpdated2
					END AS ETLSourceUpdated

				FROM ConsumptionCharges CC
				order by CC.[FinancialAccountNum]
					,  CC.EffectiveDate

--select @@ROWCOUNT AS 'Consumption extracted'
--SELECT * FROM #Charges


--====================================================================
--====================================================================
-- STEP 2 - apply charges to each property in the Nil Split CSA
--====================================================================
--====================================================================



INSERT INTO #Properties
	(PropertyGroupNum, PropertyNum, PropertyRoleInd, PropertyRole, PropertyGroupWEF, PropertyGroupWET
	, PropertyCount)
	SELECT  
		PG.PropertyGroupNum
		, PiG.PropertyNum
		, PiG.PropertyRoleInd
		, CASE PiG.PropertyRoleInd 
			WHEN 'A' THEN 'Supplying property (real)'
			WHEN 'B' THEN 'Supplied property'
			WHEN 'C' THEN 'Supplying property (psuedo)'
			END													AS PropertyRole
		, PG.PropertyGroupWEF
		, PG.PropertyGroupWET
		, (SELECT COUNT(*) FROM  dbo.CSIS_PropertyInGroup PiG2
			WHERE PiG2.PropertyGroupNum = PIG.PropertyGroupNum
			AND Pig2.PropertyRoleInd <> 'C')					AS PropertyCount
		FROM dbo.CSIS_PropertyInGroup PiG
		INNER JOIN dbo.CSIS_PropertyGroup PG
			ON PG.PropertyGroupNum = PiG.PropertyGroupNum
			AND PG.PropertyGroupTypeInd = 'C'

		INNER JOIN dbo.CSIS_IndicatorDesc I
			ON I. IndicatorCode = 'PGS'
			AND I.IndicatorInd = PG.PropertyGroupStatusInd COLLATE Latin1_GENERAL_BIN
		WHERE PG.ApportionOptionInd= 'N'
		AND I.IndicatorDesc	<> 'Cancelled           '
		AND PropertyGroupWET >= '2004-07-01'
		AND PG.PropertyGroupWEf <= PG.PropertyGroupWET 

----And Pig.PropertyGroupNum BETWEEN 4143 and 5143
-- and Pig.PropertyGroupNum =57297		;
----select * from #Properties

	
	CREATE CLUSTERED INDEX IX_PropertyGroups_PropertyNum_PropertyGroupWEF_PropertyGroupWET
		ON #Properties	(PropertyNum, PropertyGroupWEF, PropertyGroupWET, PropertyRole)
 
 ;
 WITH InvoiceLines AS
	(
	SELECT   
		P.PropertyRoleInd
		, P.PropertyGroupNum
		, EAN.FinancialAccountNum
		, CASE WHEN P.PropertyRoleInd IN ('A', 'C')
			THEN C.FinancialTransactionID
			ELSE C.FinancialTransactionID * -1
			END												AS FinancialTransactionID
		
		, CASE WHEN P.PropertyRoleInd IN ('A', 'C')
			THEN C.BillLineSeqNum
			ELSE C.BillLineSeqNum * -1
			END												AS BillLineSeqNum
--		, C.BillLineSeqNum									AS BillLineSeqNum
		, C.rateid
		, EAN.ExternalAccountNumber
		, ean.PropertyNumber
	
		, C.EffectiveDate									AS EffectiveDate

		, CASE WHEN P.PropertyRoleInd IN ('A', 'C')
			THEN C.AuthorisedDate
			ELSE NULL
			END												AS AuthorisedDate
	--	, C.AuthorisedDate									AS AuthorisedDate

		, C.PeriodStartDate
		, C.PeriodEndDate

		
		, CASE WHEN P.PropertyRoleInd IN ('A', 'C')
			THEN C.BillHeaderNum
			ELSE C.BillHeaderNum * -1
			END												AS BillHeaderNum
		--, C.BillHeaderNum

		, CASE WHEN P.PropertyRoleInd IN ('A', 'C')
			THEN BH.BillDueDate
			ELSE '1 Jan 1900'
			END												AS BillDueDate
	--	, BH.BillDueDate									AS BillDueDate


		, CASE WHEN P.PropertyRoleInd IN ('A', 'C')
			THEN BH.BillHeaderDate
			ELSE '1 Jan 1900'
			END												AS BillHeaderDate
		--, BH.BillHeaderDate									AS BillHeaderDate
		, BH.BillHeaderTypeInd
	 
		, C.WaterUseTierNumber
	
		, CASE WHEN P.PropertyRoleInd = 'C' THEN NULL
			ELSE C.Quantity  / P.PropertyCount
			END												AS Quantity
				
		, C.UnitPrice
		, CASE WHEN P.PropertyRoleInd = 'C' THEN 0
			ELSE C.InvoiceLineItemAmount  / P.PropertyCount
			END												AS InvoiceLineItemAmount

		, CASE WHEN P.PropertyRoleInd = 'C' THEN 0
			ELSE C.FinancialTransactionAmount
			END												AS FinancialTransactionAmount
	 
		, C.FinancialTransStatusInd
		, C.FinancialTransTypeInd
 
		, C.RateClassInd
		, 'FinancialTransaction Nil Split CSA Consumption'	AS ETLSource
		, C.ETLSourceUpdated
		, P.PropertyCount
		FROM #SupplyingProperties SP
		INNER JOIN #Properties P
			ON P.PropertyGroupNum = SP.PropertyGroupNum
		INNER JOIN #Charges C
			ON C.PropertyNumber = SP.PropertyNum
			AND C.PeriodStartDate BETWEEN P.PropertyGroupWEF AND P.PropertyGroupWET

		INNER JOIN dbo.CSIS_BillHeader BH
			ON BH.FinancialAccountNum = C.FinancialAccountNum
			AND BH.BillHeaderNum = C.BillHeaderNum

		INNER JOIN dbo.CSIS_ExternalAccountNum EAN 
			ON EAN.PropertyNumber = P.PropertyNum
			AND EAN.ExternalAccountNumberWET = (SELECT MAX (EAN2.ExternalAccountNumberWET)
													FROM dbo.CSIS_ExternalAccountNum EAN2
													WHERE EAN2.FinancialAccountNum = EAN.FinancialAccountNum
													AND EAN2.AccountTypeInd = EAN2.AccountTypeInd)
			AND  EAN.AccountTypeInd = 'P'	

--	AND EAN.PropertyNumber= 1090
--and c.EffectiveDate Between '1 aug 2014' and '1 oct 2014'
	)

		INSERT INTO CSIS.Stage_InvoiceLine
 
			( [FinancialAccountNum]
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
				, ROUND (IL.[InvoiceLineItemAmount], 2) AS [InvoiceLineItemAmount]
				, IL.FinancialTransactionAmount
				, IL.FinancialTransStatusInd
				, IL.FinancialTransTypeInd
				, IL.RateClassInd
				, IL.ETLSource
				, IL.ETLSourceUpdated
			--	 , il.PropertyCount
				FROM InvoiceLines IL
 				order by IL.[FinancialAccountNum]
					,  IL.EffectiveDate
GO
