/****** Object:  StoredProcedure [MDS].[DeleteSync_CSTWProduct]    Script Date: 3/02/2020 5:25:18 PM ******/
DROP PROCEDURE IF EXISTS [MDS].[DeleteSync_CSTWProduct]
GO
/****** Object:  StoredProcedure [MDS].[DeleteSync_CSTWProduct]    Script Date: 3/02/2020 5:25:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/***************************************************************************************************************************************************
Name: [MDS].[DeleteSync_CSTWProduct]

Description: Perform delete sync between [MDS].[Stage_CSTWProduct] to the [MDS].[CSTWProduct] table proper.
	Delete Type: Hard

	NOTE: You must do a FULL load of the SOURCE keys to the Stage table in order for this to operate properly.

UNMODIFIED AUTO-GEN (remove this line if code has been customised since it was generated to protect your changes from accidental over-write)

EXEC ETL28GenerateDeleteSyncTSQL
	 @vstrSchemaName='MDS', 
	 @vstrEntityNamePattern='CSTWProduct', 
	 @vstrStageTableSchema='MDS', 
	 @vstrStageTablePrefix='Stage_', 
	 @vstrAuthor='VBhosle',
	 @vstrTargetSchema='MDS';

The following tables are (potentially) updated by this procedure:
	 - [MDS].[Stage_CSTWProduct]
	 - [MDS].[CSTWProduct]

Parameters: 

Modification History:
-----------------------------------------------------------------------------------------------------------------------------------------------------
Version	Date		Name				Modification
-----------------------------------------------------------------------------------------------------------------------------------------------------
1.0		06Jan2020	VBhosle		Initial Version (auto-generated via ETL28GenerateDeleteSyncTSQL)
****************************************************************************************************************************************************/
CREATE PROCEDURE [MDS].[DeleteSync_CSTWProduct] AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@intRowCount int, 
		@ErrorNumber int = 0,
		@ErrorSeverity int,  
		@ErrorState int,
		@ErrorProcedure varchar(128),
		@ErrorLine int,
		@ErrorMessage nvarchar(2000),
		@ErrorString nvarchar(3000);
		
	--=================================================================================================
	-- Check there are records in the staging table to compare
	--=================================================================================================
	SELECT @intRowCount = COUNT(1) FROM [MDS].[Stage_CSTWProduct];

	--=================================================================================================
	-- Do the delete (either soft or hard depending on the table type)
	--=================================================================================================
	IF @intRowCount > 0
	BEGIN
		BEGIN TRANSACTION;

		BEGIN TRY

			DELETE [MDS].[CSTWProduct]
			FROM [MDS].[CSTWProduct] AS T
			WHERE NOT EXISTS(
				SELECT 1
				FROM [MDS].[Stage_CSTWProduct] AS S
				WHERE T.[PermitType] = S.[PermitType]
			);

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
			;

			SET @ErrorString = @ErrorMessage + ' at line ' + CONVERT (NVARCHAR, @ErrorLine) + ' in ' + @ErrorProcedure;
			
			RAISERROR (@ErrorString,  @ErrorSeverity, 1);
		END CATCH
	END
	
	RETURN (@ErrorNumber);
END
GO
