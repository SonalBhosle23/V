/****** Object:  StoredProcedure [CSIS].[InvoiceLine_Upsert]    Script Date: 3/02/2020 4:08:28 PM ******/
DROP PROCEDURE IF EXISTS [CSIS].[InvoiceLine_Upsert]
GO
/****** Object:  StoredProcedure [CSIS].[InvoiceLine_Upsert]    Script Date: 3/02/2020 4:08:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [CSIS].[InvoiceLine_Upsert] 
	@ETLExecutionID UNIQUEIDENTIFIER = NUll
	, @vblnPerformFullExtract bit = 0
	AS 
/*************************************************************************************************************************************************
Description: Update data in CSIS.InvoiceLine


Change Log
=================================================================================================================================================
Date		Author		Description
=================================================================================================================================================
29Nov2019	SKennedy	Initial version

=================================================================================================================================================
*************************************************************************************************************************************************/
SET XACT_ABORT ON;
SET NOCOUNT ON;
SET @ETLExecutionID = ISNULL (@ETLExecutionID, NEWID())
BEGIN TRY;

	BEGIN TRAN ;
	UPDATE T 
	SET
		T.[AuthorisedDate]				= S.[AuthorisedDate],
		T.[BillDueDate]					= S.[BillDueDate],
		T.[BillHeaderDate]				= S.[BillHeaderDate],
		T.[BillHeaderNum]				= S.[BillHeaderNum],
		T.[BillHeaderTypeInd]			= S.[BillHeaderTypeInd],
		T.[EffectiveDate]				= S.[EffectiveDate],
		T.[ETLSource]					= S.[ETLSource],
		T.[ETLSourceUpdated]			= S.[ETLSourceUpdated],
		T.[ExternalAccountNumber]		= S.[ExternalAccountNumber],
		T.[FinancialTransactionAmount]	= S.[FinancialTransactionAmount],
		T.[FinancialTransStatusInd]		= S.[FinancialTransStatusInd],
		T.[FinancialTransTypeInd]		= S.[FinancialTransTypeInd],
		T.[InvoiceLineItemAmount]		= S.[InvoiceLineItemAmount],
		T.[PeriodEndDate]				= S.[PeriodEndDate],
		T.[PeriodStartDate]				= S.[PeriodStartDate],
		T.[PropertyNumber]				= S.[PropertyNumber],
		T.[Quantity]					= S.[Quantity],
		T.[RateClassInd]				= S.[RateClassInd],
		T.[RateID]						= S.[RateID],
		T.[UnitPrice]					= S.[UnitPrice],
		T.[WaterUseTierNumber]			= S.[WaterUseTierNumber],
		
		T.ETLUpdatedExecutionID			= @ETLExecutionID,
		T.ETLUpdated					= SYSDATETIME ()
	
		FROM [CSIS].[InvoiceLine] T
		INNER JOIN [CSIS].[Stage_InvoiceLine] S
			ON T.[BillLineSeqNum] = S.[BillLineSeqNum]
			AND T.[FinancialAccountNum] = S.[FinancialAccountNum]
			AND T.[FinancialTransactionID] = S.[FinancialTransactionID]
		WHERE
			   ISNULL (T.[AuthorisedDate], '1 Jan 1800')		<> ISNULL (S.[AuthorisedDate], '1 Jan 1800')
			OR ISNULL (T.[BillDueDate], '1 Jan 1800')			<> ISNULL (S.[BillDueDate], '1 Jan 1800')
			OR ISNULL (T.[BillHeaderDate], '1 Jan 1800')		<> ISNULL (S.[BillHeaderDate], '1 Jan 1800')
			OR ISNULL (T.[BillHeaderNum], 0)					<> ISNULL (S.[BillHeaderNum], 0)
			OR ISNULL (T.[BillHeaderTypeInd], '')				<> ISNULL (S.[BillHeaderTypeInd], '')
			OR ISNULL (T.[EffectiveDate], '1 Jan 1800')			<> ISNULL (S.[EffectiveDate], '1 Jan 1800')
			OR ISNULL (T.[ETLSource], '')						<> ISNULL (S.[ETLSource], '')
			OR ISNULL (T.[ETLSourceUpdated], '1 Jan 1800')		<> ISNULL (S.[ETLSourceUpdated], '1 Jan 1800')
			OR ISNULL (T.[ExternalAccountNumber], '')			<> ISNULL (S.[ExternalAccountNumber], '')
			OR ISNULL (T.[FinancialTransactionAmount], 0)		<> ISNULL (S.[FinancialTransactionAmount], 0)
			OR ISNULL (T.[FinancialTransStatusInd], '')			<> ISNULL (S.[FinancialTransStatusInd], '')
			OR ISNULL (T.[FinancialTransTypeInd], '')			<> ISNULL (S.[FinancialTransTypeInd], '')
			OR ISNULL (T.[InvoiceLineItemAmount], 0)			<> ISNULL (S.[InvoiceLineItemAmount], 0)
			OR ISNULL (T.[PeriodEndDate], '1 Jan 1800')			<> ISNULL (S.[PeriodEndDate], '1 Jan 1800')
			OR ISNULL (T.[PeriodStartDate], '1 Jan 1800')		<> ISNULL (S.[PeriodStartDate], '1 Jan 1800')
			OR ISNULL (T.[PropertyNumber], 0)					<> ISNULL (S.[PropertyNumber], 0)
			OR ISNULL (T.[Quantity], 0)							<> ISNULL (S.[Quantity], 0)
			OR ISNULL (T.[RateClassInd], '')					<> ISNULL (S.[RateClassInd], '')
			OR ISNULL (T.[RateID], '')							<> ISNULL (S.[RateID], '')
			OR ISNULL (T.[UnitPrice], 0)						<> ISNULL (S.[UnitPrice], 0)
			OR ISNULL (T.[WaterUseTierNumber], 0)				<> ISNULL (S.[WaterUseTierNumber], 0)

	SELECT @@ROWCOUNT AS RowsUpdated;

	INSERT INTO [CSIS].[InvoiceLine]
		(
		  [AuthorisedDate]
		, [BillDueDate]
		, [BillHeaderDate]
		, [BillHeaderNum]
		, [BillHeaderTypeInd]
		, [BillLineSeqNum]
		, [EffectiveDate]
		, [ETLSource]
		, [ETLSourceUpdated]
		, [ExternalAccountNumber]
		, [FinancialAccountNum]
		, [FinancialTransactionAmount]
		, [FinancialTransactionID]
		, [FinancialTransStatusInd]
		, [FinancialTransTypeInd]
		, [InvoiceLineItemAmount]
		, [PeriodEndDate]
		, [PeriodStartDate]
		, [PropertyNumber]
		, [Quantity]
		, [RateClassInd]
		, [RateID]
		, [UnitPrice]
		, [WaterUseTierNumber]
		
		, ETLCreated
		, ETLCreatedExecutionID
		, ETLUpdated
		, ETLUpdatedExecutionID
		)
		SELECT 
			  S.[AuthorisedDate]
			, S.[BillDueDate]
			, S.[BillHeaderDate]
			, S.[BillHeaderNum]
			, S.[BillHeaderTypeInd]
			, S.[BillLineSeqNum]
			, S.[EffectiveDate]
			, S.[ETLSource]
			, S.[ETLSourceUpdated]
			, S.[ExternalAccountNumber]
			, S.[FinancialAccountNum]
			, S.[FinancialTransactionAmount]
			, S.[FinancialTransactionID]
			, S.[FinancialTransStatusInd]
			, S.[FinancialTransTypeInd]
			, S.[InvoiceLineItemAmount]
			, S.[PeriodEndDate]
			, S.[PeriodStartDate]
			, S.[PropertyNumber]
			, S.[Quantity]
			, S.[RateClassInd]
			, S.[RateID]
			, S.[UnitPrice]
			, S.[WaterUseTierNumber]
			, GETDATE()				AS ETLCreated
			, @ETLExecutionID		AS ETLCreatedETLExecutionID
			, GETDATE()				AS ETLUpdated
			, @ETLExecutionID		AS ETLUpdatedETLExecutionID
			FROM CSIS.Stage_InvoiceLine S
			WHERE NOT EXISTS (SELECT * FROM CSIS.InvoiceLine T 
								WHERE T.[BillLineSeqNum] = S.[BillLineSeqNum]
								AND T.[FinancialAccountNum] = S.[FinancialAccountNum]
								AND T.[FinancialTransactionID] = S.[FinancialTransactionID]
								);

	SELECT @@ROWCOUNT AS RowsInserted;

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
		@ErrorNumber		= ERROR_NUMBER() 
		,@ErrorSeverity		= ERROR_SEVERITY() 
		,@ErrorState		= ERROR_STATE()   
		,@ErrorProcedure	= ERROR_PROCEDURE()   
		,@ErrorLine			= ERROR_LINE() 
		,@ErrorMessage		= ERROR_MESSAGE() 

	Set @ErrorString = @ErrorMessage + ' at line ' + CONVERT (NVARCHAR, @ErrorLine) + ' in ' + @ErrorProcedure;
	RAISERROR (@ErrorString,  @ErrorSeverity, 1);
END CATCH;	

GO
