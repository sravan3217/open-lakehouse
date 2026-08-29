-- =============================================================================
-- Run in: Spark SQL / Zeppelin
-- =============================================================================
-- Engine #1 writes.
-- -----------------------------------------------------------------------------

INSERT INTO r2.demo.customers VALUES
  (1, 'Acme Corp',      'US', DATE '2024-01-15'),
  (2, 'Globex',         'DE', DATE '2024-02-03'),
  (3, 'Initech',        'US', DATE '2024-02-20'),
  (4, 'Umbrella Ltd',   'UK', DATE '2024-03-11'),
  (5, 'Soylent GmbH',   'DE', DATE '2024-04-02');

INSERT INTO r2.demo.orders VALUES
  (1001, 1, DATE '2024-05-01', 1200.00, 'SHIPPED'),
  (1002, 2, DATE '2024-05-04',  340.50, 'SHIPPED'),
  (1003, 1, DATE '2024-06-12',  875.25, 'PENDING'),
  (1004, 3, DATE '2024-06-18', 2100.00, 'SHIPPED'),
  (1005, 4, DATE '2024-07-02',   99.99, 'PENDING'),
  (1006, 5, DATE '2024-07-22',  450.00, 'CANCELLED');

-- Iceberg gives Spark row-level updates on object storage -- no rewrite of the
-- whole table, no Hive-style partition juggling.
UPDATE r2.demo.orders
SET status = 'SHIPPED'
WHERE order_id = 1003;

SELECT c.country,
       COUNT(*)      AS order_count,
       SUM(o.amount) AS revenue
FROM r2.demo.orders o
JOIN r2.demo.customers c USING (customer_id)
WHERE o.status = 'SHIPPED'
GROUP BY c.country
ORDER BY revenue DESC;

-- Snapshot history: every commit above is an atomic, addressable version.
SELECT snapshot_id, committed_at, operation
FROM r2.demo.orders.snapshots
ORDER BY committed_at;
