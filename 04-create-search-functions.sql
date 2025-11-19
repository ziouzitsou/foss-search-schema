-- =====================================================================
-- 04-create-search-functions.sql
-- =====================================================================
-- Creates search functions and helper utilities
-- =====================================================================

-- =====================================================================
-- 1. MAIN SEARCH FUNCTION
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
        (SELECT elem->>'mime_source' FROM jsonb_array_elements(pi.multimedia) AS elem WHERE elem->>'mime_code' = 'MD01' LIMIT 1) as image_url,
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
and alphanumeric filters. Returns paginated results with relevance scoring.';

-- =====================================================================
-- 2. GET AVAILABLE FACETS
-- =====================================================================

CREATE OR REPLACE FUNCTION search.get_available_facets()
RETURNS TABLE (
    filter_key TEXT,
    filter_type TEXT,
    label_el TEXT,
    label_en TEXT,
    facet_data JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        fd.filter_key,
        fd.filter_type,
        fd.label_el,
        fd.label_en,
        CASE
            WHEN fd.filter_type = 'numeric_range' THEN ff.numeric_stats
            WHEN fd.filter_type = 'alphanumeric' THEN ff.alphanumeric_counts
            WHEN fd.filter_type = 'boolean' THEN
                jsonb_build_object('true_count', ff.boolean_true_count)
            ELSE '{}'::jsonb
        END as facet_data
    FROM search.filter_definitions fd
    LEFT JOIN search.filter_facets ff ON ff.filter_key = fd.filter_key
    WHERE fd.active = true
    ORDER BY fd.display_order;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION search.get_available_facets IS
'Returns all available filters with their current facet values and counts.
Used to populate filter UI dynamically.';

-- =====================================================================
-- 3. GET TAXONOMY TREE
-- =====================================================================

CREATE OR REPLACE FUNCTION search.get_taxonomy_tree()
RETURNS TABLE (
    code TEXT,
    parent_code TEXT,
    level INTEGER,
    name_el TEXT,
    name_en TEXT,
    product_count BIGINT,
    icon TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.code,
        t.parent_code,
        t.level,
        t.name_el,
        t.name_en,
        COALESCE(tpc.product_count, 0) as product_count,
        t.icon
    FROM search.taxonomy t
    LEFT JOIN search.taxonomy_product_counts tpc ON t.code = tpc.taxonomy_code
    WHERE t.active = true
    ORDER BY t.level, t.display_order;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION search.get_taxonomy_tree IS
'Returns hierarchical taxonomy tree with product counts.
Used for category navigation menus.';

-- =====================================================================
-- 4. GET SEARCH STATISTICS
-- =====================================================================

CREATE OR REPLACE FUNCTION search.get_search_statistics()
RETURNS TABLE (
    stat_name TEXT,
    stat_value BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'total_products'::TEXT, COUNT(*)::BIGINT FROM search.product_taxonomy_flags
    UNION ALL
    SELECT 'indoor_products'::TEXT, COUNT(*)::BIGINT FROM search.product_taxonomy_flags WHERE indoor = true
    UNION ALL
    SELECT 'outdoor_products'::TEXT, COUNT(*)::BIGINT FROM search.product_taxonomy_flags WHERE outdoor = true
    UNION ALL
    SELECT 'dimmable_products'::TEXT, COUNT(*)::BIGINT FROM search.product_taxonomy_flags WHERE dimmable = true
    UNION ALL
    SELECT 'filter_entries'::TEXT, COUNT(*)::BIGINT FROM search.product_filter_index
    UNION ALL
    SELECT 'taxonomy_nodes'::TEXT, COUNT(*)::BIGINT FROM search.taxonomy WHERE active = true
    UNION ALL
    SELECT 'classification_rules'::TEXT, COUNT(*)::BIGINT FROM search.classification_rules WHERE active = true
    UNION ALL
    SELECT 'filter_definitions'::TEXT, COUNT(*)::BIGINT FROM search.filter_definitions WHERE active = true;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION search.get_search_statistics IS
'Returns key statistics about the search system.
Useful for monitoring and debugging.';

-- =====================================================================
-- 5. REFRESH ALL VIEWS FUNCTION
-- =====================================================================

CREATE OR REPLACE FUNCTION search.refresh_all_views(concurrent BOOLEAN DEFAULT true)
RETURNS TABLE (
    view_name TEXT,
    status TEXT,
    duration INTERVAL
) AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    -- Refresh product_taxonomy_flags
    v_start_time := clock_timestamp();
    IF concurrent AND EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'search'
          AND tablename = 'product_taxonomy_flags'
          AND indexdef LIKE '%UNIQUE%'
    ) THEN
        EXECUTE 'REFRESH MATERIALIZED VIEW CONCURRENTLY search.product_taxonomy_flags';
    ELSE
        EXECUTE 'REFRESH MATERIALIZED VIEW search.product_taxonomy_flags';
    END IF;
    v_end_time := clock_timestamp();
    v_duration := v_end_time - v_start_time;
    view_name := 'product_taxonomy_flags'; status := 'success'; duration := v_duration;
    RETURN NEXT;

    -- Refresh product_filter_index
    v_start_time := clock_timestamp();
    EXECUTE 'REFRESH MATERIALIZED VIEW search.product_filter_index';
    v_end_time := clock_timestamp();
    v_duration := v_end_time - v_start_time;
    view_name := 'product_filter_index'; status := 'success'; duration := v_duration;
    RETURN NEXT;

    -- Refresh filter_facets
    v_start_time := clock_timestamp();
    EXECUTE 'REFRESH MATERIALIZED VIEW search.filter_facets';
    v_end_time := clock_timestamp();
    v_duration := v_end_time - v_start_time;
    view_name := 'filter_facets'; status := 'success'; duration := v_duration;
    RETURN NEXT;

    -- Refresh taxonomy_product_counts
    v_start_time := clock_timestamp();
    EXECUTE 'REFRESH MATERIALIZED VIEW search.taxonomy_product_counts';
    v_end_time := clock_timestamp();
    v_duration := v_end_time - v_start_time;
    view_name := 'taxonomy_product_counts'; status := 'success'; duration := v_duration;
    RETURN NEXT;

    -- Analyze all views
    EXECUTE 'ANALYZE search.product_taxonomy_flags';
    EXECUTE 'ANALYZE search.product_filter_index';
    EXECUTE 'ANALYZE search.filter_facets';
    EXECUTE 'ANALYZE search.taxonomy_product_counts';

    RETURN;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION search.refresh_all_views IS
'Refreshes all search materialized views in the correct order.
Call this after catalog imports or configuration changes.';

-- =====================================================================
-- SUCCESS MESSAGE
-- =====================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE 'Search functions created successfully!';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Available functions:';
    RAISE NOTICE '  ✓ search.search_products() - Main search API';
    RAISE NOTICE '  ✓ search.get_available_facets() - Get filter options';
    RAISE NOTICE '  ✓ search.get_taxonomy_tree() - Get category tree';
    RAISE NOTICE '  ✓ search.get_search_statistics() - Get system stats';
    RAISE NOTICE '  ✓ search.refresh_all_views() - Refresh all views';
    RAISE NOTICE '';
    RAISE NOTICE 'Test the search:';
    RAISE NOTICE '  SELECT * FROM search.search_products(p_query := ''LED'', p_limit := 10);';
    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE 'Installation complete! 🎉';
    RAISE NOTICE '======================================================================';
END $$;
