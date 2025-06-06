/****** Object:  StoredProcedure [MDS].[Load_CSANZSICWaterCriticality]    Script Date: 3/02/2020 5:25:18 PM ******/
DROP PROCEDURE IF EXISTS [MDS].[Load_CSANZSICWaterCriticality]
GO
/****** Object:  StoredProcedure [MDS].[Load_CSANZSICWaterCriticality]    Script Date: 3/02/2020 5:25:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/***************************************************************************************************************************************************
Name:		[MDS].[Load_CSANZSICWaterCriticality]

Description:	Load staged data in MDS.CSANZSICWaterCriticality to the MDS.CSANZSICWaterCriticality table proper.
				Action Column: not specified
				Update Lineage: Yes 

UNMODIFIED AUTO-GEN (remove this line if code has been customised since it was generated to protect your changes from accidental over-write)

EXEC ETL28GenerateLoadTSQL
	 @vstrSchemaName='MDS', 
	 @vstrEntityNamePattern='CSANZSICWaterCriticality', 
	 @vstrStageTableSchema='MDS', 
	 @vstrStageTablePrefix='Stage_', 
	 @vblnUseETLColumnsFlag=1, 
	 @vstrActionColumnName=NULL,
	 @vblnIsSCD2=0, 
	 @vstrAuthor='VBhosle',
	 @vstrTargetSchema='MDS';

The following tables are (potentially) updated by this procedure:
	 - [MDS].[Stage_CSANZSICWaterCriticality]
	 - [MDS].[CSANZSICWaterCriticality]

Parameters: 
		@ETLExecutionID - identifier for the ETL process instance that called this S-Proc (used for logging and data lineage)
		@vblnPerformFullExtract - Flag indicating whether a FULL or incremental extract is being performed
									(a FULL Extract includes DELETING target records not found in the stage table - normally only applicable for SCD-1 targets)

Modification History:
-----------------------------------------------------------------------------------------------------------------------------------------------------
Version	Date		Name				Modification
-----------------------------------------------------------------------------------------------------------------------------------------------------
1.0		09Jan2020	VBhosle		Initial Version (auto-generated via ETL28GenerateLoadTSQL)
****************************************************************************************************************************************************/
CREATE PROCEDURE [MDS].[Load_CSANZSICWaterCriticality] (@ETLExecutionID uniqueidentifier, @vblnPerformFullExtract bit = 0) AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ErrorNumber int,
		@ErrorSeverity int,  
		@ErrorState int,
		@ErrorProcedure varchar(128),
		@ErrorLine int,
		@ErrorMessage nvarchar(2000),
		@ErrorString nvarchar(3000);

	BEGIN TRANSACTION;

	BEGIN TRY
		--=================================================================================================
		-- Handle DELETE(s) first
		--=================================================================================================
		MERGE [MDS].[CSANZSICWaterCriticality] as T
		USING [MDS].[Stage_CSANZSICWaterCriticality] as S
			ON T.[IndustryClassCode] = S.[IndustryClassCode]
		WHEN NOT MATCHED BY SOURCE AND @vblnPerformFullExtract = 1 THEN DELETE;

		--=================================================================================================
		-- Handle INSERT-UPDATE with a single MERGE (Incremental & Full-Extract handled the same)
		--=================================================================================================
		MERGE [MDS].[CSANZSICWaterCriticality] as T
		USING [MDS].[Stage_CSANZSICWaterCriticality] as S
			ON T.[IndustryClassCode] = S.[IndustryClassCode]

		WHEN NOT MATCHED BY TARGET THEN
		INSERT (
			[IndustryClass]
			,[IndustryClassCode]
			,[DivisionCode]
			,[Division]
			,[Subdivision Code]
			,[Subdivision]
			,[IndustryGroupCode]
			,[IndustryGroup]
			,[WaterCriticality]
			,[LastChgDateTime]
			,[ETLCreated]
			,[ETLCreatedExecutionID]
			,[ETLUpdated]
			,[ETLUpdatedExecutionID]
		)
		VALUES (
			S.[IndustryClass]
			,S.[IndustryClassCode]
			,S.[DivisionCode]
			,S.[Division]
			,S.[Subdivision Code]
			,S.[Subdivision]
			,S.[IndustryGroupCode]
			,S.[IndustryGroup]
			,S.[WaterCriticality]
			,S.[LastChgDateTime]
			,SYSDATETIME()
			,@ETLExecutionID
			,SYSDATETIME()
			,@ETLExecutionID
		)
	
		WHEN MATCHED
			AND NOT EXISTS (
				SELECT
					T.[IndustryClass],T.[IndustryClassCode],T.[DivisionCode],T.[Division],T.[Subdivision Code],T.[Subdivision],T.[IndustryGroupCode],T.[IndustryGroup],T.[WaterCriticality],T.[LastChgDateTime]
				INTERSECT
				SELECT
					S.[IndustryClass],S.[IndustryClassCode],S.[DivisionCode],S.[Division],S.[Subdivision Code],S.[Subdivision],S.[IndustryGroupCode],S.[IndustryGroup],S.[WaterCriticality],S.[LastChgDateTime]
			) THEN	-- i.e. at least one source payload column value does not match target (intersect also handles "<null> comparisons")

			UPDATE SET 
				T.[IndustryClass] = S.[IndustryClass]
				,T.[IndustryClassCode] = S.[IndustryClassCode]
				,T.[DivisionCode] = S.[DivisionCode]
				,T.[Division] = S.[Division]
				,T.[Subdivision Code] = S.[Subdivision Code]
				,T.[Subdivision] = S.[Subdivision]
				,T.[IndustryGroupCode] = S.[IndustryGroupCode]
				,T.[IndustryGroup] = S.[IndustryGroup]
				,T.[WaterCriticality] = S.[WaterCriticality]
				,T.[LastChgDateTime] = S.[LastChgDateTime]
				,T.[ETLUpdated] = SYSDATETIME()
				,T.[ETLUpdatedExecutionID] = @ETLExecutionID;

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
	
	RETURN (@ErrorNumber);
END
GO
