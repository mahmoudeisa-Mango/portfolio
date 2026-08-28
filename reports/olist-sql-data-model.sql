-- 1. Database Setup
USE master;
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'Olist_EcommerceDB')
BEGIN
    CREATE DATABASE Olist_EcommerceDB;
END;
GO

USE Olist_EcommerceDB;
GO



DROP VIEW IF EXISTS dbo.vw_Master_Order_Extract;
GO

CREATE VIEW dbo.vw_Master_Order_Extract AS
WITH PaymentSummary AS (
    -- Group payments per order to get total money spent
    SELECT 
        order_id,
        SUM(payment_value) AS total_payment_value,
        MAX(payment_type) AS primary_payment_type,
        MAX(payment_installments) AS max_installments
    FROM dbo.order_payments
    GROUP BY order_id
)
SELECT 
    -- 1. Order & Customer Identifiers
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,

    -- 2. Order Status & Timestamps
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    -- 3. Delivery Calculations (in Days)
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_lag_days,
    DATEDIFF(DAY, o.order_delivered_carrier_date, o.order_delivered_customer_date) AS carrier_transit_days,
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_estimated_delivery_date) AS estimated_lag_days,

    -- Delivery Performance Flag (1 = Late, 0 = On Time)
    CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 
        ELSE 0 
    END AS is_late_delivery,

    DATEDIFF(DAY, o.order_estimated_delivery_date, o.order_delivered_customer_date) AS days_overdue,

    -- 4. Financial Metrics
    p.total_payment_value,
    p.primary_payment_type,
    p.max_installments

FROM dbo.orders o
INNER JOIN dbo.customers c 
    ON o.customer_id = c.customer_id
LEFT JOIN PaymentSummary p 
    ON o.order_id = p.order_id;
GO

-- Simple sanity check
SELECT TOP 100 * 
FROM dbo.vw_Master_Order_Extract 
ORDER BY order_purchase_timestamp DESC;
GO



DROP VIEW IF EXISTS dbo.vw_Dim_Customers;
GO

CREATE VIEW dbo.vw_Dim_Customers AS
SELECT DISTINCT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM dbo.customers;
GO


DROP VIEW IF EXISTS dbo.vw_Dim_Products;
GO

CREATE VIEW dbo.vw_Dim_Products AS
SELECT 
    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM dbo.products;
GO


DROP VIEW IF EXISTS dbo.vw_Dim_Sellers;
GO

CREATE VIEW dbo.vw_Dim_Sellers AS
SELECT 
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM dbo.sellers;
GO


DROP VIEW IF EXISTS dbo.vw_Fact_Orders;
GO

CREATE VIEW dbo.vw_Fact_Orders AS
SELECT 
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    
    -- Delivery metric calculations
    DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) AS delivery_lag_days,
    CASE 
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 
        ELSE 0 
    END AS is_late_delivery
FROM dbo.orders;
GO


DROP VIEW IF EXISTS dbo.vw_Fact_Order_Items;
GO

CREATE VIEW dbo.vw_Fact_Order_Items AS
SELECT 
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value,
    (price + freight_value) AS total_item_cost
FROM dbo.order_items;
GO



SELECT 'Fact_Orders' AS View_Name, COUNT(*) AS Total_Rows FROM dbo.vw_Fact_Orders
UNION ALL
SELECT 'Dim_Customers', COUNT(*) FROM dbo.vw_Dim_Customers
UNION ALL
SELECT 'Dim_Products', COUNT(*) FROM dbo.vw_Dim_Products
UNION ALL
SELECT 'Fact_Order_Items', COUNT(*) FROM dbo.vw_Fact_Order_Items;
GO