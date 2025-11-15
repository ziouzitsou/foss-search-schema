-- =====================================================================
-- 09-add-dynamic-facets.sql
-- =====================================================================
-- Adds function to get dynamic filter facets based on current selection
-- =====================================================================

-- =====================================================================
-- DYNAMIC FACETS FUNCTION
-- =====================================================================
-- This function calculates facet counts based on currently selected
-- taxonomy and filters, showing users what options are available
-- in their current filtered result set.
-- =====================================================================

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

    -- Now get facets from the filtered product set
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

    ORDER BY filter_category, filter_key, product_count DESC;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION search.get_dynamic_facets IS
'Returns available filter options and their product counts based on current taxonomy
and filter selection. This enables "faceted search" where filter counts update
dynamically as users refine their selection.

Example usage:
SELECT * FROM search.get_dynamic_facets(
    p_taxonomy_codes := ARRAY[''LUMINAIRE-CEILING-SURFACE''],
    p_filters := ''{}''::JSONB
);
';

-- =====================================================================
-- CREATE PUBLIC WRAPPER FOR SUPABASE CLIENT
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
-- SUCCESS MESSAGE
-- =====================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=======================================================================';
    RAISE NOTICE 'Dynamic facets function created successfully!';
    RAISE NOTICE '=======================================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'New function available:';
    RAISE NOTICE '  ✓ get_dynamic_facets() - Get filter options with dynamic counts';
    RAISE NOTICE '';
    RAISE NOTICE 'This function returns facets filtered by:';
    RAISE NOTICE '  • Selected taxonomy (category)';
    RAISE NOTICE '  • Current filter selections';
    RAISE NOTICE '  • Text search query';
    RAISE NOTICE '';
    RAISE NOTICE 'Test example:';
    RAISE NOTICE '  SELECT * FROM get_dynamic_facets(';
    RAISE NOTICE '    p_taxonomy_codes := ARRAY[''LUMINAIRE-CEILING-SURFACE'']';
    RAISE NOTICE '  );';
    RAISE NOTICE '';
    RAISE NOTICE '=======================================================================';
END $$;
