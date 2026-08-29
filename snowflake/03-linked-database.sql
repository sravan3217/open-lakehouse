-- =============================================================================
-- 03 -- Expose the catalog's tables inside Snowflake
-- =============================================================================
-- Two ways to do this. A catalog-linked database is the one that keeps the
-- decoupling story honest: tables Spark creates show up in Snowflake on their
-- own, with no per-table DDL and nothing to re-run when the schema changes.
-- -----------------------------------------------------------------------------

-- --- Option A: catalog-linked database (recommended) -------------------------
-- Snowflake polls the REST catalog and mirrors whatever namespaces it finds.
-- Create a table in Spark, wait one sync interval, query it in Snowflake.
CREATE OR REPLACE DATABASE r2_lakehouse
  LINKED_CATALOG = (
    CATALOG = 'cat_int_cloudflare_r2',

    -- Restrict to the namespaces you actually want mirrored. Omit to sync all.
    ALLOWED_NAMESPACES = ('demo'),

    -- Iceberg namespaces can nest; Snowflake schemas cannot. FLATTEN maps
    -- a.b.c to a single schema named with the joined path.
    NAMESPACE_MODE = FLATTEN_NESTED_NAMESPACE,

    SYNC_INTERVAL_SECONDS = 30
  )
  EXTERNAL_VOLUME = 'ext_vol_cloudflare_r2';

-- Force a sync instead of waiting for the interval.
ALTER DATABASE r2_lakehouse REFRESH;

SHOW SCHEMAS IN DATABASE r2_lakehouse;
SHOW ICEBERG TABLES IN DATABASE r2_lakehouse;


-- --- Option B: mount one table at a time -------------------------------------
-- More verbose, but useful if you want only a subset, or want a Snowflake-side
-- name that differs from the catalog's. Must be repeated per table.
--
-- CREATE OR REPLACE ICEBERG TABLE customers
--   EXTERNAL_VOLUME      = 'ext_vol_cloudflare_r2'
--   CATALOG              = 'cat_int_cloudflare_r2'
--   CATALOG_NAMESPACE    = 'demo'
--   CATALOG_TABLE_NAME   = 'customers'
--   AUTO_REFRESH         = TRUE;
