-- =====================================================
-- File: 12-update-dynamic-facets-for-flags.sql
-- Purpose: Update get_dynamic_facets to include flag-based boolean filters
-- Created: 2025-01-21
-- Bug Fix: Location/options filters not showing counts
-- =====================================================

-- Problem:
-- - get_dynamic_facets() only returns facets from product_filter_index
-- - Flag-based filters (indoor, outdoor, submersible, trimless, cut_shape_round, cut_shape_rectangular)
--   are in product_taxonomy_flags, not product_filter_index
-- - Result: BooleanFilter component has no facets to render (no Yes/No options with counts)

-- Solution:
-- - Update get_dynamic_facets() to UNION two queries:
--   1. ETIM-based filters from product_filter_index (existing logic)
--   2. Flag-based filters from product_taxonomy_flags (new logic)

CREATE OR REPLACE FUNCTION search.get_dynamic_facets(
    p_taxonomy_codes TEXT[] DEFAULT NULL,
    p_filters JSONB DEFAULT '{}'::JSONB,
    p_suppliers TEXT[] DEFAULT NULL,
    p_indoor BOOLEAN DEFAULT NULL,
    p_outdoor BOOLEAN DEFAULT NULL,
    p_submersible BOOLEAN DEFAULT NULL,
    p_trimless BOOLEAN DEFAULT NULL,
    p_cut_shape_round BOOLEAN DEFAULT NULL,
    p_cut_shape_rectangular BOOLEAN DEFAULT NULL,
    p_query TEXT DEFAULT NULL
) RETURNS TABLE (
    filter_category TEXT,
    filter_key TEXT,
    filter_value TEXT,
    product_count BIGINT
) AS $$
BEGIN
    RETURN QUERY

    -- Get all available filter values with counts from products matching current criteria
    WITH filtered_products AS (
        SELECT DISTINCT pi.product_id
        FROM items.product_info pi
        INNER JOIN search.product_taxonomy_flags ptf ON pi.product_id = ptf.product_id
        WHERE
            -- Text search
            (p_query IS NULL OR
             pi.description_short ILIKE '%' || p_query || '%' OR
             pi.description_long ILIKE '%' || p_query || '%')

            -- Taxonomy filter (THIS IS THE KEY - only products in selected taxonomy)
            AND (p_taxonomy_codes IS NULL OR ptf.taxonomy_path && p_taxonomy_codes)

            -- Boolean flags from UI
            AND (p_indoor IS NULL OR ptf.indoor = p_indoor)
            AND (p_outdoor IS NULL OR ptf.outdoor = p_outdoor)
            AND (p_submersible IS NULL OR ptf.submersible = p_submersible)
            AND (p_trimless IS NULL OR ptf.trimless = p_trimless)
            AND (p_cut_shape_round IS NULL OR ptf.cut_shape_round = p_cut_shape_round)
            AND (p_cut_shape_rectangular IS NULL OR ptf.cut_shape_rectangular = p_cut_shape_rectangular)

            -- Supplier filter
            AND (p_suppliers IS NULL OR pi.supplier_name = ANY(p_suppliers))
    )

    -- Part 1: ETIM-based facets from product_filter_index (existing logic)
    SELECT
        fd.ui_config->>'filter_category' as filter_category,
        pfi.filter_key,
        COALESCE(pfi.alphanumeric_value, pfi.boolean_value::TEXT) as filter_value,
        COUNT(DISTINCT pfi.product_id) as product_count
    FROM search.product_filter_index pfi
    INNER JOIN filtered_products fp ON pfi.product_id = fp.product_id
    INNER JOIN search.filter_definitions fd ON pfi.filter_key = fd.filter_key
    WHERE
        fd.active = true
        AND (
            -- For multi-select filters, include all alphanumeric values
            (fd.filter_type = 'multi-select' AND pfi.alphanumeric_value IS NOT NULL)
            -- For boolean filters, include Yes/No
            OR (fd.filter_type = 'boolean' AND pfi.boolean_value IS NOT NULL)
        )
    GROUP BY
        fd.ui_config->>'filter_category',
        pfi.filter_key,
        pfi.alphanumeric_value,
        pfi.boolean_value

    UNION ALL

    -- Part 2: Flag-based boolean filters from product_taxonomy_flags (new logic)
    -- Indoor filter
    SELECT
        'location'::TEXT as filter_category,
        'indoor'::TEXT as filter_key,
        'Yes'::TEXT as filter_value,
        COUNT(DISTINCT ptf.product_id) as product_count
    FROM search.product_taxonomy_flags ptf
    INNER JOIN filtered_products fp ON ptf.product_id = fp.product_id
    WHERE ptf.indoor = true

    UNION ALL

    SELECT
        'location'::TEXT,
        'indoor'::TEXT,
        'No'::TEXT,
        COUNT(DISTINCT ptf.product_id)
    FROM search.product_taxonomy_flags ptf
    INNER JOIN filtered_products fp ON ptf.product_id = fp.product_id
    WHERE ptf.indoor = false

    UNION ALL

    -- Outdoor filter
    SELECT
        'location'::TEXT,
        'outdoor'::TEXT,
        'Yes'::TEXT,
        COUNT(DISTINCT ptf.product_id)
    FROM search.product_taxonomy_flags ptf
    INNER JOIN filtered_products fp ON ptf.product_id = fp.product_id
    WHERE ptf.outdoor = true

    UNION ALL

    SELECT
        'location'::TEXT,
        'outdoor'::TEXT,
        'No'::TEXT,
        COUNT(DISTINCT ptf.product_id)
    FROM search.product_taxonomy_flags ptf
    INNER JOIN filtered_products fp ON ptf.product_id = fp.product_id
    WHERE ptf.outdoor = false

    UNION ALL

    -- Submersible filter
    SELECT
        'location'::TEXT,
        'submersible'::TEXT,
        'Yes'::TEXT,
        COUNT(DISTINCT ptf.product_id)
    FROM search.product_taxonomy_flags ptf
    INNER JOIN filtered_products fp ON ptf.product_id = fp.product_id
    WHERE ptf.submersible = true

    UNION ALL

    SELECT
        'location'::TEXT,
        'submersible'::TEXT,
        'No'::TEXT,
        COUNT(DISTINCT ptf.product_id)
    FROM search.product_taxonomy_flags ptf
    INNER JOIN filtered_products fp ON ptf.product_id = fp.product_id
    WHERE ptf.submersible = false

    UNION ALL

    -- Trimless filter
    SELECT
        'options'::TEXT,
        'trimless'::TEXT,
        'Yes'::TEXT,
        COUNT(DISTINCT ptf.product_id)
    FROM search.product_taxonomy_flags ptf
    INNER JOIN filtered_products fp ON ptf.product_id = fp.product_id
    WHERE ptf.trimless = true

    UNION ALL

    SELECT
        'options'::TEXT,
        'trimless'::TEXT,
        'No'::TEXT,
        COUNT(DISTINCT ptf.product_id)
    FROM search.product_taxonomy_flags ptf
    INNER JOIN filtered_products fp ON ptf.product_id = fp.product_id
    WHERE ptf.trimless = false

    UNION ALL

    -- Round cut filter
    SELECT
        'options'::TEXT,
        'cut_shape_round'::TEXT,
        'Yes'::TEXT,
        COUNT(DISTINCT ptf.product_id)
    FROM search.product_taxonomy_flags ptf
    INNER JOIN filtered_products fp ON ptf.product_id = fp.product_id
    WHERE ptf.cut_shape_round = true

    UNION ALL

    SELECT
        'options'::TEXT,
        'cut_shape_round'::TEXT,
        'No'::TEXT,
        COUNT(DISTINCT ptf.product_id)
    FROM search.product_taxonomy_flags ptf
    INNER JOIN filtered_products fp ON ptf.product_id = fp.product_id
    WHERE ptf.cut_shape_round = false

    UNION ALL

    -- Rectangular cut filter
    SELECT
        'options'::TEXT,
        'cut_shape_rectangular'::TEXT,
        'Yes'::TEXT,
        COUNT(DISTINCT ptf.product_id)
    FROM search.product_taxonomy_flags ptf
    INNER JOIN filtered_products fp ON ptf.product_id = fp.product_id
    WHERE ptf.cut_shape_rectangular = true

    UNION ALL

    SELECT
        'options'::TEXT,
        'cut_shape_rectangular'::TEXT,
        'No'::TEXT,
        COUNT(DISTINCT ptf.product_id)
    FROM search.product_taxonomy_flags ptf
    INNER JOIN filtered_products fp ON ptf.product_id = fp.product_id
    WHERE ptf.cut_shape_rectangular = false

    ORDER BY filter_category, filter_key, product_count DESC;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION search.get_dynamic_facets IS
'Returns available filter options and their product counts based on current taxonomy
and filter selection. This enables "faceted search" where filter counts update
dynamically as users refine their selection.

Now includes BOTH:
1. ETIM-based filters (from product_filter_index)
2. Flag-based boolean filters (from product_taxonomy_flags)

Example usage:
SELECT * FROM search.get_dynamic_facets(
    p_taxonomy_codes := ARRAY[''LUMINAIRE-CEILING-SURFACE''],
    p_filters := ''{}''::JSONB
);
';

-- =====================================================================
-- UPDATE PUBLIC WRAPPER (no changes needed, just for completeness)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.get_dynamic_facets(
    p_taxonomy_codes TEXT[] DEFAULT NULL,
    p_filters JSONB DEFAULT '{}'::JSONB,
    p_suppliers TEXT[] DEFAULT NULL,
    p_indoor BOOLEAN DEFAULT NULL,
    p_outdoor BOOLEAN DEFAULT NULL,
    p_submersible BOOLEAN DEFAULT NULL,
    p_trimless BOOLEAN DEFAULT NULL,
    p_cut_shape_round BOOLEAN DEFAULT NULL,
    p_cut_shape_rectangular BOOLEAN DEFAULT NULL,
    p_query TEXT DEFAULT NULL
) RETURNS TABLE (
    filter_category TEXT,
    filter_key TEXT,
    filter_value TEXT,
    product_count BIGINT
) AS $$
    SELECT * FROM search.get_dynamic_facets(
        p_taxonomy_codes, p_filters, p_suppliers,
        p_indoor, p_outdoor, p_submersible, p_trimless,
        p_cut_shape_round, p_cut_shape_rectangular,
        p_query
    );
$$ LANGUAGE sql STABLE;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_dynamic_facets TO anon, authenticated;

-- =====================================================================
-- VERIFICATION QUERY
-- =====================================================================

DO $$
DECLARE
    v_location_count INTEGER;
    v_options_count INTEGER;
BEGIN
    -- Count flag-based facets returned
    SELECT COUNT(*) INTO v_location_count
    FROM search.get_dynamic_facets(
        p_taxonomy_codes := ARRAY['LUMINAIRE']
    )
    WHERE filter_category = 'location';

    SELECT COUNT(*) INTO v_options_count
    FROM search.get_dynamic_facets(
        p_taxonomy_codes := ARRAY['LUMINAIRE']
    )
    WHERE filter_category = 'options';

    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Dynamic Facets Function Updated Successfully!';
    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Flag-based facets returned:';
    RAISE NOTICE '  Location facets: % (should be 6: Indoor Yes/No, Outdoor Yes/No, Submersible Yes/No)', v_location_count;
    RAISE NOTICE '  Options facets: % (should be 6: Trimless Yes/No, Round Cut Yes/No, Rect Cut Yes/No)', v_options_count;
    RAISE NOTICE '';

    IF v_location_count = 6 AND v_options_count = 6 THEN
        RAISE NOTICE '✅ Flag-based filters working correctly!';
    ELSE
        RAISE NOTICE '⚠️  Expected 6 location facets and 6 options facets';
    END IF;

    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
END $$;
