-- =============================================================================
-- Run in: Snowflake
-- =============================================================================
-- Engine #2, on the same tables. No ingest step ran between this file and the
-- last one. Snowflake asked the R2 Data Catalog for the current metadata
-- pointer and read the Parquet files Spark wrote, in place.
-- -----------------------------------------------------------------------------

USE DATABASE r2_lakehouse;
USE SCHEMA demo;

-- Tables Spark created, visible here with no DDL of their own.
SHOW ICEBERG TABLES;

-- The same aggregate as the Spark query, on Snowflake compute.
SELECT c.country,
       COUNT(*)      AS order_count,
       SUM(o.amount) AS revenue
FROM orders o
JOIN customers c USING (customer_id)
WHERE o.status = 'SHIPPED'
GROUP BY c.country
ORDER BY revenue DESC;

-- Now write back. This commits to the same catalog Spark commits to.
INSERT INTO orders VALUES
  (1007, 2, DATE '2024-08-05', 780.00, 'SHIPPED');

UPDATE orders
SET status = 'REFUNDED'
WHERE order_id = 1006;

-- A view, created by Snowflake, over Iceberg tables created by Spark.
CREATE OR REPLACE VIEW v_revenue_by_country AS
SELECT c.country,
       COUNT(*)      AS order_count,
       SUM(o.amount) AS revenue
FROM orders o
JOIN customers c USING (customer_id)
WHERE o.status = 'SHIPPED'
GROUP BY c.country;

SELECT * FROM v_revenue_by_country ORDER BY revenue DESC;
