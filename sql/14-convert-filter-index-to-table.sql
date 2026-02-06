-- =====================================================================
-- File: 14-convert-filter-index-to-table.sql
-- Purpose: Convert product_filter_index from matview to table with
--          batch rebuild function for 2.2M+ product scale
-- =====================================================================
-- The matview definition uses JOINs (not CROSS JOIN) so it's more
-- efficient than taxonomy_flags. But at 2.2M products, the matview
-- REFRESH can still hit statement timeouts. Converting to a table
-- with rebuild function adds timeout control and atomic swap.
-- =====================================================================

-- Step 1: Drop the matview
DROP MATERIALIZED VIEW IF EXISTS search.product_filter_index CASCADE;

-- Step 2: Create the regular table with same schema
CREATE TABLE search.product_filter_index (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    product_id UUID NOT NULL,
    filter_key TEXT NOT NULL,
    filter_type TEXT NOT NULL,
    numeric_value NUMERIC,
    alphanumeric_value TEXT,
    boolean_value BOOLEAN,
    numeric_min NUMERIC,
    numeric_max NUMERIC,
    source_feature_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Step 3: Indexes (matching original matview)
CREATE INDEX idx_pfi_product_id ON search.product_filter_index(product_id);
CREATE INDEX idx_pfi_filter_key ON search.product_filter_index(filter_key);
CREATE INDEX idx_pfi_numeric ON search.product_filter_index(filter_key, numeric_value)
    WHERE numeric_value IS NOT NULL;
CREATE INDEX idx_pfi_alpha ON search.product_filter_index(filter_key, alphanumeric_value)
    WHERE alphanumeric_value IS NOT NULL;
CREATE INDEX idx_pfi_bool ON search.product_filter_index(filter_key, boolean_value)
    WHERE boolean_value = true;
CREATE INDEX idx_pfi_product_filter ON search.product_filter_index(product_id, filter_key);

-- Step 4: Permissions
GRANT SELECT ON search.product_filter_index TO authenticated, service_role, anon;

-- NOTE: The rebuild logic lives in the bash script:
--   supabase/db-maintenance/rebuild-search-tables.sh
--
-- It runs each step as a separate psql connection/transaction,
-- preventing resource exhaustion at 2.2M+ product scale.
-- The PL/pgSQL function approach was abandoned because a single
-- transaction holding millions of rows overwhelms shared buffers.
--
-- Usage:
--   ./rebuild-search-tables.sh --filter-only    # ~5 min for 2.2M products
--   ./rebuild-search-tables.sh --taxonomy-only  # taxonomy flags only
--   ./rebuild-search-tables.sh                  # both
