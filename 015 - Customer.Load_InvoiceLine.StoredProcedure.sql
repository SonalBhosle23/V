USE [EDW]
GO
/****** Object:  StoredProcedure [Customer].[Load_InvoiceLine]    Script Date: 21/02/2020 12:14:49 PM ******/
DROP PROCEDURE IF EXISTS [Customer].[Load_InvoiceLine]
GO
/****** Object:  StoredProcedure [Customer].[Load_InvoiceLine]    Script Date: 21/02/2020 12:14:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [Customer].[Load_InvoiceLine] 
	@ETLExecutionID				UNIQUEIDENTIFIER
	, @vblnPerformFullExtract	BIT = 0 
	, @PackageRunID				INT = -1
	, @ETLSourceUpdated			DATETIME2 = '2019-11-28 08:45:33.7866667'
	AS
/***************************************************************************************************************************************************
Name:		[Customer].[Load_InvoiceLine]

Description:	Load staged data in Customer.InvoiceLine to the Customer.InvoiceLine table proper.
				Action Column: not specified
				Update Lineage: Yes 


Parameters: 
		@ETLExecutionID - identifier for the ETL process instance that called this S-Proc (used for logging and data lineage)
		@vblnPerformFullExtract - Flag indicating whether a FULL or incremental extract is being performed
									(a FULL Extract includes DELETING target records not found in the stage table - normally only applicable for SCD-1 targets)

Usage:
	DECLARE @ETLExecutionID				UNIQUEIDENTIFIER
	SET @ETLExecutionID	= NEWID()
	EXEC [Customer].[Load_InvoiceLine] 	@ETLExecutionID	

Modification History:
-----------------------------------------------------------------------------------------------------------------------------------------------------
Date		Name				Modification
-----------------------------------------------------------------------------------------------------------------------------------------------------
18Nov2019	S Kennedy		Initial Version 
25Nov2019	SKennedy		Remove code related to the 2013 SA Water Segments	 
26Nov2019	SKennedy		Changed Inferred member logic for Customer.Product so that it uses a group by / max ETLUpdated 
02Dec2019	SKennedy		Added @PackageRunID as an input parameter to support older package Id logging for pre-existing tables in EDW
03Dec2019	SKennedy		Added @ETLSourceUPdated and usage of table [Customer].[Stage_InvoiceLine2].  This is intended to allow the main stage
							table to be used for both delete sync and the update of Customer.InvoiceLine
							Changed from MERGE to UPDATE/INSERT 
04Dec2019	SKennedy		Change FK lookups to be inner joins.  Defaults are on the stage table columns now.
16Dec2019	SKennedy		Added column ETLSourceKey4 and change the unique constraint to include this column
14Jan2020	SKennedy		Recoded so this sproc has logic to loop through 6 months of data at a time and call [Load_InvoiceLine_MainUpdate] to 
							load onto table Customer.InvoiceLine
17Jan2020	SKennedy		Change date range for the loop to be in 1 month increments
29Jan2020	VBhosle			Renamed RateId to InvoiceLineTypeCode
20Feb2020	SKennedy		Add InvoiceDateCalendarKey
****************************************************************************************************************************************************/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE 
		@ErrorNumber	int,
		@ErrorSeverity	int,  
		@ErrorState		int,
		@ErrorProcedure varchar(128),
		@ErrorLine		int,
		@ErrorMessage	nvarchar(2000),
		@ErrorString	nvarchar(3000);

	DECLARE  
		  @ETLSourceUpdatedValue						DATETIME2
		, @EffectiveDateCalendarKeyMonth_Start	INT
		, @EffectiveDateCalendarKeyMonth_End	INT
	CREATE TABLE #StageKeys
		(ID								INT IDENTITY (1, 1)
		, ETLSourceUpdated				DATETIME2
		, EffectiveDateCalendarKeyMonth	CHAR (6)
		);

	CREATE TABLE #StageKeysToProcessPotential
		(ID										INT IDENTITY (1, 1)
		, ETLSourceUpdated						DATETIME2
		, EffectiveDateCalendarKeyMonth_Start	INT
		, EffectiveDateCalendarKeyMonth_End		INT
		);

	CREATE TABLE #StageKeysToProcess
		(ID										INT IDENTITY (1, 1)
		, ETLSourceUpdated						DATETIME2
		, EffectiveDateCalendarKeyMonth_Start	INT
		, EffectiveDateCalendarKeyMonth_End		INT
		);
	BEGIN TRY



		INSERT INTO #StageKeys
			(ETLSourceUpdated, EffectiveDateCalendarKeyMonth)
			SELECT DISTINCT 
				S.ETLSourceUpdated
				,  LEFT (EffectiveDateCalendarKey, 6)   
				FROM customer.stage_invoiceline S
				Order by  1,2

		;
		WITH DateList AS
			(SELECT *
				, EffectiveDateCalendarKeyMonth + '01' AS EffectiveDateCalendarKey_Start
				, EffectiveDateCalendarKeyMonth + '31'	AS EffectiveDateCalendarKey_End
				FROM #StageKeys
				
			)
			INSERT INTO #StageKeysToProcessPotential
				(ETLSourceUpdated, EffectiveDateCalendarKeyMonth_Start, EffectiveDateCalendarKeyMonth_End)
				SELECT 
					DL.ETLSourceUpdated	
					, DL.EffectiveDateCalendarKey_Start
					, DL.EffectiveDateCalendarKey_End
					FROM DateList DL
				
			INSERT INTO #StageKeysToProcess
				(ETLSourceUpdated, EffectiveDateCalendarKeyMonth_Start, EffectiveDateCalendarKeyMonth_End)
				SELECT 
					S.ETLSourceUpdated
					, S.EffectiveDateCalendarKeyMonth_Start
					, S.EffectiveDateCalendarKeyMonth_End
					FROM #StageKeysToProcessPotential S
					WHERE NOT EXISTS (SELECT * FROM Customer.InvoiceLine IL
										WHERE IL.ETLSourceUpdated = S.ETLSourceUpdated
										AND IL.EffectiveDateCalendarKey BETWEEN S.EffectiveDateCalendarKeyMonth_Start AND S.EffectiveDateCalendarKeyMonth_End
									 )
					ORDER BY S.ETLSourceUpdated, S.EffectiveDateCalendarKeyMonth_Start, S.EffectiveDateCalendarKeyMonth_End

		SELECT @@ROWCOUNT AS 'Key selected to be processed ', GETDATE();

		DECLARE  KeysOfInterest Cursor
			FOR SELECT 
					S.ETLSourceUpdated, S.EffectiveDateCalendarKeyMonth_Start, S.EffectiveDateCalendarKeyMonth_End 
					FROM #StageKeysToProcess S
					ORDER BY S.ETLSourceUpdated, S.EffectiveDateCalendarKeyMonth_Start, S.EffectiveDateCalendarKeyMonth_End
	
		OPEN KeysOfInterest

		FETCH NEXT FROM KeysOfInterest INTO @ETLSourceUpdatedValue, @EffectiveDateCalendarKeyMonth_Start, @EffectiveDateCalendarKeyMonth_End

		WHILE @@FETCH_STATUS = 0
		BEGIN
		
			TRUNCATE TABLE [Customer].[Stage_InvoiceLine2];

			INSERT INTO [Customer].[Stage_InvoiceLine2]
				([AuthorisedDateCalendarKey]
				,[BasePaymentBehaviour]
				,[BillCategory]
				,InvoiceDateCalendarKey
				,[InvoiceDueCalendarKey]
				,[BillHeaderStatusInd]
				,[BillHeaderTypeInd]
				,[BillSize]
				,[DaysToPay]
				,[EffectiveDateCalendarKey]
				,[ExternalAccountNumber]
				,[FinancialAccountNum]
				,[FinancialTransactionID]
				,[HasInvoiceData]
				,[HasPaymentData]
				,[InvoiceLineAmount]
				,[MosaicType2018]
				,[MosaicType2018Owner]
				,[OtherChargeClassification]
				,[PaymentBehaviour]
				,[ProductCategory]
				,[ProductSubType]
				,[ProductType]
				,[PropertyActive]
				,[Quantity]
				,[RateClassInd]
				,[InvoiceLineTypeCode]
			
				,[UnitPrice]
				,[WaterUseCategory]
				,[ETLSource]
				,[ETLSourceUpdated]
				,[ETLSourceKey1]
				,[ETLSourceKey2]
				,[ETLSourceKey3]
				,[ETLSourceKey4])
    
				SELECT
					S.[AuthorisedDateCalendarKey]
					, S.[BasePaymentBehaviour]
					, S.[BillCategory]
					, S.InvoiceDateCalendarKey
					, S.[InvoiceDueCalendarKey]
					, S.[BillHeaderStatusInd]
					, S.[BillHeaderTypeInd]
					, S.[BillSize]
					, S.[DaysToPay]
					, S.[EffectiveDateCalendarKey]
					, S.[ExternalAccountNumber]
					, S.[FinancialAccountNum]
					, S.[FinancialTransactionID]
					, S.[HasInvoiceData]
					, S.[HasPaymentData]
					, S.[InvoiceLineAmount]
					, S.[MosaicType2018]
					, S.[MosaicType2018Owner]
					, S.[OtherChargeClassification]
					, S.[PaymentBehaviour]
					, S.[ProductCategory]
					, S.[ProductSubType]
					, S.[ProductType]
					, S.[PropertyActive]
					, S.[Quantity]
					, S.[RateClassInd]
					, S.[InvoiceLineTypeCode]
					
					, S.[UnitPrice]
					, S.[WaterUseCategory]
					, S.[ETLSource]
					, S.[ETLSourceUpdated]
					, S.[ETLSourceKey1]
					, S.[ETLSourceKey2]
					, S.[ETLSourceKey3]
					, S.[ETLSourceKey4]
		
					FROM [Customer].[Stage_InvoiceLine] S
					WHERE ETLSourceUPdated = @ETLSourceUpdatedValue
					AND S.EffectiveDateCalendarKey BETWEEN @EffectiveDateCalendarKeyMonth_Start AND @EffectiveDateCalendarKeyMonth_End

			SELECT @@ROWCOUNT AS 'Rows extracted into [Customer].[Stage_InvoiceLine2] for update ', @ETLSourceUpdatedValue '@ETLSourceUpdatedValue'
				, @EffectiveDateCalendarKeyMonth_Start '@EffectiveDateCalendarKeyMonth_Start'
				, @EffectiveDateCalendarKeyMonth_End '@EffectiveDateCalendarKeyMonth_End'
				, GETDATE();

			EXEC [Customer].[Load_InvoiceLine_MainUpdate] 	@ETLExecutionID	

			SELECT 'finish [Customer].[Load_InvoiceLine_MainUpdate]', getDate()

			FETCH NEXT FROM KeysOfInterest INTO @ETLSourceUpdatedValue, @EffectiveDateCalendarKeyMonth_Start, @EffectiveDateCalendarKeyMonth_End

		END
-------------========================================
		CLOSE KeysOfInterest;
		DEALLOCATE KeysOfInterest;

		IF @@TRANCOUNT > 0
		BEGIN
			COMMIT TRANSACTION;
		END
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION;
		END

		SELECT  
			@ErrorNumber		= ERROR_NUMBER() 
			,@ErrorSeverity		= ERROR_SEVERITY() 
			,@ErrorState		= ERROR_STATE()   
			,@ErrorProcedure	= ERROR_PROCEDURE()   
			,@ErrorLine			= ERROR_LINE() 
			,@ErrorMessage		= ERROR_MESSAGE() 

		SET @ErrorString = @ErrorMessage + ' at line ' + CONVERT (NVARCHAR, @ErrorLine) + ' in ' + @ErrorProcedure;
		RAISERROR (@ErrorString,  @ErrorSeverity, 1);
	END CATCH
	--=================================================================================================
	
END
GO
