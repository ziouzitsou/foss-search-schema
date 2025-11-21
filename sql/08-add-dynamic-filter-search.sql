-- =====================================================================
-- 08-add-dynamic-filter-search.sql
-- =====================================================================
-- Adds enhanced search function supporting dynamic Delta-style filters
-- =====================================================================

-- Drop existing functions to avoid conflicts
DROP FUNCTION IF EXISTS search.search_products_with_filters CASCADE;
DROP FUNCTION IF EXISTS public.search_products_with_filters CASCADE;

-- =====================================================================
-- ENHANCED SEARCH FUNCTION WITH DYNAMIC FILTERS (FIXED VERSION)
-- =====================================================================
--
-- CRITICAL FIX: Range filter checks now use "IS NULL" pattern instead of "? 'key'"
-- to properly handle empty JSONB objects. The old pattern would return NULL (not TRUE)
-- when p_filters was empty, causing WHERE clause to fail.
--
-- OLD (BROKEN):  AND (NOT (p_filters->'cct' ? 'min') OR EXISTS (...))
-- NEW (FIXED):   AND (p_filters->'cct'->>'min' IS NULL OR EXISTS (...))
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

        -- Supplier filter (FIXED: handle NULL array properly)
        AND (p_suppliers IS NULL OR cardinality(p_suppliers) = 0 OR pi.supplier_name = ANY(p_suppliers))

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

        -- cct (range numeric) - FIXED: Use IS NULL pattern
        AND (p_filters->'cct'->>'min' IS NULL OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'cct'
              AND pfi.numeric_value >= (p_filters->'cct'->>'min')::NUMERIC
        ))
        AND (p_filters->'cct'->>'max' IS NULL OR EXISTS (
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

        -- lumens_output (range numeric) - FIXED: Use IS NULL pattern
        AND (p_filters->'lumens_output'->>'min' IS NULL OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'lumens_output'
              AND pfi.numeric_value >= (p_filters->'lumens_output'->>'min')::NUMERIC
        ))
        AND (p_filters->'lumens_output'->>'max' IS NULL OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'lumens_output'
              AND pfi.numeric_value <= (p_filters->'lumens_output'->>'max')::NUMERIC
        ))

        -- beam_angle_type (multi-select alphanumeric)
        AND (NOT (p_filters ? 'beam_angle_type') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'beam_angle_type'
              AND pfi.alphanumeric_value = ANY(
                  ARRAY(SELECT jsonb_array_elements_text(p_filters->'beam_angle_type'))
              )
        ))

        -- light_source (multi-select alphanumeric)
        AND (NOT (p_filters ? 'light_source') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'light_source'
              AND pfi.alphanumeric_value = ANY(
                  ARRAY(SELECT jsonb_array_elements_text(p_filters->'light_source'))
              )
        ))

        -- light_distribution (multi-select alphanumeric)
        AND (NOT (p_filters ? 'light_distribution') OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'light_distribution'
              AND pfi.alphanumeric_value = ANY(
                  ARRAY(SELECT jsonb_array_elements_text(p_filters->'light_distribution'))
              )
        ))

    ORDER BY relevance_score, foss_pid
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION search.search_products_with_filters IS
'Enhanced search function supporting dynamic Delta-style filters via JSONB parameter.
Handles multi-select, range, and boolean filters from the FilterPanel component.
FIXED VERSION: Range filters use IS NULL pattern to properly handle empty JSONB objects.

Includes 18 total filters:
- Multi-select: voltage, class, ip, finishing_colour, cri, beam_angle_type, light_source, light_distribution
- Range: cct (min/max), lumens_output (min/max)
- Boolean: dimmable, indoor, outdoor, submersible, trimless, cut_shape_round, cut_shape_rectangular

Example usage:
SELECT * FROM search.search_products_with_filters(
    p_query := ''LED'',
    p_filters := ''{"ip": ["IP65", "IP20"], "dimmable": true, "cct": {"min": 2700, "max": 3000}}''::JSONB,
    p_taxonomy_codes := ARRAY[''LUMINAIRE''],
    p_limit := 24
);';

-- =====================================================================
-- PUBLIC WRAPPER FUNCTION
-- =====================================================================

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
    SELECT * FROM search.search_products_with_filters(
        p_query,
        p_filters,
        p_taxonomy_codes,
        p_suppliers,
        p_indoor,
        p_outdoor,
        p_submersible,
        p_trimless,
        p_cut_shape_round,
        p_cut_shape_rectangular,
        p_sort_by,
        p_limit,
        p_offset
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Grant execute permission to Supabase roles
GRANT EXECUTE ON FUNCTION public.search_products_with_filters TO anon, authenticated;

COMMENT ON FUNCTION public.search_products_with_filters IS
'Public wrapper for search.search_products_with_filters.
Allows Supabase client to call via RPC with security definer context.';
