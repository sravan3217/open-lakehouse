-- =============================================================================
-- Run in: Spark SQL / Zeppelin (%spark.sql)  -- the `r2` catalog
-- =============================================================================
-- Creating the tables from Spark. Every CREATE below is a commit to the R2
-- Data Catalog; the Parquet and Iceberg metadata land in the R2 bucket.
-- Nothing here is Spark-specific -- that is the point.
-- -----------------------------------------------------------------------------

CREATE NAMESPACE IF NOT EXISTS r2.demo;

DROP TABLE IF EXISTS r2.demo.customers;
CREATE TABLE r2.demo.customers (
    customer_id   BIGINT,
    name          STRING,
    country       STRING,
    signup_date   DATE
) USING iceberg;

DROP TABLE IF EXISTS r2.demo.orders;
CREATE TABLE r2.demo.orders (
    order_id      BIGINT,
    customer_id   BIGINT,
    order_date    DATE,
    amount        DECIMAL(10,2),
    status        STRING
) USING iceberg
-- Hidden partitioning: the transform is recorded in table metadata, so queries
-- filtering on order_date prune partitions without naming a partition column.
-- Snowflake honours this too, because it reads the same metadata.
PARTITIONED BY (months(order_date));

SHOW TABLES IN r2.demo;
DESCRIBE EXTENDED r2.demo.orders;
