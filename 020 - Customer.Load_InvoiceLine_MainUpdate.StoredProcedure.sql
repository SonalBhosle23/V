USE [EDW]
GO
/****** Object:  StoredProcedure [Customer].[Load_InvoiceLine_MainUpdate]    Script Date: 21/02/2020 12:14:49 PM ******/
DROP PROCEDURE IF EXISTS [Customer].[Load_InvoiceLine_MainUpdate]
GO
/****** Object:  StoredProcedure [Customer].[Load_InvoiceLine_MainUpdate]    Script Date: 21/02/2020 12:14:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [Customer].[Load_InvoiceLine_MainUpdate] 
	@ETLExecutionID				UNIQUEIDENTIFIER
	, @vblnPerformFullExtract	BIT = 0 
	, @PackageRunID				INT = -1
	, @ETLSourceUpdated			DATETIME2 = '2019-11-28 08:45:33.7866667'
	AS
/***************************************************************************************************************************************************
Name:		[Customer].[Load_InvoiceLine]

Description:	Load staged data in Customer.InvoiceLine to the Customer.InvoiceLine table proper.
				

Parameters: 
		@ETLExecutionID - identifier for the ETL process instance that called this S-Proc (used for logging and data lineage)
		@vblnPerformFullExtract - Flag indicating whether a FULL or incremental extract is being performed
									(a FULL Extract includes DELETING target records not found in the stage table - normally only applicable for SCD-1 targets)
		@PackageRunID	- support for older tables - this is the equivalent identifier to @ETLExecutionID

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
14Jan2020	SKennedy		Cloned from CUstomer.Load_InvoiceLine.  This just processes the records on table Customer.Stage_InvoiceLine2.  It is called
							by Customer.Load_InvoiceLine which has the logic required to load this stage table and appropriate looping code to keep data
							volumes down (high data volumes was causing SEVERE sql errors)
24Jan2020   VBhosle			Renamed InvoiceRateClass to InvoiceLineType
29Jan2020	VBhosle			Renamed InvoiceRateClassificationKey to InvoiceLineTypeKey
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

	BEGIN TRY

	
		INSERT INTO [dbo].[dimCustSegmentPaymentBehaviour]
			([PaymentBehaviour]
			, [PaymentBehaviourDescription]
			, RecordActiveFlag
			, IsInferredMember
			, Created
			, Updated
			, ETLIsInferredMemberETLPackageRunID
			, ETLCreatedETLPackageRunID
			, ETLUpdatedETLPackageRunID)
			SELECT DISTINCT 
				S.PaymentBehaviour		AS [PaymentBehaviour]
				, S.PaymentBehaviour	AS [PaymengBehaviourDescription]
				, 'Y'					AS RecordActiveFlag
				, 1					
				, GETDATE()				AS [Created]
				, GETDATE()				AS [Updated]
				, @PackageRunID			AS [ETLIsInferredMemberETLPackageRunID]
				, @PackageRunID			AS [ETLCreatedETLPackageRunID]
				, @PackageRunID			AS [ETLUpdatedETLPackageRunID]
				FROM [Customer].[Stage_InvoiceLine2] S
				WHERE NOT EXISTS (SELECT * FROM dbo.dimCustSegmentPaymentBehaviour PB
									WHERE PB.PaymentBehaviour = S.PaymentBehaviour
									)

		INSERT INTO [dbo].[dimCustSegmentPaymentBehaviour]
			([PaymentBehaviour]
			, [PaymentBehaviourDescription]
			, RecordActiveFlag
			, IsInferredMember
			, Created
			, Updated
			, ETLIsInferredMemberETLPackageRunID
			, ETLCreatedETLPackageRunID
			, ETLUpdatedETLPackageRunID)
			SELECT DISTINCT 
				S.BasePaymentBehaviour		AS [PaymentBehaviour]
				, S.BasePaymentBehaviour	AS [PaymengBehaviourDescription]
				, 'Y'						AS RecordActiveFlag
				, 1					
				, GETDATE()					AS [Created]
				, GETDATE()					AS [Updated]
				, @PackageRunID				AS [ETLIsInferredMemberETLPackageRunID]
				, @PackageRunID				AS [ETLCreatedETLPackageRunID]
				, @PackageRunID				AS [ETLUpdatedETLPackageRunID]
				FROM [Customer].[Stage_InvoiceLine2] S
				WHERE NOT EXISTS (SELECT * FROM dbo.dimCustSegmentPaymentBehaviour PB
									WHERE PB.PaymentBehaviour = S.BasePaymentBehaviour
									)
								
		UPDATE S
			SET CustSegmentPaymentBehaviourKey = ISNULL (PB.CustSegmentPaymentBehaviourKey, -1)
			FROM [Customer].[Stage_InvoiceLine2] S
			INNER JOIN dbo.dimCustSegmentPaymentBehaviour  PB
				ON PB.PaymentBehaviour = S.PaymentBehaviour
				AND PB.RecordActiveFlag = 'Y'

		UPDATE S
			SET CustSegmentBasePaymentBehaviourKey = ISNULL (BPB.CustSegmentPaymentBehaviourKey, -1)
			FROM [Customer].[Stage_InvoiceLine2] S
			INNER JOIN dbo.dimCustSegmentPaymentBehaviour  BPB
				ON BPB.PaymentBehaviour = S.BasePaymentBehaviour
				AND BPB.RecordActiveFlag = 'Y';

		INSERT INTO [Customer].[BillCategory]
			   ([BillCategory]
			   , ETLIsInferredMember
			   ,[ETLCreatedExecutionID]
			   ,[ETLCreated]
			   ,[ETLUpdatedExecutionID]
			   ,[ETLUpdated])
				SELECT DISTINCT 
					S.[BillCategory]			AS [BillCategory]
					, 1							AS ETLIsInferredMember				
				
					, @ETLExecutionID			AS [ETLCreatedExecutionID]
					, GETDATE()					AS [ETLCreated]
					, @ETLExecutionID			AS [ETLUpdatedExecutionID]
					, GETDATE()					AS [ETLUpdated]
					FROM [Customer].[Stage_InvoiceLine2] S
					WHERE NOT EXISTS (SELECT * FROM [Customer].[BillCategory] BC
										WHERE BC.[BillCategory] = S.[BillCategory]
										);

	--	SELECT @@ROWCOUNT AS 'Inferred [Customer].[BillCategory] added', getdate();

		UPDATE S
			SET BillCategoryKey = ISNULL (BC.BillCategoryKey, -1)
			FROM [Customer].[Stage_InvoiceLine2] S
			INNER JOIN Customer.BillCategory BC
				ON  BC.BillCategory = S.BillCategory 


		INSERT INTO [Customer].[Product]
			([ProductCategory]
			,[ProductType]
			,[ProductSubType]
			,[ETLIsInferredMember]
			,[ETLSource]
			,[ETLSourceUpdated]
			,[ETLCreatedExecutionID]
			,[ETLCreated]
			,[ETLUpdatedExecutionID]
			,[ETLUpdated])
			SELECT DISTINCT
				S.ProductCategory
				, S.ProductType
				, S.ProductSubType
				, 1							AS ETLIsInferredMember
				, MAX (S.ETLSource)				AS ETLSource
				, MAX (S.ETLSourceUpdated)	AS ETLSourceUpdated
				, @ETLExecutionID			AS [ETLCreatedExecutionID]
				, GETDATE()					AS [ETLCreated]
				, @ETLExecutionID			AS [ETLUpdatedExecutionID]
				, GETDATE()					AS [ETLUpdated]
				FROM [Customer].[Stage_InvoiceLine2] S
				WHERE NOT EXISTS (SELECT * FROM [Customer].[Product] P
										WHERE P.[ProductCategory]	= S.[ProductCategory]
										AND P.[ProductType]			= S.[ProductType]
										AND P.[ProductSubType]		= S.[ProductSubType]
										)
				GROUP BY S.ProductCategory
					, S.ProductType
					, S.ProductSubType
				;

		SELECT @@ROWCOUNT AS 'Inferred Customer.Product added', getdate();

		UPDATE S
			SET ProductKey = ISNULL (P.ProductKey, -1)
			FROM [Customer].[Stage_InvoiceLine2] S
			INNER JOIN Customer.Product p
				ON  P.[ProductCategory]		= S.[ProductCategory]
				AND P.[ProductType]			= S.[ProductType]
				AND P.[ProductSubType]		= S.[ProductSubType]
				;

		SELECT  GETDATE() AS 'ProductKey completed'	;

		INSERT INTO [Customer].[InvoiceLineType]
			( [InvoiceLineTypeCode]
			, [InvoiceLineType]
			, [InvoiceLineGroup]
			, ETLIsInferredMember
			, [ETLSourceUpdated]
			, [ETLCreatedExecutionID]
			, [ETLCreated]
			, [ETLUpdatedExecutionID]
			, [ETLUpdated])
			SELECT DISTINCT
				S.InvoiceLineTypeCode
				, 'Unknown'					AS InvoiceLineType
				, 'Unknown'					AS InvoiceLineGroup
				, 1							AS ETLIsInferredMember
				
				, MAX (S.ETLSourceUpdated) AS ETLSourceUpdated
				, @ETLExecutionID			AS [ETLCreatedExecutionID]
				, GETDATE()					AS [ETLCreated]
				, @ETLExecutionID			AS [ETLUpdatedExecutionID]
				, GETDATE()					AS [ETLUpdated]
				FROM Customer.Stage_InvoiceLine2 S
				WHERE NOT EXISTS (SELECT InvoiceLineTypeCode FROM Customer.InvoiceLineType IRC
										WHERE IRC.InvoiceLineTypeCode = S.InvoiceLineTypeCode
												)
				GROUP BY S.InvoiceLineTypeCode

	--	SELECT @@ROWCOUNT AS 'Inferred Customer.InvoiceLineType added', getdate();

		UPDATE S
			SET InvoiceLineTypeKey = ISNULL (IRC.InvoiceLineTypeKey, -1)
			FROM [Customer].[Stage_InvoiceLine2] S
			INNER JOIN Customer.InvoiceLineType IRC
				ON  IRC.InvoiceLineTypeCode = S.InvoiceLineTypeCode
				
				;

	--	SELECT  GETDATE() AS 'InvoiceLineTypeKey completed'	;
				
		INSERT INTO [Customer].WaterUseCategory
			( WaterUseCategory
			, ETLIsInferredMember
			, [ETLCreatedExecutionID]
			, [ETLCreated]
			, [ETLUpdatedExecutionID]
			, [ETLUpdated])
			SELECT DISTINCT
				S.WaterUseCategory
				, 1							AS ETLIsInferredMember
				
				, @ETLExecutionID			AS [ETLCreatedExecutionID]
				, GETDATE()					AS [ETLCreated]
				, @ETLExecutionID			AS [ETLUpdatedExecutionID]
				, GETDATE()					AS [ETLUpdated]
				FROM Customer.Stage_InvoiceLine2 S
				WHERE NOT EXISTS (SELECT * FROM Customer.WaterUseCategory WC
										WHERE WC.WaterUseCategory = S.WaterUseCategory)
				
	--	SELECT @@ROWCOUNT AS 'Inferred Customer.WaterUseCategory added';
				

		UPDATE S
			SET WaterUseCategoryKey = ISNULL (WUC.WaterUseCategoryKey, -1)
			FROM [Customer].[Stage_InvoiceLine2] S
			INNER JOIN Customer.WaterUseCategory WUC
				ON  WUC.WaterUseCategory = S.WaterUseCategory
				;

	--	SELECT  GETDATE() AS 'WaterUseCategoryKey completed'	;

		INSERT INTO [dbo].[dimCustSegmentBillSize]
			([BillSizeDisplayOrder]
			,[BillSize]
			,[BillSizeDescription]
		
			,[RecordActiveFlag]
			,[IsInferredMember]
			,[Created]
			,[Updated]
			,[ETLIsInferredMemberETLPackageRunID]
			,[ETLCreatedETLPackageRunID]
			,[ETLUpdatedETLPackageRunID])
			SELECT DISTINCT
				90				AS BillSizeDisplayOrder
				, S.BillSize
				, S.BillSize	AS BillSizeDescription
           
				, 'Y'			AS RecordActiveFlag
				, 1				AS IsInferredMember
				, GETDATE()		AS Created
				, GETDATE()		AS Updated
				, @PackageRunID	AS ETLIsInferredMemberETLPackageRunID
				, @PackageRunID	AS ETLCreatedETLPackageRunID
				, @PackageRunID	AS ETLUpdatedETLPackageRunID
				FROM [Customer].[Stage_InvoiceLine2] S
				WHERE S.BillSize IS NOT NULL
				AND S.BillSize NOT IN (SELECT BS.BillSize FROM [dbo].[dimCustSegmentBillSize] BS)

	--	SELECT @@ROWCOUNT AS 'Inferred [dbo].[dimCustSegmentBillSize] added', GETDATE()

		UPDATE S
			SET CustSegmentBillSizeKey = ISNULL (BS.CustSegmentBillSizeKey, -1)
			FROM [Customer].[Stage_InvoiceLine2] S
			INNER JOIN dbo.dimCustSegmentBillSize BS
				ON  BS.BillSize = S.BillSize 

	--	SELECT  GETDATE() AS 'CustSegmentBillSizeKey completed'	;

		INSERT INTO [Customer].[dimProperty]
			( [FinancialAccountNumber]
			, [ExternalAccountNumber]
			, [ETLIsActive]
			, [ETLIsInferred]
			, [ETLCreatedETLPackageRunID]
			, [ETLCreated]
			, [ETLChangedETLPackageRunID]
			, [ETLChanged])
			SELECT DISTINCT 
				S.FinancialAccountNum
				, S.ExternalAccountNumber
				, 'Y'			AS ETLIsActive
				, 1				AS ETLIsInferred
				, -1			AS ETLCreatedETLPackageRunID
				, GETDATE()		AS ETLCreated
				, -1			AS ETLChangedETLPackageRunID
				, GETDATE()		AS ETLChanged
				FROM [Customer].[Stage_InvoiceLine2] S 
				WHERE NOT EXISTS (SELECT * FROM Customer.dimProperty P
									WHERE P.FinancialAccountNumber = S.FinancialAccountNum 
									AND P.ExternalAccountNumber = S.ExternalAccountNumber
								)
								;
		--SELECT @@ROWCOUNT AS 'Inferred dimProperty Added', GETDATE() AS 'dimPropertyKey completed'

		UPDATE S
			SET dimPropertyKey = ISNULL (P.dimPropertyKey, -1)
			FROM [Customer].[Stage_InvoiceLine2] S
			INNER JOIN Customer.dimProperty P
				ON P.FinancialAccountNumber = S.FinancialAccountNum 
				AND P.ExternalAccountNumber = S.ExternalAccountNumber
				;
			
		--SELECT GETDATE() AS 'dimPropertyKey completed'

		UPDATE S
			SET dimPropertyActiveKey = ISNULL (PA.dimPropertyActiveKey, -1)
			FROM [Customer].[Stage_InvoiceLine2] S
			INNER JOIN Customer.dimPropertyActive PA
				ON  PA.PropertyActive = S.PropertyActive 
			
		--SELECT GETDATE() AS 'dimPropertyActiveKey completed'


----------------===================================


-------------========================================
		UPDATE S
			SET	MosaicVersion2018CustSegmentSAWaterSegmentKey			= ISNULL (SAWS2018.CustSegmentSAWaterSegmentKey, -1)

			FROM Customer.[Stage_InvoiceLine2] S 
			INNER JOIN dbo.dimCustSegmentMosaicSegment MS2018
				ON MS2018.MosaicTypeCode = S.MosaicType2018
				AND MS2018.MosaicVersion = 2018
			INNER JOIN dbo.dimCustSegmentSAWaterSegment SAWS2018
				ON SAWS2018.SAWaterSegment = CASE WHEN S.BillSize IN ( 'High')  AND MS2018.BillStressDefiningBehaviour = 'Stressed' 									THEN 'Overstretched Households'
												WHEN S.BillSize IN ( 'High') AND  MS2018.BillStressDefiningBehaviour = 'Unstressed' 									THEN 'Comfy but Careful'
												WHEN S.BillSize IN ( 'Low')   AND  MS2018.BillStressDefiningBehaviour = 'Unstressed' AND MS2018.AgeCategory = 'Younger'	THEN 'Young and Unstressed'
												WHEN S.BillSize IN ( 'Low')   AND  MS2018.BillStressDefiningBehaviour = 'Unstressed' AND MS2018.AgeCategory = 'Older'	THEN 'Mature and Mellow'
												WHEN S.BillSize IN ( 'Low')   AND  MS2018.BillStressDefiningBehaviour = 'Stressed'										THEN 'Struggling Households'
												ELSE 'Unknown' END

		--SELECT GETDATE() AS 'MosaicVersion2018CustSegmentSAWaterSegmentKey completed'

-------------========================================
	UPDATE S
		SET	MosaicVersion2018OwnerCustSegmentSAWaterSegmentKey	= ISNULL (OSAWS2018.CustSegmentSAWaterSegmentKey, -1)

		FROM Customer.[Stage_InvoiceLine2] S 
		INNER JOIN dbo.dimCustSegmentMosaicSegment OMS2018
			ON OMS2018.MosaicTypeCode = S.MosaicType2018Owner
			AND OMS2018.MosaicVersion = 2018
		INNER JOIN dbo.dimCustSegmentSAWaterSegment OSAWS2018
			ON OSAWS2018.SAWaterSegment = CASE WHEN S.BillSize IN ( 'High') AND OMS2018.BillStressDefiningBehaviour = 'Stressed'									THEN 'Overstretched Households'
											WHEN S.BillSize IN ('High') AND OMS2018.BillStressDefiningBehaviour = 'Unstressed' 									THEN 'Comfy but Careful'
											WHEN S.BillSize IN ( 'Low')   AND OMS2018.BillStressDefiningBehaviour = 'Unstressed' AND OMS2018.AgeCategory = 'Younger'	THEN 'Young and Unstressed'
											WHEN S.BillSize IN ( 'Low')   AND OMS2018.BillStressDefiningBehaviour = 'Unstressed' AND OMS2018.AgeCategory = 'Older'	THEN 'Mature and Mellow'
											WHEN S.BillSize IN ( 'Low')   AND OMS2018.BillStressDefiningBehaviour = 'Stressed'										THEN 'Struggling Households'
											ELSE 'Unknown' END
	--SELECT GETDATE() AS 'MosaicVersion2018OwnerCustSegmentSAWaterSegmentKey completed'
-------------========================================

-------------========================================
	BEGIN TRANSACTION;

		UPDATE T 
			SET
				T.[AuthorisedDateCalendarKey]							= S.[AuthorisedDateCalendarKey],
				T.[BillCategoryKey]										= S.[BillCategoryKey],
				T.[CustSegmentBasePaymentBehaviourKey]					= S.[CustSegmentBasePaymentBehaviourKey],
				T.[CustSegmentBillSizeKey]								= S.[CustSegmentBillSizeKey],
				T.[CustSegmentPaymentBehaviourKey]						= S.[CustSegmentPaymentBehaviourKey],
				T.[dimPropertyActiveKey]								= S.[dimPropertyActiveKey],
				T.[dimPropertyKey]										= S.[dimPropertyKey],
				T.[EffectiveDateCalendarKey]							= S.[EffectiveDateCalendarKey],
				T.[ETLSource]											= S.[ETLSource],
				T.[ETLSourceUpdated]									= S.[ETLSourceUpdated],
				T.InvoiceDateCalendarKey								= S.InvoiceDateCalendarKey,
				T.[InvoiceDueCalendarKey]								= S.[InvoiceDueCalendarKey],
				T.[InvoiceLineAmount]									= S.[InvoiceLineAmount],
				T.[InvoiceLineTypeKey]						            = S.[InvoiceLineTypeKey],
				T.[MosaicVersion2018CustSegmentSAWaterSegmentKey]		= S.[MosaicVersion2018CustSegmentSAWaterSegmentKey],
				T.[MosaicVersion2018OwnerCustSegmentSAWaterSegmentKey]	= S.[MosaicVersion2018OwnerCustSegmentSAWaterSegmentKey],
				T.[ProductKey]											= S.[ProductKey],
				T.[Quantity]											= S.[Quantity],
				T.[UnitPrice]											= S.[UnitPrice],
				T.[WaterUseCategoryKey]									= S.[WaterUseCategoryKey],
		
				T.ETLUpdatedExecutionID									= @ETLExecutionID,
				T.ETLUpdated											= GETDATE()
	
				FROM [Customer].[InvoiceLine] T
				INNER JOIN [Customer].[Stage_InvoiceLine2] S
					ON T.[ETLSourceKey1] = S.[ETLSourceKey1]
					AND T.[ETLSourceKey2] = S.[ETLSourceKey2]
					AND T.[ETLSourceKey3] = S.[ETLSourceKey3]
					AND T.[ETLSourceKey4] = S.[ETLSourceKey4]
				WHERE
					   ISNULL (T.[AuthorisedDateCalendarKey], 0)							<> ISNULL (S.[AuthorisedDateCalendarKey], 0)
					OR ISNULL (T.[BillCategoryKey], 0)										<> ISNULL (S.[BillCategoryKey], 0)
					OR ISNULL (T.[CustSegmentBasePaymentBehaviourKey], 0)					<> ISNULL (S.[CustSegmentBasePaymentBehaviourKey], 0)
					OR ISNULL (T.[CustSegmentBillSizeKey], 0)								<> ISNULL (S.[CustSegmentBillSizeKey], 0)
					OR ISNULL (T.[CustSegmentPaymentBehaviourKey], 0)						<> ISNULL (S.[CustSegmentPaymentBehaviourKey], 0)
					OR ISNULL (T.[dimPropertyActiveKey], 0)									<> ISNULL (S.[dimPropertyActiveKey], 0)
					OR ISNULL (T.[dimPropertyKey], 0)										<> ISNULL (S.[dimPropertyKey], 0)
					OR ISNULL (T.[EffectiveDateCalendarKey], 0)								<> ISNULL (S.[EffectiveDateCalendarKey], 0)
					OR ISNULL (T.[ETLSource], '')											<> ISNULL (S.[ETLSource], '')
					OR ISNULL (T.[ETLSourceUpdated], '1 Jan 1800')							<> ISNULL (S.[ETLSourceUpdated], '1 Jan 1800')
					OR ISNULL (T.[InvoiceDateCalendarKey], 0)								<> ISNULL (S.[InvoiceDateCalendarKey], 0)
					OR ISNULL (T.[InvoiceDueCalendarKey], 0)								<> ISNULL (S.[InvoiceDueCalendarKey], 0)
					OR ISNULL (T.[InvoiceLineAmount], 0)									<> ISNULL (S.[InvoiceLineAmount], 0)
					OR ISNULL (T.[InvoiceLineTypeKey], 0)							        <> ISNULL (S.[InvoiceLineTypeKey], 0)
					OR ISNULL (T.[MosaicVersion2018CustSegmentSAWaterSegmentKey], 0)		<> ISNULL (S.[MosaicVersion2018CustSegmentSAWaterSegmentKey], 0)
					OR ISNULL (T.[MosaicVersion2018OwnerCustSegmentSAWaterSegmentKey], 0)	<> ISNULL (S.[MosaicVersion2018OwnerCustSegmentSAWaterSegmentKey], 0)
					OR ISNULL (T.[ProductKey], 0)											<> ISNULL (S.[ProductKey], 0)
					OR ISNULL (T.[Quantity], 0)												<> ISNULL (S.[Quantity], 0)
					OR ISNULL (T.[UnitPrice], 0)											<> ISNULL (S.[UnitPrice], 0)
					OR ISNULL (T.[WaterUseCategoryKey], 0)									<> ISNULL (S.[WaterUseCategoryKey], 0)

		SELECT @@ROWCOUNT AS '[Customer].[InvoiceLine] RowsUpdated', GETDATE();

		INSERT INTO [Customer].[InvoiceLine]
			(
			  [AuthorisedDateCalendarKey]
			, [BillCategoryKey]
			, [CustSegmentBasePaymentBehaviourKey]
			, [CustSegmentBillSizeKey]
			, [CustSegmentPaymentBehaviourKey]
			, [dimPropertyActiveKey]
			, [dimPropertyKey]
			, [EffectiveDateCalendarKey]
			, [ETLSource]
			, [ETLSourceKey1]
			, [ETLSourceKey2]
			, [ETLSourceKey3]
			, [ETLSourceKey4]
			, [ETLSourceUpdated]
			, [InvoiceDateCalendarKey]
			, [InvoiceDueCalendarKey]
			, [InvoiceLineAmount]
			, [InvoiceLineTypeKey]
			, [MosaicVersion2018CustSegmentSAWaterSegmentKey]
			, [MosaicVersion2018OwnerCustSegmentSAWaterSegmentKey]
			, [ProductKey]
			, [Quantity]
			, [UnitPrice]
			, [WaterUseCategoryKey]
		
			, ETLCreated
			, ETLCreatedExecutionID
			, ETLUpdated
			, ETLUpdatedExecutionID
			)
			SELECT 
				  S.[AuthorisedDateCalendarKey]
				, S.[BillCategoryKey]
				, S.[CustSegmentBasePaymentBehaviourKey]
				, S.[CustSegmentBillSizeKey]
				, S.[CustSegmentPaymentBehaviourKey]
				, S.[dimPropertyActiveKey]
				, S.[dimPropertyKey]
				, S.[EffectiveDateCalendarKey]
				, S.[ETLSource]
				, S.[ETLSourceKey1]
				, S.[ETLSourceKey2]
				, S.[ETLSourceKey3]
				, S.[ETLSourceKey4]
				, S.[ETLSourceUpdated]
				, S.[InvoiceDateCalendarKey]
				, S.[InvoiceDueCalendarKey]
				, S.[InvoiceLineAmount]
				, S.[InvoiceLineTypeKey]
				, S.[MosaicVersion2018CustSegmentSAWaterSegmentKey]
				, S.[MosaicVersion2018OwnerCustSegmentSAWaterSegmentKey]
				, S.[ProductKey]
				, S.[Quantity]
				, S.[UnitPrice]
				, S.[WaterUseCategoryKey]
				, GETDATE()					AS ETLCreated
				, @ETLExecutionID			AS ETLCreatedExecutionID
				, GETDATE()					AS ETLUpdated
				, @ETLExecutionID			AS ETLUpdatedExecutionID
				FROM Customer.Stage_InvoiceLine2 S
				WHERE NOT EXISTS (SELECT * FROM Customer.InvoiceLine T 
									WHERE T.[ETLSourceKey1] = S.[ETLSourceKey1]
									AND T.[ETLSourceKey2] = S.[ETLSourceKey2]
									AND T.[ETLSourceKey3] = S.[ETLSourceKey3]
									AND T.[ETLSourceKey4] = S.[ETLSourceKey4]
									);

		SELECT @@ROWCOUNT AS '[Customer].[InvoiceLine] RowsInserted', GETDATE();

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
