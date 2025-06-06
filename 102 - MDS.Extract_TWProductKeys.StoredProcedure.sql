/****** Object:  StoredProcedure [MDS].[Extract_TWProductKeys]    Script Date: 3/02/2020 5:25:18 PM ******/
DROP PROCEDURE IF EXISTS [MDS].[Extract_TWProductKeys]
GO
/****** Object:  StoredProcedure [MDS].[Extract_TWProductKeys]    Script Date: 3/02/2020 5:25:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO











CREATE PROCEDURE [MDS].[Extract_TWProductKeys]
	
	AS
/*************************************************************************************************************************************************
Description: [MDS].[Extract_TWProductKeys] from [MDS].[CSTWProduct] 
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
SET NOCOUNT ON;


select Distinct 
				
				isnull (P.ProductCategory ,'') as [ProductCategory],
				isnull (P.ProductType ,'') as [ProductType],
				isnull (P.ProductSubType ,'') as [ProductSubType]

				
								
	from [MDS].[CSTWProduct] P







GO
