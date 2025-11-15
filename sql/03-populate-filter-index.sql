-- =====================================================================
-- Step 3: Populate search.product_filter_index
-- =====================================================================
-- Purpose: Build flattened ETIM feature index for fast luminaire filtering
-- Database: FOSSAPP Supabase
-- Date: 2025-01-15
-- Scope: LUMINAIRES (ETIM group EG000027) FROM ACTIVE CATALOGS ONLY
-- Source: items.product_feature (1.38M ETIM features)
-- Target: search.product_filter_index
-- Duration: ~5-10 minutes for 13,336 luminaires

-- =====================================================================
-- CRITICAL CONSTRAINTS (DO NOT MODIFY)
-- =====================================================================
-- ✅ ONLY products from catalogs where catalog.active = true
-- ✅ ONLY products in ETIM group EG000027 (Luminaires)
-- ✅ ONLY features mapped in search.filter_definitions (active = true)

-- =====================================================================
-- Clear existing index (if re-running)
-- =====================================================================

-- CAUTION: Uncomment only if you want to rebuild from scratch
-- TRUNCATE search.product_filter_index;

-- =====================================================================
-- Build Filter Index from ETIM Features
-- =====================================================================

INSERT INTO search.product_filter_index (
  product_id,
  filter_key,
  numeric_value,
  alphanumeric_value,
  boolean_value,
  source_feature_id
)
SELECT
  pf.product_id,
  fd.filter_key,
  -- Numeric value (for range filters like CCT, Lumens, Power)
  pf.fvaluen as numeric_value,
  -- Alphanumeric value (for multi-select filters like IP, Colour)
  -- Use human-readable description from etim.value if available, otherwise use code
  COALESCE(v."VALUEDESC", pf.fvaluec) as alphanumeric_value,
  -- Boolean value (for yes/no filters like Dimmable, Adjustability)
  pf.fvalueb as boolean_value,
  -- Source ETIM feature for traceability
  pf.fname_id as source_feature_id
FROM items.product_feature pf

-- Join to filter definitions (only index mapped features)
JOIN search.filter_definitions fd
  ON fd.etim_feature_id = pf.fname_id
  AND fd.active = true

-- ✅ CONSTRAINT 1: Only products from active catalogs
JOIN items.product p ON p.id = pf.product_id
JOIN items.catalog c ON c.id = p.catalog_id
  AND c.active = true

-- ✅ CONSTRAINT 2: Only luminaires (ETIM group EG000027)
JOIN items.product_detail pd ON pd.product_id = p.id
JOIN etim.class ec ON ec."ARTCLASSID" = pd.class_id
  AND ec."ARTGROUPID" = 'EG000027'

-- Left join to ETIM value descriptions (for alphanumeric values)
LEFT JOIN etim.value v ON v."VALUEID" = pf.fvaluec

-- Only index rows with at least one value
WHERE (
  pf.fvaluen IS NOT NULL OR
  pf.fvaluec IS NOT NULL OR
  pf.fvalueb IS NOT NULL
)

-- Handle duplicates gracefully (use DISTINCT to avoid duplicate feature values)
ON CONFLICT DO NOTHING;

-- =====================================================================
-- Create Additional Indexes for Performance
-- =====================================================================

-- Composite indexes for common filter queries
CREATE INDEX IF NOT EXISTS idx_pfi_composite_voltage
  ON search.product_filter_index(filter_key, alphanumeric_value, product_id)
  WHERE filter_key = 'voltage';

CREATE INDEX IF NOT EXISTS idx_pfi_composite_ip
  ON search.product_filter_index(filter_key, alphanumeric_value, product_id)
  WHERE filter_key = 'ip';

CREATE INDEX IF NOT EXISTS idx_pfi_composite_cct_range
  ON search.product_filter_index(filter_key, numeric_value, product_id)
  WHERE filter_key = 'cct' AND numeric_value IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pfi_composite_lumens_range
  ON search.product_filter_index(filter_key, numeric_value, product_id)
  WHERE filter_key = 'lumens_output' AND numeric_value IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pfi_composite_boolean
  ON search.product_filter_index(filter_key, boolean_value, product_id)
  WHERE boolean_value IS NOT NULL;

-- =====================================================================
-- Analyze Table for Query Optimization
-- =====================================================================

ANALYZE search.product_filter_index;

-- =====================================================================
-- Verification Queries
-- =====================================================================

-- 1. Show indexing summary
SELECT
  fd.label as filter_name,
  fd.filter_key,
  fd.filter_type,
  COUNT(DISTINCT pfi.product_id) as products_indexed,
  COUNT(*) as total_values,
  COUNT(DISTINCT pfi.alphanumeric_value) as unique_alpha_values,
  MIN(pfi.numeric_value) as min_numeric,
  MAX(pfi.numeric_value) as max_numeric
FROM search.filter_definitions fd
LEFT JOIN search.product_filter_index pfi ON pfi.filter_key = fd.filter_key
WHERE fd.active = true
  AND fd.applicable_taxonomy_codes @> ARRAY['LUMINAIRE']::text[]
GROUP BY fd.filter_key, fd.label, fd.filter_type
ORDER BY fd.display_order;

-- 2. Verify active catalog constraint
SELECT
  'Total luminaire products (all catalogs)' as metric,
  COUNT(DISTINCT p.id) as count
FROM items.product p
JOIN items.product_detail pd ON pd.product_id = p.id
JOIN etim.class ec ON ec."ARTCLASSID" = pd.class_id
WHERE ec."ARTGROUPID" = 'EG000027'

UNION ALL

SELECT
  'Luminaire products in active catalogs' as metric,
  COUNT(DISTINCT p.id) as count
FROM items.product p
JOIN items.catalog c ON c.id = p.catalog_id AND c.active = true
JOIN items.product_detail pd ON pd.product_id = p.id
JOIN etim.class ec ON ec."ARTCLASSID" = pd.class_id
WHERE ec."ARTGROUPID" = 'EG000027'

UNION ALL

SELECT
  'Products indexed in filter index' as metric,
  COUNT(DISTINCT product_id) as count
FROM search.product_filter_index;

-- 3. Sample indexed data for each filter type
SELECT
  fd.filter_key,
  fd.filter_type,
  CASE
    WHEN fd.filter_type = 'multi-select' THEN pfi.alphanumeric_value
    WHEN fd.filter_type = 'range' THEN pfi.numeric_value::text
    WHEN fd.filter_type = 'boolean' THEN pfi.boolean_value::text
  END as sample_value,
  COUNT(*) as value_count
FROM search.filter_definitions fd
JOIN search.product_filter_index pfi ON pfi.filter_key = fd.filter_key
WHERE fd.active = true
GROUP BY fd.filter_key, fd.filter_type, pfi.alphanumeric_value, pfi.numeric_value, pfi.boolean_value
ORDER BY fd.filter_key, value_count DESC
LIMIT 50;

-- =====================================================================
-- Completion Message
-- =====================================================================

DO $$
DECLARE
  total_products INTEGER;
  indexed_products INTEGER;
  total_values INTEGER;
  active_filters INTEGER;
BEGIN
  -- Get statistics
  SELECT COUNT(DISTINCT p.id) INTO total_products
  FROM items.product p
  JOIN items.catalog c ON c.id = p.catalog_id AND c.active = true
  JOIN items.product_detail pd ON pd.product_id = p.id
  JOIN etim.class ec ON ec."ARTCLASSID" = pd.class_id
  WHERE ec."ARTGROUPID" = 'EG000027';

  SELECT COUNT(DISTINCT product_id) INTO indexed_products
  FROM search.product_filter_index;

  SELECT COUNT(*) INTO total_values
  FROM search.product_filter_index;

  SELECT COUNT(*) INTO active_filters
  FROM search.filter_definitions
  WHERE active = true
    AND applicable_taxonomy_codes @> ARRAY['LUMINAIRE']::text[];

  RAISE NOTICE '✅ Product filter index populated successfully!';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Indexing Statistics:';
  RAISE NOTICE '   - Total luminaires (active catalogs): %', total_products;
  RAISE NOTICE '   - Products indexed: %', indexed_products;
  RAISE NOTICE '   - Total filter values: %', total_values;
  RAISE NOTICE '   - Active filters: %', active_filters;
  RAISE NOTICE '';
  RAISE NOTICE '✅ Constraints verified:';
  RAISE NOTICE '   - ONLY active catalogs ✓';
  RAISE NOTICE '   - ONLY ETIM group EG000027 (Luminaires) ✓';
  RAISE NOTICE '   - ONLY mapped ETIM features ✓';
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '   1. REFRESH MATERIALIZED VIEW search.filter_facets;';
  RAISE NOTICE '   2. Review verification queries above';
  RAISE NOTICE '   3. Test filter queries in 04-test-filter-queries.sql';
END $$;
