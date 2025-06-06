/****** Object:  StoredProcedure [MDS].[Extract_CSISProductKeys]    Script Date: 3/02/2020 5:25:18 PM ******/
DROP PROCEDURE IF EXISTS [MDS].[Extract_CSISProductKeys]
GO
/****** Object:  StoredProcedure [MDS].[Extract_CSISProductKeys]    Script Date: 3/02/2020 5:25:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO












CREATE PROCEDURE [MDS].[Extract_CSISProductKeys]
	
	AS
/*************************************************************************************************************************************************
Description: [MDS].[Extract_ProductKeys] from [MDS].[CSProduct] 
			Data is extracted from  MDS Schema.

Author:           V Bhosle
Creation Date:    11 Nov 2019


Change Log
=================================================================================================================================================
Date		Author		Description
=================================================================================================================================================
11 Nov 2019 VBhosle 	Initial version
10 Dec 2019 VBhosle     Removed the extra space when NULL calls.
06 Jan 2020 VBhosle     Changed the table name from CSProduct to CSCSISProduct 
08 Jan 2020 VBhosle		Renamed Extract_ProductKeys to Extract_CSISProductKeys
=================================================================================================================================================
*************************************************************************************************************************************************/
SET NOCOUNT ON;


select Distinct 
				
				isnull (P.ProductCategory ,'') as [ProductCategory],
				isnull (P.ProductType ,'') as [ProductType],
				isnull (P.ProductSubType ,'') as [ProductSubType]

				
								
	from [MDS].[CSCSISProduct] P







GO
