-- =============================================================================
-- 02 -- Catalog integration: point Snowflake at the R2 Data Catalog
-- =============================================================================
-- This is the CATALOG half. The external volume told Snowflake where the bytes
-- live; this tells it who decides which bytes are the current table state.
--
-- Snowflake becomes a *client* of an external Iceberg REST catalog instead of
-- using its own metadata store. That is the whole decoupling argument: table
-- state has one owner, and every engine asks it.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE CATALOG INTEGRATION cat_int_cloudflare_r2
  CATALOG_SOURCE = ICEBERG_REST
  TABLE_FORMAT   = ICEBERG

  REST_CONFIG = (
    CATALOG_URI = 'https://catalog.cloudflarestorage.com/${R2_ACCOUNT_ID}/${R2_BUCKET}'

    -- R2's warehouse identifier is literally "<account_id>_<bucket_name>".
    -- It is not a path and not a URL.
    WAREHOUSE   = '${R2_ACCOUNT_ID}_${R2_BUCKET}'
  )

  REST_AUTHENTICATION = (
    -- Static bearer token, matching the Spark side's
    -- rest.auth.type=none + Authorization header approach.
    TYPE         = BEARER
    BEARER_TOKEN = '${R2_CATALOG_TOKEN}'
  )

  ENABLED = TRUE;

SELECT SYSTEM$VERIFY_CATALOG_INTEGRATION('cat_int_cloudflare_r2');
