-- ============================================================================
-- FIX: Add numeric range (fvaluer) support to search.product_filter_index
-- ============================================================================
-- Problem: Voltage, CCT, and Lumens filters show "No data found" because
--          they are stored in fvaluer (numrange) column, but the view only
--          checks fvaluen, fvaluec, fvalueb columns.
--
-- Solution: Add fvaluer handling with numeric_min/numeric_max extraction
-- ============================================================================

BEGIN;

-- Step 1: Drop dependent views in correct order
-- ============================================================================
DROP VIEW IF EXISTS public.filter_facets CASCADE;
DROP MATERIALIZED VIEW IF EXISTS search.filter_facets CASCADE;

-- Step 2: Drop and recreate search.product_filter_index with range support
-- ============================================================================
DROP MATERIALIZED VIEW IF EXISTS search.product_filter_index CASCADE;

CREATE MATERIALIZED VIEW search.product_filter_index AS
SELECT
    row_number() OVER () AS id,
    pf.product_id,
    fd.filter_key,
    -- Numeric value: use fvaluen if available, otherwise use range midpoint
    COALESCE(
        pf.fvaluen::numeric,
        (lower(pf.fvaluer) + upper(pf.fvaluer)) / 2.0
    ) AS numeric_value,
    -- Alphanumeric value (unchanged)
    COALESCE(v."VALUEDESC", pf.fvaluec) AS alphanumeric_value,
    -- Boolean value (unchanged)
    pf.fvalueb AS boolean_value,
    -- NEW: Range minimum (for range filters)
    lower(pf.fvaluer) AS numeric_min,
    -- NEW: Range maximum (for range filters)
    upper(pf.fvaluer) AS numeric_max,
    -- Source feature ID (unchanged)
    pf.fname_id AS source_feature_id,
    now() AS created_at
FROM items.product_feature pf
JOIN search.filter_definitions fd
    ON fd.etim_feature_id = pf.fname_id
    AND fd.active = true
JOIN items.product p
    ON p.id = pf.product_id
JOIN items.catalog c
    ON c.id = p.catalog_id
    AND c.active = true
JOIN items.product_detail pd
    ON pd.product_id = p.id
JOIN etim.class ec
    ON ec."ARTCLASSID" = pd.class_id
    AND ec."ARTGROUPID" = 'EG000027'
LEFT JOIN etim.value v
    ON v."VALUEID" = pf.fvaluec
WHERE
    -- CRITICAL FIX: Include fvaluer in the filter condition
    pf.fvaluen IS NOT NULL
    OR pf.fvaluec IS NOT NULL
    OR pf.fvalueb IS NOT NULL
    OR pf.fvaluer IS NOT NULL;  -- NEW: This was missing!

-- Create indexes for performance
CREATE INDEX idx_product_filter_index_product_id
    ON search.product_filter_index(product_id);
CREATE INDEX idx_product_filter_index_filter_key
    ON search.product_filter_index(filter_key);
CREATE INDEX idx_product_filter_index_numeric_value
    ON search.product_filter_index(numeric_value)
    WHERE numeric_value IS NOT NULL;
CREATE INDEX idx_product_filter_index_alphanumeric_value
    ON search.product_filter_index(alphanumeric_value)
    WHERE alphanumeric_value IS NOT NULL;
-- NEW: Indexes for range queries
CREATE INDEX idx_product_filter_index_numeric_min
    ON search.product_filter_index(numeric_min)
    WHERE numeric_min IS NOT NULL;
CREATE INDEX idx_product_filter_index_numeric_max
    ON search.product_filter_index(numeric_max)
    WHERE numeric_max IS NOT NULL;

-- Step 3: Recreate search.filter_facets materialized view
-- ============================================================================
CREATE MATERIALIZED VIEW search.filter_facets AS
SELECT
    fd.filter_key,
    fd.filter_type,
    fd.filter_label,
    fd.etim_feature_id,
    -- For range filters, calculate min/max across all products
    CASE
        WHEN fd.filter_type = 'range' THEN
            jsonb_build_object(
                'min', MIN(COALESCE(pfi.numeric_min, pfi.numeric_value)),
                'max', MAX(COALESCE(pfi.numeric_max, pfi.numeric_value)),
                'count', COUNT(DISTINCT pfi.product_id)
            )
        ELSE NULL
    END AS range_data,
    -- For categorical filters, aggregate value counts
    CASE
        WHEN fd.filter_type = 'categorical' THEN
            jsonb_agg(
                DISTINCT jsonb_build_object(
                    'value', pfi.alphanumeric_value,
                    'count', facet_counts.count
                )
            ) FILTER (WHERE pfi.alphanumeric_value IS NOT NULL)
        ELSE NULL
    END AS categorical_data,
    -- For boolean filters, count true/false
    CASE
        WHEN fd.filter_type = 'boolean' THEN
            jsonb_build_object(
                'true_count', COUNT(*) FILTER (WHERE pfi.boolean_value = true),
                'false_count', COUNT(*) FILTER (WHERE pfi.boolean_value = false)
            )
        ELSE NULL
    END AS boolean_data,
    COUNT(DISTINCT pfi.product_id) AS total_products,
    now() AS created_at
FROM search.filter_definitions fd
LEFT JOIN search.product_filter_index pfi ON pfi.filter_key = fd.filter_key
LEFT JOIN LATERAL (
    SELECT
        pfi2.alphanumeric_value,
        COUNT(DISTINCT pfi2.product_id) as count
    FROM search.product_filter_index pfi2
    WHERE pfi2.filter_key = fd.filter_key
        AND pfi2.alphanumeric_value IS NOT NULL
    GROUP BY pfi2.alphanumeric_value
) facet_counts ON fd.filter_type = 'categorical' AND facet_counts.alphanumeric_value = pfi.alphanumeric_value
WHERE fd.active = true
GROUP BY fd.filter_key, fd.filter_type, fd.filter_label, fd.etim_feature_id;

CREATE INDEX idx_filter_facets_filter_key ON search.filter_facets(filter_key);

-- Step 4: Recreate public.filter_facets view (if it exists in your schema)
-- ============================================================================
CREATE OR REPLACE VIEW public.filter_facets AS
SELECT * FROM search.filter_facets;

-- Step 5: Refresh all materialized views
-- ============================================================================
REFRESH MATERIALIZED VIEW search.product_filter_index;
REFRESH MATERIALIZED VIEW search.filter_facets;

-- Step 6: Analyze tables for query optimization
-- ============================================================================
ANALYZE search.product_filter_index;
ANALYZE search.filter_facets;

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check that range filters now have data
SELECT
    filter_key,
    COUNT(DISTINCT product_id) as product_count,
    MIN(numeric_min) as min_value,
    MAX(numeric_max) as max_value
FROM search.product_filter_index
WHERE filter_key IN ('voltage', 'cct', 'lumens_output')
GROUP BY filter_key
ORDER BY filter_key;

-- Check filter facets
SELECT
    filter_key,
    filter_type,
    total_products,
    range_data
FROM search.filter_facets
WHERE filter_key IN ('voltage', 'cct', 'lumens_output')
ORDER BY filter_key;

-- Sample range data to verify extraction
SELECT
    product_id,
    filter_key,
    numeric_value,
    numeric_min,
    numeric_max
FROM search.product_filter_index
WHERE filter_key IN ('voltage', 'cct', 'lumens_output')
LIMIT 20;
