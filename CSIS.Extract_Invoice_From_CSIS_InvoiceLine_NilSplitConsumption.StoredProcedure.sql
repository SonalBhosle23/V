/****** Object:  StoredProcedure [CSIS].[Extract_Invoice_From_CSIS_InvoiceLine_NilSplitConsumption]    Script Date: 19/02/2020 4:48:30 PM ******/
DROP PROCEDURE IF EXISTS [CSIS].[Extract_Invoice_From_CSIS_InvoiceLine_NilSplitConsumption]
GO
/****** Object:  StoredProcedure [CSIS].[Extract_Invoice_From_CSIS_InvoiceLine_NilSplitConsumption]    Script Date: 19/02/2020 4:48:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [CSIS].[Extract_Invoice_From_CSIS_InvoiceLine_NilSplitConsumption] 
/*******************************************************************************

Name:             [CSIS.[Extract_Invoice_From_CSIS_InvoiceLine_NilSplitConsumption] 
Descriptive Name: Create CSIS.Invoice records for the records that were constructed as part of the 
					Nil Split CSA Consumption mapping rules for CSIS.InvoiceLine

Author:           S Kennedy
Creation Date:    31 Jan 2020
Version:          1.0


Modification History:
--------------------------------------------------------------------------------
Date		Name         Modification
--------------------------------------------------------------------------------
31Jan2020	SKennedy	Initial version.
04Feb2020	SKennedy	Extract Invoice record where one does not exist for the account/bill headernum/EffectiveDate/BillDueDate
						from CSIS (via the other non Nil Split CSA records)
07Feb2020	SKennedy	Updated payment behaviour to be "No Payment Required"
*******************************************************************************/
	@ExecutionID	UNIQUEIDENTIFIER = NULL
	AS
SET XACT_ABORT ON;
--SELECT GETDATE() 'Starting';
 
	;
SELECT @ExecutionID = ISNULL (@ExecutionID, NEWID() );

DECLARE @StartDate		DATE =  '1 Jul 2004'
	, @StartDate_CHAR	VARCHAR (10) =  '2004-07-01'

	;

BEGIN TRY
	BEGIN TRAN
	;
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
			IL.FinancialAccountNum
			, IL.BillHeaderNum
			, IL.BillDueDate								AS BillDueDate
			, 'S'											AS BillHeaderStatusInd
			, 'W'											AS BillHeaderTypeInd
			, CONVERT (DECIMAL (12, 2), 0)					AS BillTotalAmt
			, CONVERT (DECIMAL (12, 2), 0)					AS BillCurrentDueAmt
			, CONVERT (VARCHAR (10), NULL)					AS PaymentAmount
			, CONVERT (VARCHAR (10), NULL)					AS PaymentDate 
			, IL.EffectiveDate
			, 'No Payment Required'							AS BasePaymentBehaviour
			, 'No Payment Required'							AS PaymentBehaviour
			,  0											AS DaysToPay
			, 'No'											AS HasInvoiceData
			, 'No'											AS HasPaymentData
			, 'CSIS.InvoiceLine Nil Split Consumption'		AS ETLSource

			, MAX (IL.ETLUpdated)							AS ETLUpdated

			FROM CSIS.InvoiceLine IL

			WHERE IL.EffectiveDate >= @StartDate
			AND IL.ETLSource = 'FinancialTransaction Nil Split CSA Consumption'
			AND EXISTS (SELECT * FROM dbo.CSIS_ExternalAccountNum EAN
							WHERE EAN.FinancialAccountNum = IL.FinancialAccountNum
							AND  EAN.AccountTypeInd = 'P'	 -- only process "Property" accounts
						)
			AND IL.BillHeaderNum < 0		-- the records constructed by the Nil Split CSA Consumption mapping rules have a 
											-- negative value for FinancialTransactionID

			--AND NOT EXISTS (SELECT * FROM CSIS.InvoiceLine IL2
			--					WHERE IL2.FinancialAccountNum = IL.FInancialAccountNum	
			--					AND IL2.BillHeaderNum = IL.BillHeaderNum
			--					AND IL2.BillDueDate = IL.BillDueDate
			--					AND IL2.EffectiveDate = IL.EffectiveDate)
			GROUP BY IL.FinancialAccountNum
				, IL.BillHeaderNum
				, IL.EffectiveDate
				, IL.BillDueDate

	;
		SELECT @@ROWCOUNT AS 'CSIS.Stage_Invoice records inserted', GETDATE()
	;

	COMMIT
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
