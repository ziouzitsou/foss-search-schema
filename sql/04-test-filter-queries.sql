-- =====================================================================
-- Step 4: Test Filter Queries
-- =====================================================================
-- Purpose: Example queries demonstrating Delta Light-style filtering
-- Database: FOSSAPP Supabase
-- Date: 2025-01-15
-- Scope: Luminaires (ETIM group EG000027) from active catalogs

-- =====================================================================
-- Query 1: Simple Multi-Select Filter (IP Rating)
-- =====================================================================
-- Find all luminaires with IP65 or IP44 rating

SELECT DISTINCT
  p.id,
  p.foss_pid,
  pi.description_short,
  pfi.alphanumeric_value as ip_rating
FROM items.product p
JOIN items.product_info pi ON pi.product_id = p.id
JOIN search.product_filter_index pfi ON pfi.product_id = p.id
WHERE pfi.filter_key = 'ip'
  AND pfi.alphanumeric_value IN ('IP65', 'IP44')
ORDER BY p.foss_pid
LIMIT 20;

-- =====================================================================
-- Query 2: Range Filter (Color Temperature)
-- =====================================================================
-- Find luminaires with CCT between 2700K and 3000K (warm white)

SELECT DISTINCT
  p.id,
  p.foss_pid,
  pi.description_short,
  pfi.numeric_value as cct_kelvin
FROM items.product p
JOIN items.product_info pi ON pi.product_id = p.id
JOIN search.product_filter_index pfi ON pfi.product_id = p.id
WHERE pfi.filter_key = 'cct'
  AND pfi.numeric_value BETWEEN 2700 AND 3000
ORDER BY pfi.numeric_value, p.foss_pid
LIMIT 20;

-- =====================================================================
-- Query 3: Boolean Filter (Dimmable)
-- =====================================================================
-- Find all dimmable luminaires

SELECT DISTINCT
  p.id,
  p.foss_pid,
  pi.description_short,
  pfi.boolean_value as is_dimmable
FROM items.product p
JOIN items.product_info pi ON pi.product_id = p.id
JOIN search.product_filter_index pfi ON pfi.product_id = p.id
WHERE pfi.filter_key = 'dimmable'
  AND pfi.boolean_value = true
ORDER BY p.foss_pid
LIMIT 20;

-- =====================================================================
-- Query 4: Multiple Filters Combined (AND logic)
-- =====================================================================
-- Find dimmable luminaires with IP65 AND CCT 3000K AND CRI > 90

WITH filtered_products AS (
  SELECT DISTINCT product_id
  FROM search.product_filter_index
  WHERE filter_key = 'dimmable' AND boolean_value = true

  INTERSECT

  SELECT DISTINCT product_id
  FROM search.product_filter_index
  WHERE filter_key = 'ip' AND alphanumeric_value = 'IP65'

  INTERSECT

  SELECT DISTINCT product_id
  FROM search.product_filter_index
  WHERE filter_key = 'cct' AND numeric_value = 3000

  INTERSECT

  SELECT DISTINCT product_id
  FROM search.product_filter_index
  WHERE filter_key = 'cri' AND numeric_value > 90
)
SELECT
  p.id,
  p.foss_pid,
  pi.description_short,
  STRING_AGG(
    pfi.filter_key || ': ' || COALESCE(
      pfi.alphanumeric_value,
      pfi.numeric_value::text,
      pfi.boolean_value::text
    ),
    ', '
  ) as filter_values
FROM filtered_products fp
JOIN items.product p ON p.id = fp.product_id
JOIN items.product_info pi ON pi.product_id = p.id
LEFT JOIN search.product_filter_index pfi ON pfi.product_id = p.id
GROUP BY p.id, p.foss_pid, pi.description_short
ORDER BY p.foss_pid
LIMIT 20;

-- =====================================================================
-- Query 5: Get Filter Facets (Value Counts) for UI
-- =====================================================================
-- Show available filter values with product counts (for building UI)

-- IP Rating facets
SELECT
  filter_value as ip_rating,
  product_count
FROM search.filter_facets
WHERE filter_key = 'ip'
ORDER BY product_count DESC;

-- CCT range
SELECT
  filter_value as cct_range,
  min_numeric_value,
  max_numeric_value,
  product_count
FROM search.filter_facets
WHERE filter_key = 'cct';

-- Finishing Colour facets
SELECT
  filter_value as colour,
  product_count
FROM search.filter_facets
WHERE filter_key = 'finishing_colour'
ORDER BY product_count DESC
LIMIT 20;

-- =====================================================================
-- Query 6: Performance Test (Multi-Filter Query)
-- =====================================================================
-- Test query performance with multiple filters
-- Expected: < 200ms for indexed queries

EXPLAIN ANALYZE
SELECT DISTINCT
  p.id,
  p.foss_pid,
  pi.description_short
FROM items.product p
JOIN items.product_info pi ON pi.product_id = p.id
WHERE
  -- IP65 filter
  EXISTS (
    SELECT 1 FROM search.product_filter_index pfi
    WHERE pfi.product_id = p.id
      AND pfi.filter_key = 'ip'
      AND pfi.alphanumeric_value = 'IP65'
  )
  -- CCT 3000K filter
  AND EXISTS (
    SELECT 1 FROM search.product_filter_index pfi
    WHERE pfi.product_id = p.id
      AND pfi.filter_key = 'cct'
      AND pfi.numeric_value = 3000
  )
  -- Dimmable filter
  AND EXISTS (
    SELECT 1 FROM search.product_filter_index pfi
    WHERE pfi.product_id = p.id
      AND pfi.filter_key = 'dimmable'
      AND pfi.boolean_value = true
  )
LIMIT 50;

-- =====================================================================
-- Query 7: Get All Available Filters for Category
-- =====================================================================
-- Retrieve filter configuration for UI rendering (grouped by category)

SELECT
  ui_config->>'filter_category' as category,
  filter_key,
  label,
  filter_type,
  ui_component,
  ui_config,
  display_order
FROM search.filter_definitions
WHERE applicable_taxonomy_codes @> ARRAY['LUMINAIRE']::text[]
  AND active = true
ORDER BY
  CASE ui_config->>'filter_category'
    WHEN 'electricals' THEN 1
    WHEN 'design' THEN 2
    WHEN 'light_engine' THEN 3
    ELSE 4
  END,
  display_order;

-- =====================================================================
-- Query 8: Get Available Filter Values for Dynamic Faceting
-- =====================================================================
-- When user applies filters, show what values are still available

-- Example: User selected IP65, show available CCT values for IP65 products
WITH ip65_products AS (
  SELECT DISTINCT product_id
  FROM search.product_filter_index
  WHERE filter_key = 'ip' AND alphanumeric_value = 'IP65'
)
SELECT
  pfi.numeric_value as cct_value,
  COUNT(*) as product_count
FROM search.product_filter_index pfi
JOIN ip65_products ON ip65_products.product_id = pfi.product_id
WHERE pfi.filter_key = 'cct'
  AND pfi.numeric_value IS NOT NULL
GROUP BY pfi.numeric_value
ORDER BY product_count DESC, pfi.numeric_value;

-- =====================================================================
-- Query 9: Search + Filter Combination
-- =====================================================================
-- Combine text search with filters (typical user workflow)

SELECT DISTINCT
  p.id,
  p.foss_pid,
  pi.description_short,
  ts_rank(pi.search_vector, plainto_tsquery('english', 'downlight')) as rank
FROM items.product p
JOIN items.product_info pi ON pi.product_id = p.id
WHERE
  -- Text search: "downlight"
  pi.search_vector @@ plainto_tsquery('english', 'downlight')
  -- Filter: IP65
  AND EXISTS (
    SELECT 1 FROM search.product_filter_index pfi
    WHERE pfi.product_id = p.id
      AND pfi.filter_key = 'ip'
      AND pfi.alphanumeric_value = 'IP65'
  )
  -- Filter: CCT range 2700-4000K
  AND EXISTS (
    SELECT 1 FROM search.product_filter_index pfi
    WHERE pfi.product_id = p.id
      AND pfi.filter_key = 'cct'
      AND pfi.numeric_value BETWEEN 2700 AND 4000
  )
ORDER BY rank DESC
LIMIT 20;

-- =====================================================================
-- Query 10: Delta-Style Universal Filter Test
-- =====================================================================
-- Show that filters return 0 results for non-applicable products
-- (e.g., "Min. recessed depth" for non-recessed luminaires)

-- Count products with recessed depth feature
SELECT
  'Products with recessed depth' as metric,
  COUNT(DISTINCT product_id) as count
FROM search.product_filter_index
WHERE filter_key = 'builtin_height'  -- If you enabled Phase 3

UNION ALL

-- Count total luminaires
SELECT
  'Total luminaires in index' as metric,
  COUNT(DISTINCT product_id) as count
FROM search.product_filter_index;

-- This demonstrates Delta's approach: Show filter always, return 0 if not applicable

-- =====================================================================
-- Query 11: Refresh Materialized View (Maintenance)
-- =====================================================================
-- Run this after catalog imports to update filter facets

REFRESH MATERIALIZED VIEW search.filter_facets;
ANALYZE search.filter_facets;

-- =====================================================================
-- Query 12: Monitor Index Health
-- =====================================================================

SELECT
  'product_filter_index' as table_name,
  pg_size_pretty(pg_total_relation_size('search.product_filter_index')) as size,
  (SELECT COUNT(*) FROM search.product_filter_index) as row_count,
  (SELECT COUNT(DISTINCT product_id) FROM search.product_filter_index) as unique_products;

SELECT
  'filter_facets' as view_name,
  pg_size_pretty(pg_total_relation_size('search.filter_facets')) as size,
  (SELECT COUNT(*) FROM search.filter_facets) as facet_count;

-- =====================================================================
-- Completion Message
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Test queries ready!';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Available test scenarios:';
  RAISE NOTICE '   1. Simple multi-select (IP rating)';
  RAISE NOTICE '   2. Range filter (CCT)';
  RAISE NOTICE '   3. Boolean filter (Dimmable)';
  RAISE NOTICE '   4. Combined filters (AND logic)';
  RAISE NOTICE '   5. Filter facets (value counts)';
  RAISE NOTICE '   6. Performance test (EXPLAIN ANALYZE)';
  RAISE NOTICE '   7. Filter configuration for UI';
  RAISE NOTICE '   8. Dynamic faceting (filtered counts)';
  RAISE NOTICE '   9. Search + filters combined';
  RAISE NOTICE '   10. Universal filter strategy test';
  RAISE NOTICE '   11. Materialized view refresh';
  RAISE NOTICE '   12. Index health monitoring';
  RAISE NOTICE '';
  RAISE NOTICE '💡 Expected performance: <200ms for most queries';
END $$;
