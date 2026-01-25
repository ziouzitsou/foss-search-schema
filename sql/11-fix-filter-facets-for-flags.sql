-- =====================================================
-- File: 11-fix-filter-facets-for-flags.sql
-- Purpose: Update filter_facets to include flag-based boolean filters
-- Created: 2025-01-21
-- Bug Fix: Location/options filters showing zero counts
-- =====================================================

-- Problem:
-- - Location/options filters (indoor, outdoor, submersible, trimless, cut_shape_round, cut_shape_rectangular)
--   have etim_feature_id = NULL and etim_feature_type = 'L' (Logical/flag-based)
-- - Original filter_facets view only calculates from product_filter_index
-- - product_filter_index only includes ETIM-based filters (requires etim_feature_id)
-- - Result: Flag-based filters show zero counts despite populated data in product_taxonomy_flags

-- Solution:
-- - Rebuild filter_facets to UNION two sources:
--   1. ETIM-based filters from product_filter_index (existing logic)
--   2. Flag-based filters from product_taxonomy_flags (new logic)

-- Drop existing materialized view
DROP MATERIALIZED VIEW IF EXISTS search.filter_facets;

-- Recreate with flag support
CREATE MATERIALIZED VIEW search.filter_facets AS

-- Part 1: ETIM-based filters (from product_filter_index)
SELECT
    filter_key,
    filter_type,

    -- For numeric filters: min, max, histogram
    CASE WHEN filter_type = 'numeric_range' THEN
        jsonb_build_object(
            'min', MIN(numeric_value),
            'max', MAX(numeric_value),
            'avg', AVG(numeric_value),
            'count', COUNT(DISTINCT product_id),
            'histogram', search.build_histogram(array_agg(DISTINCT numeric_value), 10)
        )
    ELSE NULL END AS numeric_stats,

    -- For alphanumeric filters: value counts
    CASE WHEN filter_type = 'alphanumeric' THEN
        jsonb_object_agg(
            alphanumeric_value,
            value_count
        ) FILTER (WHERE alphanumeric_value IS NOT NULL)
    ELSE NULL END AS alphanumeric_counts,

    -- For boolean filters: true count
    CASE WHEN filter_type = 'boolean' THEN
        COUNT(DISTINCT product_id) FILTER (WHERE boolean_value = true)
    ELSE NULL END AS boolean_true_count,

    -- Total products with this filter
    COUNT(DISTINCT product_id) as total_products

FROM (
    SELECT
        filter_key,
        filter_type,
        product_id,
        numeric_value,
        alphanumeric_value,
        boolean_value,
        COUNT(*) as value_count
    FROM search.product_filter_index
    GROUP BY filter_key, filter_type, product_id, numeric_value, alphanumeric_value, boolean_value
) etim_filters
GROUP BY filter_key, filter_type

UNION ALL

-- Part 2: Flag-based boolean filters (from product_taxonomy_flags)
-- These are filters with etim_feature_type = 'L' (Logical) and no ETIM feature ID
SELECT
    fd.filter_key,
    fd.filter_type,
    NULL::jsonb AS numeric_stats,
    NULL::jsonb AS alphanumeric_counts,

    -- Count products where flag = true
    CASE
        WHEN fd.filter_key = 'indoor' THEN
            COUNT(*) FILTER (WHERE ptf.indoor = true)
        WHEN fd.filter_key = 'outdoor' THEN
            COUNT(*) FILTER (WHERE ptf.outdoor = true)
        WHEN fd.filter_key = 'submersible' THEN
            COUNT(*) FILTER (WHERE ptf.submersible = true)
        WHEN fd.filter_key = 'trimless' THEN
            COUNT(*) FILTER (WHERE ptf.trimless = true)
        WHEN fd.filter_key = 'cut_shape_round' THEN
            COUNT(*) FILTER (WHERE ptf.cut_shape_round = true)
        WHEN fd.filter_key = 'cut_shape_rectangular' THEN
            COUNT(*) FILTER (WHERE ptf.cut_shape_rectangular = true)
        ELSE 0
    END AS boolean_true_count,

    -- Total products (all rows in product_taxonomy_flags)
    COUNT(*) as total_products

FROM search.filter_definitions fd
CROSS JOIN search.product_taxonomy_flags ptf
WHERE fd.etim_feature_type = 'L'  -- Flag-based filters
  AND fd.etim_feature_id IS NULL  -- Not ETIM-based
  AND fd.active = true
GROUP BY fd.filter_key, fd.filter_type;

-- Create index
CREATE UNIQUE INDEX idx_filter_facets_key ON search.filter_facets(filter_key);

COMMENT ON MATERIALIZED VIEW search.filter_facets IS
'Aggregated facet counts and statistics for filter UI. Includes both ETIM-based
filters (from product_filter_index) and flag-based filters (from product_taxonomy_flags).
Shows available filter options and product counts before user applies filters.';

-- =====================================================
-- Refresh and verify
-- =====================================================

-- Refresh the view immediately
REFRESH MATERIALIZED VIEW search.filter_facets;

-- Verification query
DO $$
DECLARE
    v_indoor_count INTEGER;
    v_outdoor_count INTEGER;
    v_submersible_count INTEGER;
    v_trimless_count INTEGER;
    v_round_count INTEGER;
    v_rect_count INTEGER;
BEGIN
    -- Get counts from filter_facets
    SELECT boolean_true_count INTO v_indoor_count
    FROM search.filter_facets WHERE filter_key = 'indoor';

    SELECT boolean_true_count INTO v_outdoor_count
    FROM search.filter_facets WHERE filter_key = 'outdoor';

    SELECT boolean_true_count INTO v_submersible_count
    FROM search.filter_facets WHERE filter_key = 'submersible';

    SELECT boolean_true_count INTO v_trimless_count
    FROM search.filter_facets WHERE filter_key = 'trimless';

    SELECT boolean_true_count INTO v_round_count
    FROM search.filter_facets WHERE filter_key = 'cut_shape_round';

    SELECT boolean_true_count INTO v_rect_count
    FROM search.filter_facets WHERE filter_key = 'cut_shape_rectangular';

    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Filter Facets Updated Successfully!';
    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Flag-based filter counts:';
    RAISE NOTICE '  Indoor: % products', v_indoor_count;
    RAISE NOTICE '  Outdoor: % products', v_outdoor_count;
    RAISE NOTICE '  Submersible: % products', v_submersible_count;
    RAISE NOTICE '  Trimless: % products', v_trimless_count;
    RAISE NOTICE '  Round Cut: % products', v_round_count;
    RAISE NOTICE '  Rectangular Cut: % products', v_rect_count;
    RAISE NOTICE '';

    IF v_indoor_count > 0 THEN
        RAISE NOTICE '✅ Flag-based filters working correctly!';
    ELSE
        RAISE NOTICE '⚠️  No products found - verify product_taxonomy_flags is populated';
    END IF;

    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
END $$;
