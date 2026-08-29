-- =============================================================================
-- Run in: Spark SQL / Zeppelin
-- =============================================================================
-- Back to engine #1. This is the file that actually proves the claim: Spark
-- sees Snowflake's writes, because neither engine owns the table -- the
-- catalog does.
-- -----------------------------------------------------------------------------

-- Order 1007 was inserted by Snowflake. 1006 was refunded by Snowflake.
SELECT order_id, customer_id, order_date, amount, status
FROM r2.demo.orders
ORDER BY order_id;

-- The snapshot log now interleaves commits from both engines.
SELECT snapshot_id, committed_at, operation
FROM r2.demo.orders.snapshots
ORDER BY committed_at;

-- Time travel across an engine boundary: read the table as it was before
-- Snowflake touched it. Substitute a snapshot_id from the query above.
-- SELECT * FROM r2.demo.orders VERSION AS OF <snapshot_id>;

-- Data file inventory -- one row per Parquet file, whichever engine wrote it.
SELECT file_path, record_count, file_size_in_bytes
FROM r2.demo.orders.files;
