/****** Object:  StoredProcedure [CSIS].[Enable_InvoiceLineIndexes]    Script Date: 3/02/2020 4:08:28 PM ******/
DROP PROCEDURE IF EXISTS [CSIS].[Enable_InvoiceLineIndexes]
GO
/****** Object:  StoredProcedure [CSIS].[Enable_InvoiceLineIndexes]    Script Date: 3/02/2020 4:08:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [CSIS].[Enable_InvoiceLineIndexes] As
/***************************************************************************************************************************************************
Name: CSIS.Enable_InvoiceLineIndexes

Description: ENable selected indexes on table CSIS.InvoiceLine
			Indexes are disabled during the load of CSIS.InvoiceLine to boost the performance of this process.
			These indexes are not needed for that process
			but will be useful for general query performance from reportings tools.
	
Parameters: n/a

Modification History:
-----------------------------------------------------------------------------------------------------------------------------------------------------
Date		Name			Modification
-----------------------------------------------------------------------------------------------------------------------------------------------------
29Jan2020	S Kennedy		Initial Version
****************************************************************************************************************************************************/
DECLARE @IndexName	NVARCHAR (128)
	, @SchemaName	NVARCHAR (128)
	, @TableName	NVARCHAR (128)
	, @SQL			NVARCHAR (2000)
	;
DECLARE IndexList CURSOR FOR
	SELECT Object_Schema_Name (I.object_id) , Object_Name (I.object_id) , I.Name
		FROM sys.indexes I
		WHERE Object_Schema_Name (I.object_id) = 'CSIS'
		AND Object_Name (I.object_id) = 'InvoiceLine'
		and I.is_unique = 0
		and I.is_disabled = 1;

OPEN IndexList;

FETCH NEXT FROM IndexList
	INTO @SchemaName, @TableName, @IndexName;

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @SQL = '
IF EXISTS (SELECT * FROM sys.indexes I where I.name = ''' + @IndexName + ''' 
			AND OBJECT_Schema_NAME (I.Object_ID) = ''' + @SchemaName + '''
			AND OBJECT_NAME (I.Object_ID) = ''' + @TableName + '''
			and I.is_unique = 0
			and I.is_disabled = 1 )
BEGIN 
	alter index   [' + @IndexName + '] on  [' + @SchemaName + '].[' + @TableName + ']  rebuild;
 
END'
	EXEC sp_executesql @SQL
	--PRINT @SQL
	FETCH NEXT FROM IndexList
		INTO @SchemaName, @TableName, @IndexName;
END
CLOSE IndexList
DEALLOCATE IndexList
GO
