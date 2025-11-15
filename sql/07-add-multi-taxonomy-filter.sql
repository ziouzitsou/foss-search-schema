-- =====================================================================
-- 07-add-multi-taxonomy-filter.sql
-- =====================================================================
-- Updates search_products function to support multi-select taxonomy filtering
-- =====================================================================

CREATE OR REPLACE FUNCTION search.search_products(
    p_query TEXT DEFAULT NULL,
    p_indoor BOOLEAN DEFAULT NULL,
    p_outdoor BOOLEAN DEFAULT NULL,
    p_ceiling BOOLEAN DEFAULT NULL,
    p_wall BOOLEAN DEFAULT NULL,
    p_pendant BOOLEAN DEFAULT NULL,
    p_recessed BOOLEAN DEFAULT NULL,
    p_dimmable BOOLEAN DEFAULT NULL,
    p_power_min NUMERIC DEFAULT NULL,
    p_power_max NUMERIC DEFAULT NULL,
    p_color_temp_min NUMERIC DEFAULT NULL,
    p_color_temp_max NUMERIC DEFAULT NULL,
    p_ip_ratings TEXT[] DEFAULT NULL,
    p_suppliers TEXT[] DEFAULT NULL,
    p_taxonomy_codes TEXT[] DEFAULT NULL,  -- NEW: Multi-select taxonomy filter
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
    SELECT
        pi.product_id,
        pi.foss_pid,
        pi.description_short,
        pi.description_long,
        pi.supplier_name,
        pi.class_name,
        (pi.prices->0->>'start_price')::NUMERIC as price,
        (pi.multimedia->0->>'mime_source') as image_url,
        ptf.taxonomy_path,
        jsonb_build_object(
            'indoor', ptf.indoor,
            'outdoor', ptf.outdoor,
            'ceiling', ptf.ceiling,
            'wall', ptf.wall,
            'pendant', ptf.pendant,
            'recessed', ptf.recessed,
            'dimmable', ptf.dimmable
        ) as flags,
        jsonb_build_object(
            'power', (SELECT pfi.numeric_value FROM search.product_filter_index pfi
                      WHERE pfi.product_id = pi.product_id AND pfi.filter_key = 'power' LIMIT 1),
            'color_temp', (SELECT pfi.numeric_value FROM search.product_filter_index pfi
                          WHERE pfi.product_id = pi.product_id AND pfi.filter_key = 'color_temp' LIMIT 1),
            'ip_rating', (SELECT pfi.alphanumeric_value FROM search.product_filter_index pfi
                         WHERE pfi.product_id = pi.product_id AND pfi.filter_key = 'ip_rating' LIMIT 1)
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

        -- NEW: Taxonomy filter (checks if any selected taxonomy code is in the product's taxonomy path)
        AND (p_taxonomy_codes IS NULL OR
             p_taxonomy_codes = ARRAY[]::TEXT[] OR
             ptf.taxonomy_path && p_taxonomy_codes)  -- && is the array overlap operator

        -- Boolean flags
        AND (p_indoor IS NULL OR ptf.indoor = p_indoor)
        AND (p_outdoor IS NULL OR ptf.outdoor = p_outdoor)
        AND (p_ceiling IS NULL OR ptf.ceiling = p_ceiling)
        AND (p_wall IS NULL OR ptf.wall = p_wall)
        AND (p_pendant IS NULL OR ptf.pendant = p_pendant)
        AND (p_recessed IS NULL OR ptf.recessed = p_recessed)
        AND (p_dimmable IS NULL OR ptf.dimmable = p_dimmable)

        -- Numeric filters
        AND (p_power_min IS NULL OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'power'
              AND pfi.numeric_value >= p_power_min
        ))
        AND (p_power_max IS NULL OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'power'
              AND pfi.numeric_value <= p_power_max
        ))
        AND (p_color_temp_min IS NULL OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'color_temp'
              AND pfi.numeric_value >= p_color_temp_min
        ))
        AND (p_color_temp_max IS NULL OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'color_temp'
              AND pfi.numeric_value <= p_color_temp_max
        ))

        -- Alphanumeric filters
        AND (p_ip_ratings IS NULL OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'ip_rating'
              AND pfi.alphanumeric_value = ANY(p_ip_ratings)
        ))

        -- Supplier filter
        AND (p_suppliers IS NULL OR pi.supplier_name = ANY(p_suppliers))

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

COMMENT ON FUNCTION search.search_products IS
'Main search API function. Supports text search, boolean flags, numeric ranges,
alphanumeric filters, and multi-select taxonomy filtering (NEW).
Returns paginated results with relevance scoring.

The p_taxonomy_codes parameter accepts an array of taxonomy codes (e.g., [''LUM_CEIL'', ''LUM_WALL'']).
Products are included if their taxonomy_path contains ANY of the selected codes (OR logic).';

-- =====================================================================
-- Test the updated function
-- =====================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE 'Multi-select taxonomy filter added successfully!';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Test examples:';
    RAISE NOTICE '  -- Single taxonomy:';
    RAISE NOTICE '  SELECT * FROM search.search_products(p_taxonomy_codes := ARRAY[''LUM_CEIL'']);';
    RAISE NOTICE '';
    RAISE NOTICE '  -- Multiple taxonomies (Ceiling OR Wall):';
    RAISE NOTICE '  SELECT * FROM search.search_products(p_taxonomy_codes := ARRAY[''LUM_CEIL'', ''LUM_WALL'']);';
    RAISE NOTICE '';
    RAISE NOTICE '  -- Empty array (show all):';
    RAISE NOTICE '  SELECT * FROM search.search_products(p_taxonomy_codes := ARRAY[]::TEXT[]);';
    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
END $$;
