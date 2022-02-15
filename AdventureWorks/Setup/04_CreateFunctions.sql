-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Convert TSQL Functions to Spark SQL
-- MAGIC 
-- MAGIC 
-- MAGIC 
-- MAGIC Here are the sample functions. 
-- MAGIC 
-- MAGIC ```sql
-- MAGIC 
-- MAGIC CREATE FUNCTION [dbo].[ufnGetAccountingStartDate]()
-- MAGIC RETURNS [datetime] 
-- MAGIC AS 
-- MAGIC BEGIN
-- MAGIC     RETURN CONVERT(datetime, '20030701', 112);
-- MAGIC END;
-- MAGIC GO
-- MAGIC 
-- MAGIC CREATE FUNCTION [dbo].[ufnGetAccountingEndDate]()
-- MAGIC RETURNS [datetime] 
-- MAGIC AS 
-- MAGIC BEGIN
-- MAGIC     RETURN DATEADD(millisecond, -2, CONVERT(datetime, '20040701', 112));
-- MAGIC END;
-- MAGIC GO
-- MAGIC 
-- MAGIC CREATE FUNCTION [dbo].[ufnGetContactInformation](@PersonID int)
-- MAGIC RETURNS @retContactInformation TABLE 
-- MAGIC (
-- MAGIC     -- Columns returned by the function
-- MAGIC     [PersonID] int NOT NULL, 
-- MAGIC     [FirstName] [nvarchar](50) NULL, 
-- MAGIC     [LastName] [nvarchar](50) NULL, 
-- MAGIC 	[JobTitle] [nvarchar](50) NULL,
-- MAGIC     [BusinessEntityType] [nvarchar](50) NULL
-- MAGIC )
-- MAGIC AS 
-- MAGIC -- Returns the first name, last name, job title and business entity type for the specified contact.
-- MAGIC -- Since a contact can serve multiple roles, more than one row may be returned.
-- MAGIC BEGIN
-- MAGIC 	IF @PersonID IS NOT NULL 
-- MAGIC 		BEGIN
-- MAGIC 		IF EXISTS(SELECT * FROM [HumanResources].[Employee] e 
-- MAGIC 					WHERE e.[BusinessEntityID] = @PersonID) 
-- MAGIC 			INSERT INTO @retContactInformation
-- MAGIC 				SELECT @PersonID, p.FirstName, p.LastName, e.[JobTitle], 'Employee'
-- MAGIC 				FROM [HumanResources].[Employee] AS e
-- MAGIC 					INNER JOIN [Person].[Person] p
-- MAGIC 					ON p.[BusinessEntityID] = e.[BusinessEntityID]
-- MAGIC 				WHERE e.[BusinessEntityID] = @PersonID;
-- MAGIC 
-- MAGIC 		IF EXISTS(SELECT * FROM [Purchasing].[Vendor] AS v
-- MAGIC 					INNER JOIN [Person].[BusinessEntityContact] bec 
-- MAGIC 					ON bec.[BusinessEntityID] = v.[BusinessEntityID]
-- MAGIC 					WHERE bec.[PersonID] = @PersonID)
-- MAGIC 			INSERT INTO @retContactInformation
-- MAGIC 				SELECT @PersonID, p.FirstName, p.LastName, ct.[Name], 'Vendor Contact' 
-- MAGIC 				FROM [Purchasing].[Vendor] AS v
-- MAGIC 					INNER JOIN [Person].[BusinessEntityContact] bec 
-- MAGIC 					ON bec.[BusinessEntityID] = v.[BusinessEntityID]
-- MAGIC 					INNER JOIN [Person].ContactType ct
-- MAGIC 					ON ct.[ContactTypeID] = bec.[ContactTypeID]
-- MAGIC 					INNER JOIN [Person].[Person] p
-- MAGIC 					ON p.[BusinessEntityID] = bec.[PersonID]
-- MAGIC 				WHERE bec.[PersonID] = @PersonID;
-- MAGIC 		
-- MAGIC 		IF EXISTS(SELECT * FROM [Sales].[Store] AS s
-- MAGIC 					INNER JOIN [Person].[BusinessEntityContact] bec 
-- MAGIC 					ON bec.[BusinessEntityID] = s.[BusinessEntityID]
-- MAGIC 					WHERE bec.[PersonID] = @PersonID)
-- MAGIC 			INSERT INTO @retContactInformation
-- MAGIC 				SELECT @PersonID, p.FirstName, p.LastName, ct.[Name], 'Store Contact' 
-- MAGIC 				FROM [Sales].[Store] AS s
-- MAGIC 					INNER JOIN [Person].[BusinessEntityContact] bec 
-- MAGIC 					ON bec.[BusinessEntityID] = s.[BusinessEntityID]
-- MAGIC 					INNER JOIN [Person].ContactType ct
-- MAGIC 					ON ct.[ContactTypeID] = bec.[ContactTypeID]
-- MAGIC 					INNER JOIN [Person].[Person] p
-- MAGIC 					ON p.[BusinessEntityID] = bec.[PersonID]
-- MAGIC 				WHERE bec.[PersonID] = @PersonID;
-- MAGIC 
-- MAGIC 		IF EXISTS(SELECT * FROM [Person].[Person] AS p
-- MAGIC 					INNER JOIN [Sales].[Customer] AS c
-- MAGIC 					ON c.[PersonID] = p.[BusinessEntityID]
-- MAGIC 					WHERE p.[BusinessEntityID] = @PersonID AND c.[StoreID] IS NULL) 
-- MAGIC 			INSERT INTO @retContactInformation
-- MAGIC 				SELECT @PersonID, p.FirstName, p.LastName, NULL, 'Consumer' 
-- MAGIC 				FROM [Person].[Person] AS p
-- MAGIC 					INNER JOIN [Sales].[Customer] AS c
-- MAGIC 					ON c.[PersonID] = p.[BusinessEntityID]
-- MAGIC 					WHERE p.[BusinessEntityID] = @PersonID AND c.[StoreID] IS NULL; 
-- MAGIC 		END
-- MAGIC 
-- MAGIC 	RETURN;
-- MAGIC END;
-- MAGIC GO
-- MAGIC 
-- MAGIC 
-- MAGIC 
-- MAGIC CREATE FUNCTION [dbo].[ufnGetProductDealerPrice](@ProductID [int], @OrderDate [datetime])
-- MAGIC RETURNS [money] 
-- MAGIC AS 
-- MAGIC -- Returns the dealer price for the product on a specific date.
-- MAGIC BEGIN
-- MAGIC     DECLARE @DealerPrice money;
-- MAGIC     DECLARE @DealerDiscount money;
-- MAGIC 
-- MAGIC     SET @DealerDiscount = 0.60  -- 60% of list price
-- MAGIC 
-- MAGIC     SELECT @DealerPrice = plph.[ListPrice] * @DealerDiscount 
-- MAGIC     FROM [Production].[Product] p 
-- MAGIC         INNER JOIN [Production].[ProductListPriceHistory] plph 
-- MAGIC         ON p.[ProductID] = plph.[ProductID] 
-- MAGIC             AND p.[ProductID] = @ProductID 
-- MAGIC             AND @OrderDate BETWEEN plph.[StartDate] AND COALESCE(plph.[EndDate], CONVERT(datetime, '99991231', 112)); -- Make sure we get all the prices!
-- MAGIC 
-- MAGIC     RETURN @DealerPrice;
-- MAGIC END;
-- MAGIC GO
-- MAGIC 
-- MAGIC CREATE FUNCTION [dbo].[ufnGetProductListPrice](@ProductID [int], @OrderDate [datetime])
-- MAGIC RETURNS [money] 
-- MAGIC AS 
-- MAGIC BEGIN
-- MAGIC     DECLARE @ListPrice money;
-- MAGIC 
-- MAGIC     SELECT @ListPrice = plph.[ListPrice] 
-- MAGIC     FROM [Production].[Product] p 
-- MAGIC         INNER JOIN [Production].[ProductListPriceHistory] plph 
-- MAGIC         ON p.[ProductID] = plph.[ProductID] 
-- MAGIC             AND p.[ProductID] = @ProductID 
-- MAGIC             AND @OrderDate BETWEEN plph.[StartDate] AND COALESCE(plph.[EndDate], CONVERT(datetime, '99991231', 112)); -- Make sure we get all the prices!
-- MAGIC 
-- MAGIC     RETURN @ListPrice;
-- MAGIC END;
-- MAGIC GO
-- MAGIC 
-- MAGIC CREATE FUNCTION [dbo].[ufnGetProductStandardCost](@ProductID [int], @OrderDate [datetime])
-- MAGIC RETURNS [money] 
-- MAGIC AS 
-- MAGIC -- Returns the standard cost for the product on a specific date.
-- MAGIC BEGIN
-- MAGIC     DECLARE @StandardCost money;
-- MAGIC 
-- MAGIC     SELECT @StandardCost = pch.[StandardCost] 
-- MAGIC     FROM [Production].[Product] p 
-- MAGIC         INNER JOIN [Production].[ProductCostHistory] pch 
-- MAGIC         ON p.[ProductID] = pch.[ProductID] 
-- MAGIC             AND p.[ProductID] = @ProductID 
-- MAGIC             AND @OrderDate BETWEEN pch.[StartDate] AND COALESCE(pch.[EndDate], CONVERT(datetime, '99991231', 112)); -- Make sure we get all the prices!
-- MAGIC 
-- MAGIC     RETURN @StandardCost;
-- MAGIC END;
-- MAGIC GO
-- MAGIC 
-- MAGIC CREATE FUNCTION [dbo].[ufnGetStock](@ProductID [int])
-- MAGIC RETURNS [int] 
-- MAGIC AS 
-- MAGIC -- Returns the stock level for the product. This function is used internally only
-- MAGIC BEGIN
-- MAGIC     DECLARE @ret int;
-- MAGIC     
-- MAGIC     SELECT @ret = SUM(p.[Quantity]) 
-- MAGIC     FROM [Production].[ProductInventory] p 
-- MAGIC     WHERE p.[ProductID] = @ProductID 
-- MAGIC         AND p.[LocationID] = '6'; -- Only look at inventory in the misc storage
-- MAGIC     
-- MAGIC     IF (@ret IS NULL) 
-- MAGIC         SET @ret = 0
-- MAGIC     
-- MAGIC     RETURN @ret
-- MAGIC END;
-- MAGIC GO
-- MAGIC 
-- MAGIC CREATE FUNCTION [dbo].[ufnGetDocumentStatusText](@Status [tinyint])
-- MAGIC RETURNS [nvarchar](16) 
-- MAGIC AS 
-- MAGIC -- Returns the sales order status text representation for the status value.
-- MAGIC BEGIN
-- MAGIC     DECLARE @ret [nvarchar](16);
-- MAGIC 
-- MAGIC     SET @ret = 
-- MAGIC         CASE @Status
-- MAGIC             WHEN 1 THEN N'Pending approval'
-- MAGIC             WHEN 2 THEN N'Approved'
-- MAGIC             WHEN 3 THEN N'Obsolete'
-- MAGIC             ELSE N'** Invalid **'
-- MAGIC         END;
-- MAGIC     
-- MAGIC     RETURN @ret
-- MAGIC END;
-- MAGIC GO
-- MAGIC 
-- MAGIC CREATE FUNCTION [dbo].[ufnGetPurchaseOrderStatusText](@Status [tinyint])
-- MAGIC RETURNS [nvarchar](15) 
-- MAGIC AS 
-- MAGIC -- Returns the sales order status text representation for the status value.
-- MAGIC BEGIN
-- MAGIC     DECLARE @ret [nvarchar](15);
-- MAGIC 
-- MAGIC     SET @ret = 
-- MAGIC         CASE @Status
-- MAGIC             WHEN 1 THEN 'Pending'
-- MAGIC             WHEN 2 THEN 'Approved'
-- MAGIC             WHEN 3 THEN 'Rejected'
-- MAGIC             WHEN 4 THEN 'Complete'
-- MAGIC             ELSE '** Invalid **'
-- MAGIC         END;
-- MAGIC     
-- MAGIC     RETURN @ret
-- MAGIC END;
-- MAGIC GO
-- MAGIC 
-- MAGIC CREATE FUNCTION [dbo].[ufnGetSalesOrderStatusText](@Status [tinyint])
-- MAGIC RETURNS [nvarchar](15) 
-- MAGIC AS 
-- MAGIC -- Returns the sales order status text representation for the status value.
-- MAGIC BEGIN
-- MAGIC     DECLARE @ret [nvarchar](15);
-- MAGIC 
-- MAGIC     SET @ret = 
-- MAGIC         CASE @Status
-- MAGIC             WHEN 1 THEN 'In process'
-- MAGIC             WHEN 2 THEN 'Approved'
-- MAGIC             WHEN 3 THEN 'Backordered'
-- MAGIC             WHEN 4 THEN 'Rejected'
-- MAGIC             WHEN 5 THEN 'Shipped'
-- MAGIC             WHEN 6 THEN 'Cancelled'
-- MAGIC             ELSE '** Invalid **'
-- MAGIC         END;
-- MAGIC     
-- MAGIC     RETURN @ret
-- MAGIC END;
-- MAGIC GO
-- MAGIC ```