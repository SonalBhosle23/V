/****** Object:  StoredProcedure [MDS].[Extract_TWProduct]    Script Date: 3/02/2020 5:25:18 PM ******/
DROP PROCEDURE IF EXISTS [MDS].[Extract_TWProduct]
GO
/****** Object:  StoredProcedure [MDS].[Extract_TWProduct]    Script Date: 3/02/2020 5:25:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO














/*************************************************************************************************************************************************
Description: [MDS].[Extract_TWProduct] from [MDS].[CSTWProduct] 
			Data is extracted from  MDS Schema.

Author:           V Bhosle
Creation Date:    03 Jan 2020


Change Log
=================================================================================================================================================
Date		Author		Description
=================================================================================================================================================
03 Jan 2020 VBhosle 	Initial version

=================================================================================================================================================
*************************************************************************************************************************************************/
CREATE PROCEDURE [MDS].[Extract_TWProduct]
	
	
	@ETLUpdated datetime2(7)
	AS
SET NOCOUNT ON;


select Distinct 
				
				
				isnull (P.ProductCategory ,'') as [ProductCategory],
				isnull (P.ProductType ,'') as [ProductType],
				isnull (P.ProductSubType ,'') as [ProductSubType],
				'MDS.CSTWProduct'as ETLSource,
				max(ETLUpdated) as ETLSourceUpdated

				
								
	from [MDS].[CSTWProduct] P
	where ETLUpdated > @ETLUpdated
	group by 
				
				isnull (P.ProductCategory ,''),
				isnull (P.ProductType ,'') ,
				isnull (P.ProductSubType ,'')
			











GO
