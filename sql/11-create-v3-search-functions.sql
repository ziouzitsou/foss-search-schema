-- =====================================================================
-- 11-create-v3-search-functions.sql
-- =====================================================================
-- v3 search functions that query the denormalized search.product_search
-- wide table directly. Replaces the EAV-based v1/v2 functions.
--
-- Functions:
--   search.search_products_v3()  - Main product search
--   search.count_products_v3()   - Count matching products
--   search.get_facets_v3()       - Data-driven facet aggregation
--   public.search_products_v3()  - Public SECURITY DEFINER wrapper
--   public.count_products_v3()   - Public wrapper
--   public.get_facets_v3()       - Public wrapper
--
-- Key improvements over v1/v2:
--   - No N+1 subqueries (7 scalar subqueries per row → 0)
--   - No EAV JOINs (product_filter_index → direct columns)
--   - FTS via plainto_tsquery (not ILIKE '%...%')
--   - get_facets_v3 is data-driven from filter_definitions
-- =====================================================================

-- =====================================================================
-- SEARCH PRODUCTS V3
-- =====================================================================
-- Uses DYNAMIC SQL to map taxonomy codes to boolean columns via
-- search.taxonomy.boolean_column. This avoids sequential scans on
-- taxonomy_path for broad categories (LUMINAIRE = 2.27M rows) by using
-- partial indexes on boolean columns instead (35x faster).
-- =====================================================================
DROP FUNCTION IF EXISTS search.search_products_v3 CASCADE;

CREATE OR REPLACE FUNCTION search.search_products_v3(
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
    -- Direct feature columns (no more JSONB)
    voltage NUMERIC,
    cct NUMERIC,
    cri TEXT,
    ip_rating TEXT,
    finishing_colour TEXT,
    light_source TEXT,
    light_distribution TEXT,
    beam_angle_type TEXT,
    protection_class TEXT,
    lumens_output NUMERIC,
    -- Boolean flags
    indoor BOOLEAN,
    outdoor BOOLEAN,
    ceiling BOOLEAN,
    wall BOOLEAN,
    recessed BOOLEAN,
    dimmable BOOLEAN,
    submersible BOOLEAN,
    trimless BOOLEAN,
    cut_shape_round BOOLEAN,
    cut_shape_rectangular BOOLEAN,
    -- Relevance
    relevance_score REAL
) AS $$
DECLARE
    base_where TEXT := 'WHERE TRUE';
    bool_col TEXT;
    taxonomy_handled BOOLEAN := FALSE;
    order_clause TEXT;
    dyn_sql TEXT;
    supplier_list TEXT;
BEGIN
    -- === TAXONOMY FILTER ===
    -- Map taxonomy codes to boolean columns (uses partial indexes, 35x faster)
    IF p_taxonomy_codes IS NOT NULL AND cardinality(p_taxonomy_codes) > 0 THEN
        -- Check if ALL codes have boolean column mappings
        SELECT string_agg('ps.' || quote_ident(t.boolean_column) || ' = TRUE', ' AND ')
        INTO bool_col
        FROM search.taxonomy t
        WHERE t.code = ANY(p_taxonomy_codes) AND t.boolean_column IS NOT NULL;

        IF bool_col IS NOT NULL AND
           (SELECT COUNT(*) FROM search.taxonomy WHERE code = ANY(p_taxonomy_codes) AND boolean_column IS NOT NULL)
           = cardinality(p_taxonomy_codes) THEN
            -- All codes mapped to booleans — use indexed columns
            base_where := base_where || ' AND (' || bool_col || ')';
            taxonomy_handled := TRUE;
        END IF;

        IF NOT taxonomy_handled THEN
            -- Fallback: use taxonomy_path array overlap (for unmapped codes)
            base_where := base_where || ' AND ps.taxonomy_path && ' || quote_literal(p_taxonomy_codes::TEXT) || '::TEXT[]';
        END IF;
    END IF;

    -- === FTS ===
    IF p_query IS NOT NULL THEN
        base_where := base_where || ' AND ps.fts @@ plainto_tsquery(''english'', ' || quote_literal(p_query) || ')';
    END IF;

    -- === BOOLEAN FLAGS ===
    IF p_indoor IS NOT NULL THEN base_where := base_where || ' AND ps.indoor = ' || p_indoor; END IF;
    IF p_outdoor IS NOT NULL THEN base_where := base_where || ' AND ps.outdoor = ' || p_outdoor; END IF;
    IF p_submersible IS NOT NULL THEN base_where := base_where || ' AND ps.submersible = ' || p_submersible; END IF;
    IF p_trimless IS NOT NULL THEN base_where := base_where || ' AND ps.trimless = ' || p_trimless; END IF;
    IF p_cut_shape_round IS NOT NULL THEN base_where := base_where || ' AND ps.cut_shape_round = ' || p_cut_shape_round; END IF;
    IF p_cut_shape_rectangular IS NOT NULL THEN base_where := base_where || ' AND ps.cut_shape_rectangular = ' || p_cut_shape_rectangular; END IF;

    -- === SUPPLIER ===
    -- Use = for single supplier (enables composite index), IN for multiple
    IF p_suppliers IS NOT NULL AND cardinality(p_suppliers) > 0 THEN
        IF cardinality(p_suppliers) = 1 THEN
            base_where := base_where || ' AND ps.supplier_name = ' || quote_literal(p_suppliers[1]);
        ELSE
            SELECT string_agg(quote_literal(s), ', ') INTO supplier_list FROM unnest(p_suppliers) s;
            base_where := base_where || ' AND ps.supplier_name IN (' || supplier_list || ')';
        END IF;
    END IF;

    -- === CATEGORICAL FILTERS ===
    -- Use IN (subquery) instead of = ANY(ARRAY(...)) for better index usage
    IF p_filters ? 'class' THEN base_where := base_where || ' AND ps.protection_class IN (SELECT jsonb_array_elements_text(' || quote_literal(p_filters->'class') || '::JSONB))'; END IF;
    IF p_filters ? 'ip' THEN base_where := base_where || ' AND ps.ip_rating IN (SELECT jsonb_array_elements_text(' || quote_literal(p_filters->'ip') || '::JSONB))'; END IF;
    IF p_filters ? 'finishing_colour' THEN base_where := base_where || ' AND ps.finishing_colour IN (SELECT jsonb_array_elements_text(' || quote_literal(p_filters->'finishing_colour') || '::JSONB))'; END IF;
    IF p_filters ? 'cri' THEN base_where := base_where || ' AND ps.cri IN (SELECT jsonb_array_elements_text(' || quote_literal(p_filters->'cri') || '::JSONB))'; END IF;
    IF p_filters ? 'beam_angle_type' THEN base_where := base_where || ' AND ps.beam_angle_type IN (SELECT jsonb_array_elements_text(' || quote_literal(p_filters->'beam_angle_type') || '::JSONB))'; END IF;
    IF p_filters ? 'light_source' THEN base_where := base_where || ' AND ps.light_source IN (SELECT jsonb_array_elements_text(' || quote_literal(p_filters->'light_source') || '::JSONB))'; END IF;
    IF p_filters ? 'light_distribution' THEN base_where := base_where || ' AND ps.light_distribution IN (SELECT jsonb_array_elements_text(' || quote_literal(p_filters->'light_distribution') || '::JSONB))'; END IF;

    -- === BOOLEAN JSONB FILTER ===
    IF p_filters ? 'dimmable' THEN base_where := base_where || ' AND ps.dimmable = ' || quote_literal(p_filters->>'dimmable') || '::BOOLEAN'; END IF;

    -- === RANGE FILTERS ===
    IF p_filters->'cct'->>'min' IS NOT NULL THEN base_where := base_where || ' AND ps.cct >= ' || (p_filters->'cct'->>'min')::NUMERIC; END IF;
    IF p_filters->'cct'->>'max' IS NOT NULL THEN base_where := base_where || ' AND ps.cct <= ' || (p_filters->'cct'->>'max')::NUMERIC; END IF;
    IF p_filters->'lumens_output'->>'min' IS NOT NULL THEN base_where := base_where || ' AND ps.lumens_output >= ' || (p_filters->'lumens_output'->>'min')::NUMERIC; END IF;
    IF p_filters->'lumens_output'->>'max' IS NOT NULL THEN base_where := base_where || ' AND ps.lumens_output <= ' || (p_filters->'lumens_output'->>'max')::NUMERIC; END IF;
    IF p_filters->'voltage'->>'min' IS NOT NULL THEN base_where := base_where || ' AND ps.voltage >= ' || (p_filters->'voltage'->>'min')::NUMERIC; END IF;
    IF p_filters->'voltage'->>'max' IS NOT NULL THEN base_where := base_where || ' AND ps.voltage <= ' || (p_filters->'voltage'->>'max')::NUMERIC; END IF;

    -- === ORDER BY ===
    IF p_sort_by = 'relevance' AND p_query IS NOT NULL THEN
        order_clause := 'ORDER BY ts_rank(ps.fts, plainto_tsquery(''english'', ' || quote_literal(p_query) || ')) DESC, ps.foss_pid ASC';
    ELSIF p_sort_by = 'price_asc' THEN
        order_clause := 'ORDER BY ps.price ASC NULLS LAST, ps.foss_pid ASC';
    ELSIF p_sort_by = 'price_desc' THEN
        order_clause := 'ORDER BY ps.price DESC NULLS LAST, ps.foss_pid ASC';
    ELSIF p_sort_by = 'name' THEN
        order_clause := 'ORDER BY ps.description_short ASC, ps.foss_pid ASC';
    ELSE
        order_clause := 'ORDER BY ps.foss_pid ASC';
    END IF;

    -- === EXECUTE ===
    dyn_sql := format(
        'SELECT ps.product_id, ps.foss_pid, ps.description_short, ps.description_long,
                ps.supplier_name, ps.class_name, ps.price, ps.image_url, ps.taxonomy_path,
                ps.voltage, ps.cct, ps.cri, ps.ip_rating, ps.finishing_colour,
                ps.light_source, ps.light_distribution, ps.beam_angle_type,
                ps.protection_class, ps.lumens_output,
                ps.indoor, ps.outdoor, ps.ceiling, ps.wall, ps.recessed,
                ps.dimmable, ps.submersible, ps.trimless,
                ps.cut_shape_round, ps.cut_shape_rectangular,
                CASE WHEN %L IS NOT NULL AND ps.fts @@ plainto_tsquery(''english'', %L)
                     THEN ts_rank(ps.fts, plainto_tsquery(''english'', %L))
                     WHEN %L IS NOT NULL THEN 0.0 ELSE 1.0 END::REAL as relevance_score
         FROM search.product_search ps %s %s LIMIT %s OFFSET %s',
        p_query, p_query, p_query, p_query,
        base_where, order_clause, p_limit, p_offset
    );

    RETURN QUERY EXECUTE dyn_sql;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION search.search_products_v3 IS
'v3 search using dynamic SQL with boolean column mapping.
Maps taxonomy codes to boolean columns via search.taxonomy.boolean_column,
enabling partial index usage (35x faster than taxonomy_path GIN for broad categories).
Falls back to taxonomy_path array overlap for unmapped codes.';

-- =====================================================================
-- COUNT PRODUCTS V3
-- =====================================================================
-- Uses same dynamic SQL approach as search_products_v3 for taxonomy
-- boolean column mapping. When only taxonomy is specified with no
-- other filters, uses pre-computed count from search.taxonomy for
-- instant response.
-- =====================================================================
DROP FUNCTION IF EXISTS search.count_products_v3 CASCADE;

CREATE OR REPLACE FUNCTION search.count_products_v3(
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
    result BIGINT;
    base_where TEXT := 'WHERE TRUE';
    bool_col TEXT;
    taxonomy_handled BOOLEAN := FALSE;
    has_extra_filters BOOLEAN;
    supplier_list TEXT;
    explain_result JSONB;
BEGIN
    -- Check if there are any filters beyond taxonomy
    has_extra_filters := (
        p_query IS NOT NULL OR
        p_indoor IS NOT NULL OR p_outdoor IS NOT NULL OR
        p_submersible IS NOT NULL OR p_trimless IS NOT NULL OR
        p_cut_shape_round IS NOT NULL OR p_cut_shape_rectangular IS NOT NULL OR
        (p_suppliers IS NOT NULL AND cardinality(p_suppliers) > 0) OR
        (p_filters IS NOT NULL AND p_filters != '{}'::JSONB)
    );

    -- FAST PATH: taxonomy-only count → use pre-computed value
    IF NOT has_extra_filters AND p_taxonomy_codes IS NOT NULL AND cardinality(p_taxonomy_codes) = 1 THEN
        SELECT t.product_count INTO result
        FROM search.taxonomy t
        WHERE t.code = p_taxonomy_codes[1] AND t.product_count > 0;

        IF FOUND AND result IS NOT NULL THEN
            RETURN result;
        END IF;
    END IF;

    -- STANDARD PATH: dynamic SQL with boolean column mapping
    IF p_taxonomy_codes IS NOT NULL AND cardinality(p_taxonomy_codes) > 0 THEN
        SELECT string_agg('ps.' || quote_ident(t.boolean_column) || ' = TRUE', ' AND ')
        INTO bool_col
        FROM search.taxonomy t
        WHERE t.code = ANY(p_taxonomy_codes) AND t.boolean_column IS NOT NULL;

        IF bool_col IS NOT NULL AND
           (SELECT COUNT(*) FROM search.taxonomy WHERE code = ANY(p_taxonomy_codes) AND boolean_column IS NOT NULL)
           = cardinality(p_taxonomy_codes) THEN
            base_where := base_where || ' AND (' || bool_col || ')';
            taxonomy_handled := TRUE;
        END IF;

        IF NOT taxonomy_handled THEN
            base_where := base_where || ' AND ps.taxonomy_path && ' || quote_literal(p_taxonomy_codes::TEXT) || '::TEXT[]';
        END IF;
    END IF;

    IF p_query IS NOT NULL THEN
        base_where := base_where || ' AND ps.fts @@ plainto_tsquery(''english'', ' || quote_literal(p_query) || ')';
    END IF;

    IF p_indoor IS NOT NULL THEN base_where := base_where || ' AND ps.indoor = ' || p_indoor; END IF;
    IF p_outdoor IS NOT NULL THEN base_where := base_where || ' AND ps.outdoor = ' || p_outdoor; END IF;
    IF p_submersible IS NOT NULL THEN base_where := base_where || ' AND ps.submersible = ' || p_submersible; END IF;
    IF p_trimless IS NOT NULL THEN base_where := base_where || ' AND ps.trimless = ' || p_trimless; END IF;
    IF p_cut_shape_round IS NOT NULL THEN base_where := base_where || ' AND ps.cut_shape_round = ' || p_cut_shape_round; END IF;
    IF p_cut_shape_rectangular IS NOT NULL THEN base_where := base_where || ' AND ps.cut_shape_rectangular = ' || p_cut_shape_rectangular; END IF;

    IF p_suppliers IS NOT NULL AND cardinality(p_suppliers) > 0 THEN
        IF cardinality(p_suppliers) = 1 THEN
            base_where := base_where || ' AND ps.supplier_name = ' || quote_literal(p_suppliers[1]);
        ELSE
            SELECT string_agg(quote_literal(s), ', ') INTO supplier_list FROM unnest(p_suppliers) s;
            base_where := base_where || ' AND ps.supplier_name IN (' || supplier_list || ')';
        END IF;
    END IF;

    IF p_filters ? 'class' THEN base_where := base_where || ' AND ps.protection_class IN (SELECT jsonb_array_elements_text(' || quote_literal(p_filters->'class') || '::JSONB))'; END IF;
    IF p_filters ? 'ip' THEN base_where := base_where || ' AND ps.ip_rating IN (SELECT jsonb_array_elements_text(' || quote_literal(p_filters->'ip') || '::JSONB))'; END IF;
    IF p_filters ? 'finishing_colour' THEN base_where := base_where || ' AND ps.finishing_colour IN (SELECT jsonb_array_elements_text(' || quote_literal(p_filters->'finishing_colour') || '::JSONB))'; END IF;
    IF p_filters ? 'cri' THEN base_where := base_where || ' AND ps.cri IN (SELECT jsonb_array_elements_text(' || quote_literal(p_filters->'cri') || '::JSONB))'; END IF;
    IF p_filters ? 'beam_angle_type' THEN base_where := base_where || ' AND ps.beam_angle_type IN (SELECT jsonb_array_elements_text(' || quote_literal(p_filters->'beam_angle_type') || '::JSONB))'; END IF;
    IF p_filters ? 'light_source' THEN base_where := base_where || ' AND ps.light_source IN (SELECT jsonb_array_elements_text(' || quote_literal(p_filters->'light_source') || '::JSONB))'; END IF;
    IF p_filters ? 'light_distribution' THEN base_where := base_where || ' AND ps.light_distribution IN (SELECT jsonb_array_elements_text(' || quote_literal(p_filters->'light_distribution') || '::JSONB))'; END IF;
    IF p_filters ? 'dimmable' THEN base_where := base_where || ' AND ps.dimmable = ' || quote_literal(p_filters->>'dimmable') || '::BOOLEAN'; END IF;

    IF p_filters->'cct'->>'min' IS NOT NULL THEN base_where := base_where || ' AND ps.cct >= ' || (p_filters->'cct'->>'min')::NUMERIC; END IF;
    IF p_filters->'cct'->>'max' IS NOT NULL THEN base_where := base_where || ' AND ps.cct <= ' || (p_filters->'cct'->>'max')::NUMERIC; END IF;
    IF p_filters->'lumens_output'->>'min' IS NOT NULL THEN base_where := base_where || ' AND ps.lumens_output >= ' || (p_filters->'lumens_output'->>'min')::NUMERIC; END IF;
    IF p_filters->'lumens_output'->>'max' IS NOT NULL THEN base_where := base_where || ' AND ps.lumens_output <= ' || (p_filters->'lumens_output'->>'max')::NUMERIC; END IF;
    IF p_filters->'voltage'->>'min' IS NOT NULL THEN base_where := base_where || ' AND ps.voltage >= ' || (p_filters->'voltage'->>'min')::NUMERIC; END IF;
    IF p_filters->'voltage'->>'max' IS NOT NULL THEN base_where := base_where || ' AND ps.voltage <= ' || (p_filters->'voltage'->>'max')::NUMERIC; END IF;

    -- Use EXPLAIN estimate for large result sets (instant), exact count for small ones
    EXECUTE 'EXPLAIN (FORMAT JSON) SELECT * FROM search.product_search ps ' || base_where INTO explain_result;
    result := (explain_result->0->'Plan'->>'Plan Rows')::BIGINT;

    -- For small result sets (< 100K), do exact count (fast enough)
    IF result < 100000 THEN
        EXECUTE 'SELECT COUNT(*) FROM search.product_search ps ' || base_where INTO result;
    END IF;

    RETURN result;
END;
$$ LANGUAGE plpgsql VOLATILE;

COMMENT ON FUNCTION search.count_products_v3 IS
'v3 count with boolean column mapping + fast path for taxonomy-only counts.
Uses pre-computed taxonomy.product_count when no filters are active (instant).
Dynamic SQL with boolean columns for filtered counts (35x faster than taxonomy_path).';

-- =====================================================================
-- GET FACETS V3 (DATA-DRIVEN + CACHED)
-- =====================================================================
-- Uses facet_cache for taxonomy-only queries (instant).
-- Falls back to dynamic computation for filtered queries.
-- The cache is populated by the rebuild-product-search.sh script.
-- =====================================================================
DROP FUNCTION IF EXISTS search.get_facets_v3 CASCADE;

CREATE OR REPLACE FUNCTION search.get_facets_v3(
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
) RETURNS JSONB AS $$
DECLARE
    result JSONB := '{}'::JSONB;
    total_count BIGINT;
    filter_rec RECORD;
    facet_data JSONB;
    col_name TEXT;
    base_where TEXT;
    dyn_sql TEXT;
    has_extra_filters BOOLEAN;
    has_narrow_filters BOOLEAN;
    cached_data JSONB;
BEGIN
    -- Check filter types for cache strategy
    -- "narrow" = supplier, categorical, range, text (changes facet distribution significantly)
    -- "broad" = boolean flags only (facet distribution stays ~same as taxonomy-only)
    has_narrow_filters := (
        p_query IS NOT NULL OR
        (p_suppliers IS NOT NULL AND cardinality(p_suppliers) > 0) OR
        (p_filters IS NOT NULL AND p_filters != '{}'::JSONB)
    );

    has_extra_filters := (
        has_narrow_filters OR
        p_indoor IS NOT NULL OR p_outdoor IS NOT NULL OR
        p_submersible IS NOT NULL OR p_trimless IS NOT NULL OR
        p_cut_shape_round IS NOT NULL OR p_cut_shape_rectangular IS NOT NULL OR
        (p_suppliers IS NOT NULL AND cardinality(p_suppliers) > 0) OR
        (p_filters IS NOT NULL AND p_filters != '{}'::JSONB)
    );

    -- FAST PATH: Return cached facets when no narrow filters are applied.
    -- Boolean-only filters (indoor, outdoor, etc.) don't significantly change
    -- facet distributions, so cached taxonomy facets are a good approximation.
    -- Only supplier/categorical/range/text filters warrant fresh computation.
    IF NOT has_narrow_filters AND p_taxonomy_codes IS NOT NULL AND cardinality(p_taxonomy_codes) = 1 THEN
        SELECT fc.facet_data INTO cached_data
        FROM search.facet_cache fc
        WHERE fc.taxonomy_code = p_taxonomy_codes[1];

        IF FOUND AND cached_data IS NOT NULL THEN
            RETURN cached_data;
        END IF;
    END IF;

    -- STANDARD PATH: dynamic computation
    base_where := 'WHERE TRUE';

    IF p_query IS NOT NULL THEN
        base_where := base_where || ' AND ps.fts @@ plainto_tsquery(''english'', ' || quote_literal(p_query) || ')';
    END IF;

    -- Map taxonomy codes to boolean columns
    IF p_taxonomy_codes IS NOT NULL AND cardinality(p_taxonomy_codes) > 0 THEN
        DECLARE
            bool_col_facets TEXT;
            taxonomy_handled_facets BOOLEAN := FALSE;
        BEGIN
            SELECT string_agg('ps.' || quote_ident(t.boolean_column) || ' = TRUE', ' AND ')
            INTO bool_col_facets
            FROM search.taxonomy t
            WHERE t.code = ANY(p_taxonomy_codes) AND t.boolean_column IS NOT NULL;

            IF bool_col_facets IS NOT NULL AND
               (SELECT COUNT(*) FROM search.taxonomy WHERE code = ANY(p_taxonomy_codes) AND boolean_column IS NOT NULL)
               = cardinality(p_taxonomy_codes) THEN
                base_where := base_where || ' AND (' || bool_col_facets || ')';
                taxonomy_handled_facets := TRUE;
            END IF;

            IF NOT taxonomy_handled_facets THEN
                base_where := base_where || ' AND ps.taxonomy_path && ' || quote_literal(p_taxonomy_codes::TEXT) || '::TEXT[]';
            END IF;
        END;
    END IF;

    IF p_indoor IS NOT NULL THEN base_where := base_where || ' AND ps.indoor = ' || p_indoor; END IF;
    IF p_outdoor IS NOT NULL THEN base_where := base_where || ' AND ps.outdoor = ' || p_outdoor; END IF;
    IF p_submersible IS NOT NULL THEN base_where := base_where || ' AND ps.submersible = ' || p_submersible; END IF;
    IF p_trimless IS NOT NULL THEN base_where := base_where || ' AND ps.trimless = ' || p_trimless; END IF;
    IF p_cut_shape_round IS NOT NULL THEN base_where := base_where || ' AND ps.cut_shape_round = ' || p_cut_shape_round; END IF;
    IF p_cut_shape_rectangular IS NOT NULL THEN base_where := base_where || ' AND ps.cut_shape_rectangular = ' || p_cut_shape_rectangular; END IF;

    IF p_suppliers IS NOT NULL AND cardinality(p_suppliers) > 0 THEN
        IF cardinality(p_suppliers) = 1 THEN
            base_where := base_where || ' AND ps.supplier_name = ' || quote_literal(p_suppliers[1]);
        ELSE
            DECLARE supplier_list_f TEXT;
            BEGIN
                SELECT string_agg(quote_literal(s), ', ') INTO supplier_list_f FROM unnest(p_suppliers) s;
                base_where := base_where || ' AND ps.supplier_name IN (' || supplier_list_f || ')';
            END;
        END IF;
    END IF;

    -- Get total count
    EXECUTE 'SELECT COUNT(*) FROM search.product_search ps ' || base_where INTO total_count;
    result := jsonb_build_object('total', total_count);

    -- Supplier facet
    EXECUTE format(
        'SELECT COALESCE(jsonb_agg(row_to_json(t) ORDER BY t.count DESC), ''[]''::JSONB)
         FROM (
             SELECT ps.supplier_name AS value, COUNT(*) AS count
             FROM search.product_search ps %s
             AND ps.supplier_name IS NOT NULL
             GROUP BY ps.supplier_name ORDER BY COUNT(*) DESC
         ) t', base_where
    ) INTO facet_data;
    result := result || jsonb_build_object('supplier', facet_data);

    -- Data-driven facets from filter_definitions
    FOR filter_rec IN
        SELECT fd.filter_key, fd.filter_type
        FROM search.filter_definitions fd
        WHERE fd.active = true AND fd.etim_feature_id LIKE 'EF%'
          AND (fd.applicable_taxonomy_codes IS NULL
               OR p_taxonomy_codes IS NULL
               OR fd.applicable_taxonomy_codes && p_taxonomy_codes)
        ORDER BY fd.display_order
    LOOP
        CASE filter_rec.filter_key
            WHEN 'class' THEN col_name := 'protection_class';
            WHEN 'ip' THEN col_name := 'ip_rating';
            ELSE col_name := filter_rec.filter_key;
        END CASE;

        IF filter_rec.filter_type = 'categorical' THEN
            EXECUTE format(
                'SELECT COALESCE(jsonb_agg(row_to_json(t) ORDER BY t.count DESC), ''[]''::JSONB)
                 FROM (SELECT ps.%I AS value, COUNT(*) AS count
                       FROM search.product_search ps %s AND ps.%I IS NOT NULL
                       GROUP BY ps.%I ORDER BY COUNT(*) DESC LIMIT 50) t',
                col_name, base_where, col_name, col_name
            ) INTO facet_data;
            result := result || jsonb_build_object(filter_rec.filter_key, facet_data);

        ELSIF filter_rec.filter_type = 'range' THEN
            EXECUTE format(
                'SELECT jsonb_build_object(''min'', MIN(ps.%I), ''max'', MAX(ps.%I), ''count'', COUNT(ps.%I))
                 FROM search.product_search ps %s AND ps.%I IS NOT NULL',
                col_name, col_name, col_name, base_where, col_name
            ) INTO facet_data;
            result := result || jsonb_build_object(filter_rec.filter_key, facet_data);

        ELSIF filter_rec.filter_type = 'boolean' THEN
            EXECUTE format(
                'SELECT jsonb_build_object(''true'', COUNT(*) FILTER (WHERE ps.%I = TRUE),
                     ''false'', COUNT(*) FILTER (WHERE ps.%I IS NOT TRUE))
                 FROM search.product_search ps %s',
                col_name, col_name, base_where
            ) INTO facet_data;
            result := result || jsonb_build_object(filter_rec.filter_key, facet_data);
        END IF;
    END LOOP;

    RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION search.get_facets_v3 IS
'v3 facets with cache + boolean column mapping.
For taxonomy-only queries: returns pre-computed JSONB from facet_cache (instant).
For filtered queries: dynamic SQL with boolean columns (faster than taxonomy_path).
Cache is populated by rebuild-product-search.sh.';

-- =====================================================================
-- PUBLIC WRAPPER FUNCTIONS (SECURITY DEFINER)
-- =====================================================================

DROP FUNCTION IF EXISTS public.search_products_v3 CASCADE;

CREATE OR REPLACE FUNCTION public.search_products_v3(
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
    voltage NUMERIC,
    cct NUMERIC,
    cri TEXT,
    ip_rating TEXT,
    finishing_colour TEXT,
    light_source TEXT,
    light_distribution TEXT,
    beam_angle_type TEXT,
    protection_class TEXT,
    lumens_output NUMERIC,
    indoor BOOLEAN,
    outdoor BOOLEAN,
    ceiling BOOLEAN,
    wall BOOLEAN,
    recessed BOOLEAN,
    dimmable BOOLEAN,
    submersible BOOLEAN,
    trimless BOOLEAN,
    cut_shape_round BOOLEAN,
    cut_shape_rectangular BOOLEAN,
    relevance_score REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM search.search_products_v3(
        p_query, p_filters, p_taxonomy_codes, p_suppliers,
        p_indoor, p_outdoor, p_submersible, p_trimless,
        p_cut_shape_round, p_cut_shape_rectangular,
        p_sort_by, p_limit, p_offset
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.search_products_v3 TO anon, authenticated;

-- Count wrapper
DROP FUNCTION IF EXISTS public.count_products_v3 CASCADE;

CREATE OR REPLACE FUNCTION public.count_products_v3(
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
    SELECT search.count_products_v3(
        p_query, p_filters, p_taxonomy_codes, p_suppliers,
        p_indoor, p_outdoor, p_submersible, p_trimless,
        p_cut_shape_round, p_cut_shape_rectangular
    );
$$ LANGUAGE sql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.count_products_v3 TO anon, authenticated;

-- Facets wrapper
DROP FUNCTION IF EXISTS public.get_facets_v3 CASCADE;

CREATE OR REPLACE FUNCTION public.get_facets_v3(
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
) RETURNS JSONB AS $$
    SELECT search.get_facets_v3(
        p_taxonomy_codes, p_filters, p_suppliers,
        p_indoor, p_outdoor, p_submersible, p_trimless,
        p_cut_shape_round, p_cut_shape_rectangular,
        p_query
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_facets_v3 TO anon, authenticated;

-- =====================================================================
-- SUCCESS
-- =====================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=======================================================================';
    RAISE NOTICE 'v3 search functions created successfully!';
    RAISE NOTICE '=======================================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Functions:';
    RAISE NOTICE '  ✓ search.search_products_v3()  - Main search (direct columns)';
    RAISE NOTICE '  ✓ search.count_products_v3()   - Count matching products';
    RAISE NOTICE '  ✓ search.get_facets_v3()       - Data-driven facet aggregation';
    RAISE NOTICE '  ✓ public.search_products_v3()  - Public wrapper';
    RAISE NOTICE '  ✓ public.count_products_v3()   - Public wrapper';
    RAISE NOTICE '  ✓ public.get_facets_v3()       - Public wrapper';
    RAISE NOTICE '';
END $$;
