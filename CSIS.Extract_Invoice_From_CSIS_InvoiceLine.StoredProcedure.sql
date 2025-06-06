/****** Object:  StoredProcedure [CSIS].[Extract_Invoice_From_CSIS_InvoiceLine]    Script Date: 19/02/2020 4:48:30 PM ******/
DROP PROCEDURE IF EXISTS [CSIS].[Extract_Invoice_From_CSIS_InvoiceLine]
GO
/****** Object:  StoredProcedure [CSIS].[Extract_Invoice_From_CSIS_InvoiceLine]    Script Date: 19/02/2020 4:48:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE procedure [CSIS].[Extract_Invoice_From_CSIS_InvoiceLine] 
/*******************************************************************************

Name:             [CSIS.[ExtractInvoice_From_CSIS_InvoiceLine] 
Descriptive Name: Extract bill amounts and payments within the next 91 days

Author:           S Kennedy
Creation Date:    19 Nov 2019
Version:          1.0


Modification History:
--------------------------------------------------------------------------------
Date		Name         Modification
--------------------------------------------------------------------------------
19Nov2019	SKennedy	Initial version.
28Jan2019	SKennedy	Updates rules for PaymentDate, DaysToDay, base payment behaviour (payment early/ontime/late)
						and payment behaviour (payment early/ontime/late/often late)					
29Jan2020	SKennedy	Remove temp table usage - populate the stage table directly instead as the temp table
						usage is not adding value.
04Feb2020	SKennedy	Only extract records where FinancialTransactionID >= 0.  These are for invoices that CSIS 
						actually created.
						Records where FinancialTransactionID < 0 are handled by the extract for NIL split CSAs and
						are used by Customer Segmentation to apportion consumption and related charges for these CSAs
05Feb2020	SKennedy	Change BasePaymentBehaviour so that if the due amount is <= 0, the value used is "No Payment Required"
						The initial value for PaymentBehaviour also has this change - may be overridden by the calculation
						of "Often Late" (no change to that logic)
						Only process records from table CSIS.InvoiceLine WHERE BillHeaderNum > 0
*******************************************************************************/
	@ExecutionID	UNIQUEIDENTIFIER = NULL
	AS
SET XACT_ABORT ON;
--SELECT GETDATE() 'Starting';
 
	;
SELECT @ExecutionID = ISNULL (@ExecutionID, NEWID() );

DECLARE @StartDate		DATE =  '1 Jul 2004'
	, @StartDate_CHAR	VARCHAR (10) =  '2004-07-01'
	, @LoopStartDate	DATE
	, @LoopEndDate		DATE
	, @Counter			INT = 0

	, @StartFinancialAccountNum	INT =    0
	, @EndFinancialAccountNum	INT =  99415787
	;

CREATE TABLE #Stage_Invoice
	(FinancialAccountNum			INT
	
	, BillHeaderNum					INT
	, BillDueDate					DATE
	, BillHeaderDate				DATE
	, BillHeaderStatusInd			VARCHAR (1)
	, BillHeaderTypeInd				VARCHAR (1)
	, BillTotalAmt					DECIMAL (12, 2)
	, BillCurrentDueAmt				DECIMAL (12, 2)
	, PaymentAmountWithin7Days		DECIMAL (12, 2)
	, PaymentDateWithin7Days		Date
	, PaymentAmount					DECIMAL (12, 2)
	, PaymentDate					Date
	
	, EffectiveDate					DATE

--	, NextBillHeaderDate			Date
	, BasePaymentBehaviour			VARCHAR (50)
	, PaymentBehaviour				VARCHAR (50)
	, DaysToPay						INT
	, HasPaymentData				CHAR (3)
	, InvoiceLineItemAmount			DECIMAL (19, 2)
--	, ETLSource						VARCHAR (50)
	, ETLUpdated					DATETIME2
	)		
	;
	CREATE CLUSTERED INDEX IX_FinancialAccountNum_BillHeaderDate ON #Stage_Invoice (FinancialAccountNum, BillHeaderNum)
--	CREATE  INDEX IX_FinancialAccountNum_FinancialTransactionID ON #Stage_Invoice (FinancialAccountNum, FinancialTransactionID)
	;
	 
CREATE TABLE #Payments(
	FinancialAccountNum				INT,
	FinancialTransDate				VARCHAR (10),
	FinancialTransDate_DATE			DATE,
	FinancialTransactionAmount		DECIMAL (12, 2),
	ETLUpdated						DATETIME2
	) 
	;

BEGIN TRY
	;
	SELECT IL.FinancialAccountNum
		, IL.BillHeaderNum
		, IL.EffectiveDate
	
		INTO #InvoiceLineSummary
		FROM CSIS.InvoiceLine IL

		WHERE IL.EffectiveDate >= @StartDate
		AND IL.BillHeaderNum > 0
		GROUP BY IL.FinancialAccountNum
			, IL.BillHeaderNum
			, IL.EffectiveDate

	;
		SELECT @@ROWCOUNT AS '#InvoiceLineSummary records inserted', GETDATE()
	;
	INSERT INTO #Payments
		(FinancialAccountNum
		, FinancialTransDate
		, FinancialTransDate_DATE
		, FinancialTransactionAmount
		, ETLUpdated
		)
		SELECT  
			FT.FinancialAccountNum
			, FT.FinancialTransDate	AS FinancialTransDate
			, CONVERT (DATE, FT.FinancialTransDate)	AS FinancialTransDate_DATE
			, CONVERT (DECIMAL (12, 2), FT.FinancialTransactionAmt)
			, FT.Updated
			FROM dbo.CSIS_FinancialTransaction ft

			WHERE FT.BillHeaderNum = 0 
			AND FinancialTransTypeInd = 'P'  -- this should be payments.
			AND FT.PeriodStartDate >= @StartDate_CHAR
			
			AND EXISTS (SELECT * FROM dbo.CSIS_ExternalAccountNum EAN
						WHERE EAN.FinancialAccountNum = FT.FinancialAccountNum
						AND  EAN.AccountTypeInd = 'P'	
						)
			AND FT.FinancialAccountNum  IN (SELECT IL.FinancialAccountNum FROM #InvoiceLineSummary IL)

;
	SELECT @@ROWCOUNT AS 'Payments found on CSIS_FinancialTransaction', GETDATE()

;

	CREATE INDEX IX_FinancialAccountNum_FinancialTransDate_DATE
		on #Payments (FinancialAccountNum, FinancialTransDate_DATE)
		include (FinancialTransactionAmount)
	SELECT @@ROWCOUNT AS 'Index #Payments IX_FinancialAccountNum_FinancialTransDate_DATE created', GETDATE()

	;
	WITH Records AS
		(SELECT 
			IL.FinancialAccountNum
			, IL.BillHeaderNum
			, IL.EffectiveDate
			, CONVERT (DATE, BH.BillDueDate)								AS BillDueDate
			, CONVERT (DATE, BH.BillHeaderDate)								AS BillHeaderDate  -- InvoiceDate

			, BH.BillHeaderStatusInd
			, BH.BillHeaderTypeInd
		
			, CONVERT (DECIMAL (12, 2), BH.BillTotalAmt)					AS BillTotalAmt
			, CONVERT (DECIMAL (12, 2), BH.BillIssueCurrDueAmt)				AS BillCurrentDueAmt

			, - (SELECT SUM (P.FinancialTransactionAmount)					AS PaymentAmount
					FROM #Payments P
					WHERE P.FinancialAccountNum = BH.FinancialAccountNum
					AND P.FinancialTransDate_DATE BETWEEN CONVERT (DATE, BH.BillHeaderDate) AND DATEADD (DAY, 7,  CONVERT (DATE, BH.BillHeaderDate))
				)
				AS PaymentAmountWithin7Days
	
			, (SELECT MAX (FinancialTransDate)								AS PaymentDate
					FROM #Payments P
					WHERE P.FinancialAccountNum = BH.FinancialAccountNum
					AND P.FinancialTransDate_DATE BETWEEN CONVERT (DATE, BH.BillHeaderDate) AND DATEADD (DAY, 7,  CONVERT (DATE, BH.BillHeaderDate) )
				)
				AS PaymentDateWithin7Days
				
			, - (SELECT SUM (P.FinancialTransactionAmount)					AS PaymentAmount
					FROM #Payments P
					WHERE P.FinancialAccountNum = BH.FinancialAccountNum
					AND P.FinancialTransDate_DATE BETWEEN CONVERT (DATE, BH.BillHeaderDate) AND DATEADD (DAY, 3,  CONVERT (DATE, BH.BillDueDate))
				)
				AS PaymentAmountByDueDate
	
			, (SELECT MAX (FinancialTransDate)								AS PaymentDate
					FROM #Payments P
					WHERE P.FinancialAccountNum = BH.FinancialAccountNum
					AND P.FinancialTransDate_DATE BETWEEN CONVERT (DATE, BH.BillHeaderDate) AND DATEADD (DAY, 3,  CONVERT (DATE, BH.BillDueDate) )
				)
				AS PaymentDateByDueDate
				

			, - (SELECT SUM (P.FinancialTransactionAmount)					AS PaymentAmount
					FROM #Payments P
					WHERE P.FinancialAccountNum = BH.FinancialAccountNum
					AND P.FinancialTransDate_DATE BETWEEN CONVERT (DATE, BH.BillHeaderDate) AND DATEADD (DAY, 91,  CONVERT (DATE, BH.BillHeaderDate))
				)
				AS PaymentAmount
	
			, (SELECT MAX (FinancialTransDate)								AS PaymentDate
					FROM #Payments P
					WHERE P.FinancialAccountNum = BH.FinancialAccountNum
					AND P.FinancialTransDate_DATE BETWEEN CONVERT (DATE, BH.BillHeaderDate) AND DATEADD (DAY, 91,  CONVERT (DATE, BH.BillHeaderDate) )
				)
				AS PaymentDate 
				
		--	, IL.ETLSource
			, BH.Updated									AS ETLUpdated

			FROM #InvoiceLineSummary IL

			INNER JOIN [dbo].[CSIS_BillHeader] BH
				ON BH.FinancialAccountNum = IL.FinancialAccountNum
				AND BH.BillHeaderNum  = IL.BillHeaderNum

			WHERE EXISTS (SELECT * FROM dbo.CSIS_ExternalAccountNum EAN
							WHERE EAN.FinancialAccountNum = BH.FinancialAccountNum
							AND  EAN.AccountTypeInd = 'P'	 -- only process "Property" accounts
						)

		)
		INSERT INTO CSIS.Stage_Invoice
			(FinancialAccountNum, BillHeaderNum, BillDueDate 
			, BillHeaderStatusInd, BillHeaderTypeInd, BillTotalAmt
			, BillCurrentDueAmt

			, PaymentAmount
			, PaymentDate
			, EffectiveDate
			, BasePaymentBehaviour, PaymentBehaviour, DaysToPay
			, [HasInvoiceData]
			, HasPaymentData
			, [ETLSource]
			, ETLSourceUpdated
			)
			SELECT 
				R.FinancialAccountNum, R.BillHeaderNum, R.BillDueDate 
				, R.BillHeaderStatusInd, R.BillHeaderTypeInd, R.BillTotalAmt
				, R.BillCurrentDueAmt
			--	, R.PaymentAmountWithin7Days
			--	, R.PaymentDateWithin7Days
				, CASE 
					WHEN R.BillCurrentDueAmt <= 0							THEN NULL
					WHEN R.PaymentAmountWithin7Days >= R.BillCurrentDueAmt 
							THEN R.PaymentAmountWithin7Days
					WHEN R.PaymentAmountByDueDate >= R.BillCurrentDueAmt 
							THEN R.PaymentAmountByDueDate
					ELSE  R.PaymentAmount		
					END														AS PaymentAmount
				 
				, CASE 
					WHEN R.BillCurrentDueAmt <= 0							THEN NULL
					WHEN R.PaymentAmountWithin7Days >= R.BillCurrentDueAmt 
							THEN R.PaymentDateWithin7Days
					WHEN R.PaymentAmountByDueDate >= R.BillCurrentDueAmt 
							THEN R.PaymentDateByDueDate
					ELSE  R.PaymentDate
					END															AS PaymentDate


				, R.EffectiveDate
				, CASE 
					WHEN R.BillCurrentDueAmt <= 0															THEN 'No Payment Required'
					WHEN R.PaymentDate IS NULL																THEN 'No Payment Received'

					WHEN DATEDIFF (Day, R.BillHeaderDate, R.PaymentDateWithin7Days) <= 7				
							AND R.PaymentAmountWithin7Days >= R.BillCurrentDueAmt 							THEN 'Early'

					WHEN R.PaymentDateByDueDate IS NOT NULL	
							AND R.PaymentAmountByDueDate >= R.BillCurrentDueAmt 							THEN 'On Time'
					WHEN  R.PaymentDate IS NULL
						OR   R.PaymentAmount < R.BillCurrentDueAmt
						OR R.PaymentDate > DATEADD (Day, 3 , BillDueDate)
																											THEN 'Late'
					ELSE 'Unknown'
					END AS BasePaymentBehaviour

				, CASE 
					WHEN R.BillCurrentDueAmt <= 0															THEN 'No Payment Required'
					WHEN R.PaymentDate IS NULL																THEN 'No Payment Received'

					WHEN DATEDIFF (Day, R.BillHeaderDate, R.PaymentDateWithin7Days) <= 7				
							AND R.PaymentAmountWithin7Days >= R.BillCurrentDueAmt 							THEN 'Early'

					WHEN R.PaymentDateByDueDate IS NOT NULL	
							AND R.PaymentAmountByDueDate >= R.BillCurrentDueAmt 							THEN 'On Time'

					WHEN  R.PaymentDate IS NULL
						OR R.PaymentAmount < R.BillCurrentDueAmt
						OR R.PaymentDate > DATEADD (Day, 3 , R.BillDueDate)
																											THEN 'Late'
					ELSE 'Unknown'
					END 																		AS PaymentBehaviour
				
				, CASE 
					WHEN R.BillCurrentDueAmt <= 0							THEN 0
					WHEN R.PaymentAmountWithin7Days >= R.BillCurrentDueAmt 
							THEN DATEDIFF (Day, R.BillHeaderDate, R.PaymentDateWithin7Days)	
					WHEN R.PaymentAmountByDueDate >= R.BillCurrentDueAmt 
							THEN DATEDIFF (Day, R.BillHeaderDate, R.PaymentDateByDueDate)	
					ELSE DATEDIFF (Day, R.BillHeaderDate, R.PaymentDate)
					END																			AS DaysToPay

			   , 'Yes'			AS HasInvoiceData
				, CASE 
					WHEN R.PaymentDate IS NULL THEN 'No'
					ELSE 'Yes'
					END
					AS HasPaymentData

				, 'CSIS.InvoiceLine'	AS ETLSource
				, R.ETLUpdated	AS ETLSourceUpdated

				FROM Records R
				ORDER BY FinancialAccountNum, BillHeaderDate
			;
	SELECT @@Rowcount AS 'Inserted into csis.Stage_Invoice', GETDATE()
	;


--	BEGIN TRAN;
----select count(*) '#Stage_Invoice record count inside TRANSACTION' From #Stage_Invoice 
--		INSERT INTO [CSIS].[Stage_Invoice]
--			([BasePaymentBehaviour]
--			,[BillHeaderNum]
--			,[BillDueDate]
--			,[BillHeaderStatusInd]
--			,[BillHeaderTypeInd]
--			,[BillTotalAmt]
--			,[BillCurrentDueAmt]
--			,[DaysToPay]
--			,[EffectiveDate]
--			,[FinancialAccountNum]

--			,[HasInvoiceData]
--			,[HasPaymentData]
--			,[PaymentAmount]
--			,[PaymentBehaviour]
--			,[PaymentDate]
--			,[ETLSource]
--			,[ETLSourceUpdated])
--			SELECT 
--				S.BasePaymentBehaviour
--			   , S.BillHeaderNum
--			   , S.BillDueDate
--			   , S.BillHeaderStatusInd
--			   , S.BillHeaderTypeInd
--			   , S.BillTotalAmt
--			   , S.BillCurrentDueAmt
--			   , S.DaysToPay
--			   , S.EffectiveDate
--			   , S.FinancialAccountNum

--			   , 'Yes'			AS HasInvoiceData
--			   , S.HasPaymentData
--			   , S.PaymentAmount
--			   , S.PaymentBehaviour
--			   , S.PaymentDate
--			   , 'CSIS.InoiceLine'	AS ETLSource
--			   , S.ETLUpdated		AS ETLSourceUpdated
--				FROM #Stage_Invoice  S
--	SELECT @@ROWCOUNT AS 'Inserted in CSIS_Stage_Invoice', GETDATE()

--	;
--		--END				
--	COMMIT
END TRY


BEGIN CATCH
	IF @@TRANcount > 0
	BEGIN
		ROLLBACK;
	END;
	DECLARE @ErrorNumber	INT,
		@ErrorSeverity		INT,  
		@ErrorState			INT,
		@ErrorProcedure		VARCHAR (128),
		@ErrorLine			INT,
		@ErrorMessage		NVARCHAR (2000),
		@ErrorString		NVARCHAR (3000);
		
	SELECT  
		@ErrorNumber = ERROR_NUMBER() 
		,@ErrorSeverity	= ERROR_SEVERITY() 
		,@ErrorState = ERROR_STATE()   
		,@ErrorProcedure = ERROR_PROCEDURE()   
		,@ErrorLine = ERROR_LINE() 
		,@ErrorMessage = ERROR_MESSAGE() 

	Set @ErrorString = @ErrorMessage + ' at line ' + CONVERT (NVARCHAR, @ErrorLine) + ' in ' + @ErrorProcedure;
	RAISERROR (@ErrorString,  @ErrorSeverity, 1);
END CATCH;	
GO
