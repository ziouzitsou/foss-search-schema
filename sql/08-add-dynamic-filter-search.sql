-- =====================================================================
-- 08-add-dynamic-filter-search.sql
-- =====================================================================
-- Adds enhanced search function supporting dynamic Delta-style filters
-- =====================================================================

-- Drop existing function to avoid conflicts
DROP FUNCTION IF EXISTS search.search_products_with_filters(
    TEXT, JSONB, TEXT[], TEXT[], TEXT, INTEGER, INTEGER
);

-- =====================================================================
-- ENHANCED SEARCH FUNCTION WITH DYNAMIC FILTERS
-- =====================================================================

CREATE OR REPLACE FUNCTION search.search_products_with_filters(
    p_query TEXT DEFAULT NULL,
    p_filters JSONB DEFAULT '{}'::JSONB,
    p_taxonomy_codes TEXT[] DEFAULT NULL,
    p_suppliers TEXT[] DEFAULT NULL,
    p_indoor BOOLEAN DEFAULT NULL,
    p_outdoor BOOLEAN DEFAULT NULL,
    p_submersible BOOLEAN DEFAULT NULL,
    p_trimless BOOLEAN DEFAULT NULL,
    p_cut_shape_round BOOLEAN DEFAULT NULL,
    p_cut_shape_rectangular BOOLEAN DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'relevance',
    p_limit INTEGER DEFAULT 24,
    p_offset INTEGER DEFAULT 0
) RETURNS TABLE (
    product_id UUID,
    foss_pid TEXT,
    description_short TEXT,
    description_long TEXT,
    supplier_name TEXT,
    class_name TEXT,
    price NUMERIC,
    image_url TEXT,
    taxonomy_path TEXT[],
    flags JSONB,
    key_features JSONB,
    relevance_score INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        pi.product_id,
        pi.foss_pid,
        pi.description_short,
        pi.description_long,
        pi.supplier_name,
        pi.class_name,
        (pi.prices->0->>'start_price')::NUMERIC as price,
        (SELECT elem->>'mime_source' FROM jsonb_array_elements(pi.multimedia) AS elem WHERE elem->>'mime_code' = 'MD01' LIMIT 1) as image_url,
        ptf.taxonomy_path,
        jsonb_build_object(
            'indoor', ptf.indoor,
            'outdoor', ptf.outdoor,
            'ceiling', ptf.ceiling,
            'wall', ptf.wall,
            'pendant', ptf.pendant,
            'recessed', ptf.recessed,
            'dimmable', ptf.dimmable,
            'submersible', ptf.submersible,
            'trimless', ptf.trimless,
            'cut_shape_round', ptf.cut_shape_round,
            'cut_shape_rectangular', ptf.cut_shape_rectangular
        ) as flags,
        jsonb_build_object(
            'voltage', (SELECT pfi.alphanumeric_value FROM search.product_filter_index pfi
                       WHERE pfi.product_id = pi.product_id AND pfi.filter_key = 'voltage' LIMIT 1),
            'class', (SELECT pfi.alphanumeric_value FROM search.product_filter_index pfi
                     WHERE pfi.product_id = pi.product_id AND pfi.filter_key = 'class' LIMIT 1),
            'ip', (SELECT pfi.alphanumeric_value FROM search.product_filter_index pfi
                  WHERE pfi.product_id = pi.product_id AND pfi.filter_key = 'ip' LIMIT 1),
            'finishing_colour', (SELECT pfi.alphanumeric_value FROM search.product_filter_index pfi
                               WHERE pfi.product_id = pi.product_id AND pfi.filter_key = 'finishing_colour' LIMIT 1),
            'cct', (SELECT pfi.numeric_value FROM search.product_filter_index pfi
                   WHERE pfi.product_id = pi.product_id AND pfi.filter_key = 'cct' LIMIT 1),
            'cri', (SELECT pfi.alphanumeric_value FROM search.product_filter_index pfi
                   WHERE pfi.product_id = pi.product_id AND pfi.filter_key = 'cri' LIMIT 1),
            'lumens_output', (SELECT pfi.numeric_value FROM search.product_filter_index pfi
                            WHERE pfi.product_id = pi.product_id AND pfi.filter_key = 'lumens_output' LIMIT 1)
        ) as key_features,
        CASE
            WHEN p_query IS NOT NULL AND pi.description_short ILIKE p_query THEN 1
            WHEN p_query IS NOT NULL AND pi.description_short ILIKE '%' || p_query || '%' THEN 2
            ELSE 3
        END as relevance_score
    FROM items.product_info pi
    INNER JOIN search.product_taxonomy_flags ptf ON pi.product_id = ptf.product_id
    WHERE
        -- Text search
        (p_query IS NULL OR
         pi.description_short ILIKE '%' || p_query || '%' OR
         pi.description_long ILIKE '%' || p_query || '%')

        -- Taxonomy filter
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

        -- DYNAMIC FILTERS FROM p_filters JSONB

        -- voltage (multi-select alphanumeric)
        AND (NOT (p_filters ? 'voltage') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'voltage'
              AND pfi.alphanumeric_value = ANY(
                  ARRAY(SELECT jsonb_array_elements_text(p_filters->'voltage'))
              )
        ))

        -- dimmable (boolean)
        AND (NOT (p_filters ? 'dimmable') OR
             (p_filters->>'dimmable')::BOOLEAN = ptf.dimmable)

        -- class / Protection Class (multi-select alphanumeric)
        AND (NOT (p_filters ? 'class') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'class'
              AND pfi.alphanumeric_value = ANY(
                  ARRAY(SELECT jsonb_array_elements_text(p_filters->'class'))
              )
        ))

        -- ip (multi-select alphanumeric)
        AND (NOT (p_filters ? 'ip') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'ip'
              AND pfi.alphanumeric_value = ANY(
                  ARRAY(SELECT jsonb_array_elements_text(p_filters->'ip'))
              )
        ))

        -- finishing_colour (multi-select alphanumeric)
        AND (NOT (p_filters ? 'finishing_colour') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'finishing_colour'
              AND pfi.alphanumeric_value = ANY(
                  ARRAY(SELECT jsonb_array_elements_text(p_filters->'finishing_colour'))
              )
        ))

        -- cct (range numeric)
        AND (NOT (p_filters->'cct' ? 'min') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'cct'
              AND pfi.numeric_value >= (p_filters->'cct'->>'min')::NUMERIC
        ))
        AND (NOT (p_filters->'cct' ? 'max') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'cct'
              AND pfi.numeric_value <= (p_filters->'cct'->>'max')::NUMERIC
        ))

        -- cri (multi-select alphanumeric)
        AND (NOT (p_filters ? 'cri') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'cri'
              AND pfi.alphanumeric_value = ANY(
                  ARRAY(SELECT jsonb_array_elements_text(p_filters->'cri'))
              )
        ))

        -- lumens_output (range numeric)
        AND (NOT (p_filters->'lumens_output' ? 'min') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'lumens_output'
              AND pfi.numeric_value >= (p_filters->'lumens_output'->>'min')::NUMERIC
        ))
        AND (NOT (p_filters->'lumens_output' ? 'max') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'lumens_output'
              AND pfi.numeric_value <= (p_filters->'lumens_output'->>'max')::NUMERIC
        ))

    ORDER BY
        CASE
            WHEN p_sort_by = 'relevance' THEN relevance_score
            WHEN p_sort_by = 'price_asc' THEN (pi.prices->0->>'start_price')::INTEGER
            WHEN p_sort_by = 'price_desc' THEN -(pi.prices->0->>'start_price')::INTEGER
            ELSE relevance_score
        END,
        pi.foss_pid

    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION search.search_products_with_filters IS
'Enhanced search function supporting dynamic Delta-style filters via JSONB parameter.
Handles multi-select, range, and boolean filters from the FilterPanel component.

Example usage:
SELECT * FROM search.search_products_with_filters(
    p_query := ''LED'',
    p_filters := ''{"ip": ["IP65", "IP20"], "dimmable": true, "cct": {"min": 2700, "max": 3000}}''::JSONB,
    p_taxonomy_codes := ARRAY[''LUMINAIRE''],
    p_limit := 24
);';

-- =====================================================================
-- COUNT FUNCTION WITH DYNAMIC FILTERS
-- =====================================================================

CREATE OR REPLACE FUNCTION search.count_products_with_filters(
    p_query TEXT DEFAULT NULL,
    p_filters JSONB DEFAULT '{}'::JSONB,
    p_taxonomy_codes TEXT[] DEFAULT NULL,
    p_suppliers TEXT[] DEFAULT NULL,
    p_indoor BOOLEAN DEFAULT NULL,
    p_outdoor BOOLEAN DEFAULT NULL,
    p_submersible BOOLEAN DEFAULT NULL,
    p_trimless BOOLEAN DEFAULT NULL,
    p_cut_shape_round BOOLEAN DEFAULT NULL,
    p_cut_shape_rectangular BOOLEAN DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE
    v_count BIGINT;
BEGIN
    SELECT COUNT(DISTINCT pi.product_id)
    INTO v_count
    FROM items.product_info pi
    INNER JOIN search.product_taxonomy_flags ptf ON pi.product_id = ptf.product_id
    WHERE
        -- Text search
        (p_query IS NULL OR
         pi.description_short ILIKE '%' || p_query || '%' OR
         pi.description_long ILIKE '%' || p_query || '%')

        -- Taxonomy filter
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

        -- DYNAMIC FILTERS (same logic as search function)
        AND (NOT (p_filters ? 'voltage') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'voltage'
              AND pfi.alphanumeric_value = ANY(
                  ARRAY(SELECT jsonb_array_elements_text(p_filters->'voltage'))
              )
        ))
        AND (NOT (p_filters ? 'dimmable') OR
             (p_filters->>'dimmable')::BOOLEAN = ptf.dimmable)
        AND (NOT (p_filters ? 'class') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'class'
              AND pfi.alphanumeric_value = ANY(
                  ARRAY(SELECT jsonb_array_elements_text(p_filters->'class'))
              )
        ))
        AND (NOT (p_filters ? 'ip') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'ip'
              AND pfi.alphanumeric_value = ANY(
                  ARRAY(SELECT jsonb_array_elements_text(p_filters->'ip'))
              )
        ))
        AND (NOT (p_filters ? 'finishing_colour') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'finishing_colour'
              AND pfi.alphanumeric_value = ANY(
                  ARRAY(SELECT jsonb_array_elements_text(p_filters->'finishing_colour'))
              )
        ))
        AND (NOT (p_filters->'cct' ? 'min') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'cct'
              AND pfi.numeric_value >= (p_filters->'cct'->>'min')::NUMERIC
        ))
        AND (NOT (p_filters->'cct' ? 'max') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'cct'
              AND pfi.numeric_value <= (p_filters->'cct'->>'max')::NUMERIC
        ))
        AND (NOT (p_filters ? 'cri') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'cri'
              AND pfi.alphanumeric_value = ANY(
                  ARRAY(SELECT jsonb_array_elements_text(p_filters->'cri'))
              )
        ))
        AND (NOT (p_filters->'lumens_output' ? 'min') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'lumens_output'
              AND pfi.numeric_value >= (p_filters->'lumens_output'->>'min')::NUMERIC
        ))
        AND (NOT (p_filters->'lumens_output' ? 'max') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'lumens_output'
              AND pfi.numeric_value <= (p_filters->'lumens_output'->>'max')::NUMERIC
        ));

    RETURN v_count;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION search.count_products_with_filters IS
'Counts products matching dynamic filter criteria. Used with search_products_with_filters.';

-- =====================================================================
-- CREATE PUBLIC WRAPPERS FOR SUPABASE CLIENT
-- =====================================================================

-- Public wrapper for search function
CREATE OR REPLACE FUNCTION public.search_products_with_filters(
    p_query TEXT DEFAULT NULL,
    p_filters JSONB DEFAULT '{}'::JSONB,
    p_taxonomy_codes TEXT[] DEFAULT NULL,
    p_suppliers TEXT[] DEFAULT NULL,
    p_indoor BOOLEAN DEFAULT NULL,
    p_outdoor BOOLEAN DEFAULT NULL,
    p_submersible BOOLEAN DEFAULT NULL,
    p_trimless BOOLEAN DEFAULT NULL,
    p_cut_shape_round BOOLEAN DEFAULT NULL,
    p_cut_shape_rectangular BOOLEAN DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'relevance',
    p_limit INTEGER DEFAULT 24,
    p_offset INTEGER DEFAULT 0
) RETURNS SETOF search.search_products_with_filters AS $$
    SELECT * FROM search.search_products_with_filters(
        p_query, p_filters, p_taxonomy_codes, p_suppliers,
        p_indoor, p_outdoor, p_submersible, p_trimless,
        p_cut_shape_round, p_cut_shape_rectangular,
        p_sort_by, p_limit, p_offset
    );
$$ LANGUAGE sql STABLE;

-- Public wrapper for count function
CREATE OR REPLACE FUNCTION public.count_products_with_filters(
    p_query TEXT DEFAULT NULL,
    p_filters JSONB DEFAULT '{}'::JSONB,
    p_taxonomy_codes TEXT[] DEFAULT NULL,
    p_suppliers TEXT[] DEFAULT NULL,
    p_indoor BOOLEAN DEFAULT NULL,
    p_outdoor BOOLEAN DEFAULT NULL,
    p_submersible BOOLEAN DEFAULT NULL,
    p_trimless BOOLEAN DEFAULT NULL,
    p_cut_shape_round BOOLEAN DEFAULT NULL,
    p_cut_shape_rectangular BOOLEAN DEFAULT NULL
) RETURNS BIGINT AS $$
    SELECT search.count_products_with_filters(
        p_query, p_filters, p_taxonomy_codes, p_suppliers,
        p_indoor, p_outdoor, p_submersible, p_trimless,
        p_cut_shape_round, p_cut_shape_rectangular
    );
$$ LANGUAGE sql STABLE;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.search_products_with_filters TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.count_products_with_filters TO anon, authenticated;

-- =====================================================================
-- SUCCESS MESSAGE
-- =====================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=======================================================================';
    RAISE NOTICE 'Dynamic filter search functions created successfully!';
    RAISE NOTICE '=======================================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'New functions available:';
    RAISE NOTICE '  ✓ search_products_with_filters() - Search with Delta-style filters';
    RAISE NOTICE '  ✓ count_products_with_filters() - Count matching products';
    RAISE NOTICE '';
    RAISE NOTICE 'Test example:';
    RAISE NOTICE '  SELECT * FROM search_products_with_filters(';
    RAISE NOTICE '    p_filters := ''{"ip": ["IP65"], "dimmable": true}''::JSONB,';
    RAISE NOTICE '    p_taxonomy_codes := ARRAY[''LUMINAIRE''],';
    RAISE NOTICE '    p_limit := 10';
    RAISE NOTICE '  );';
    RAISE NOTICE '';
    RAISE NOTICE '=======================================================================';
END $$;
