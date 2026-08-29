-- =============================================================================
-- 01 -- External volume: teach Snowflake how to read/write the R2 bucket
-- =============================================================================
-- This is the STORAGE half of the integration. It grants Snowflake direct
-- S3-compatible access to the same bucket Spark writes to, so Snowflake reads
-- Parquet files in place rather than copying them into Snowflake-managed
-- storage. No ingest, no second copy, no egress bill.
--
-- Replace ${...} with your values before running. See .env.example.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE EXTERNAL VOLUME ext_vol_cloudflare_r2
  STORAGE_LOCATIONS = (
    (
      NAME = 'r2_storage'

      -- S3COMPAT, not S3. Cloudflare R2 speaks the S3 API but is not AWS,
      -- so the AWS IAM role trust flow does not apply -- static keys instead.
      STORAGE_PROVIDER = 'S3COMPAT'

      STORAGE_BASE_URL = 's3compat://${R2_BUCKET}/'

      CREDENTIALS = (
        AWS_KEY_ID     = '${R2_ACCESS_KEY_ID}'
        AWS_SECRET_KEY = '${R2_SECRET_ACCESS_KEY}'
      )

      -- Hostname only, no scheme.
      STORAGE_ENDPOINT = '${R2_ACCOUNT_ID}.r2.cloudflarestorage.com'
    )
  )

  -- The switch that makes this bidirectional. Without ALLOW_WRITES, Snowflake
  -- is a read-only consumer of tables Spark produces; with it, Snowflake can
  -- run DML against the same Iceberg tables.
  ALLOW_WRITES = TRUE;

-- Verify Snowflake can actually reach the bucket before moving on.
-- Look for STORAGE_ALLOWED / write test success in the output.
SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('ext_vol_cloudflare_r2');

DESC EXTERNAL VOLUME ext_vol_cloudflare_r2;
