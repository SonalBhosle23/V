USE [EDW]
GO
/****** Object:  StoredProcedure [Customer].[Disable_InvoiceLineIndexes]    Script Date: 21/02/2020 12:14:49 PM ******/
DROP PROCEDURE IF EXISTS [Customer].[Disable_InvoiceLineIndexes]
GO
/****** Object:  StoredProcedure [Customer].[Disable_InvoiceLineIndexes]    Script Date: 21/02/2020 12:14:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [Customer].[Disable_InvoiceLineIndexes] As
/***************************************************************************************************************************************************
Name: Customer.Disable_InvoiceLineIndexes

Description: Disable selected indexes on table Customer.InvoiceLine
			Indexes are disabled during the load of Customer.InvoiceLine to boost the performance of this process.
			These indexes are not needed for that process
			but will be useful for general query performance from reportings tools.
	
Parameters: n/a

Modification History:
-----------------------------------------------------------------------------------------------------------------------------------------------------
Date		Name			Modification
-----------------------------------------------------------------------------------------------------------------------------------------------------
22Jan2020	S Kennedy		Initial Version
12Feb2020	S Kennedy		Added addition indexes 
****************************************************************************************************************************************************/

IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_BillCategory' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_BillCategory on  Customer.InvoiceLine disable 
END

IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_dimCalendar_InvoiceCreated' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_dimCalendar_InvoiceCreated on  Customer.InvoiceLine disable 
END
 
IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_dimCustSegmentPaymentBehaviour' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_dimCustSegmentPaymentBehaviour on  Customer.InvoiceLine disable 
END
  
IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_dimCustSegmentPaymentBehaviour' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_dimCustSegmentPaymentBehaviour on  Customer.InvoiceLine disable 
END  

IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_dimCustSegmentSAWaterSegment_2018' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_dimCustSegmentSAWaterSegment_2018 on  Customer.InvoiceLine disable 
END
 
IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_dimCustSegmentSAWaterSegment_2018Owner' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_dimCustSegmentSAWaterSegment_2018Owner on  Customer.InvoiceLine disable 
END
 
IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_dimProperty' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_dimProperty on  Customer.InvoiceLine disable 
END
 
IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_InvoiceLineType' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_InvoiceLineType on  Customer.InvoiceLine disable 
END
 
IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_InvoiceRateClass' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_InvoiceRateClass on  Customer.InvoiceLine disable 
END
 
IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_Product' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_Product on  Customer.InvoiceLine disable 
END

IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_WaterUseCategory' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_WaterUseCategory on  Customer.InvoiceLine disable 
END



IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_dimCalendar_InvoiceDue' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_dimCalendar_InvoiceDue on  Customer.InvoiceLine disable 
END


IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_dimCalendar_InvoiceIssued' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_dimCalendar_InvoiceIssued on  Customer.InvoiceLine disable 
END


IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_dimCustSegmentBillSize' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_dimCustSegmentBillSize on  Customer.InvoiceLine disable 
END


IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_dimCustSegmentPaymentBehaviour_Base' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_dimCustSegmentPaymentBehaviour_Base on  Customer.InvoiceLine disable 
END



IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_dimPropertyActive' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_dimPropertyActive on  Customer.InvoiceLine disable 
END




IF EXISTS (SELECT * FROM sys.indexes where name = 'IX_InvoiceLine_dimPropertyKey' 
			AND OBJECT_Schema_NAME (Object_ID) = 'Customer' 
			AND OBJECT_NAME (Object_ID) = 'InvoiceLine' )
BEGIN 
	alter index   IX_InvoiceLine_dimPropertyKey on  Customer.InvoiceLine disable 
END


GO
