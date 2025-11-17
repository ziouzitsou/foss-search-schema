-- =====================================================================
-- 03-create-materialized-views.sql
-- =====================================================================
-- Creates materialized views for fast product search
-- This may take 5-10 minutes depending on data volume
-- =====================================================================

-- =====================================================================
-- 1. PRODUCT_TAXONOMY_FLAGS (Boolean flags per product)
-- =====================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS search.product_taxonomy_flags AS
WITH product_classifications AS (
    -- Apply all active classification rules
    SELECT DISTINCT
        pi.product_id,
        pi.foss_pid,
        cr.taxonomy_code,
        cr.flag_name
    FROM items.product_info pi
    CROSS JOIN search.classification_rules cr
    WHERE cr.active = true
      AND (
          -- Rule matches ETIM group
          (cr.etim_group_ids IS NOT NULL
           AND pi."group" = ANY(cr.etim_group_ids))

          -- Rule matches ETIM class
          OR (cr.etim_class_ids IS NOT NULL
              AND pi.class = ANY(cr.etim_class_ids))

          -- Rule matches feature conditions
          OR (cr.etim_feature_conditions IS NOT NULL
              AND EXISTS (
                  SELECT 1
                  FROM jsonb_array_elements(pi.features) f
                  WHERE f->>'FEATUREID' = (SELECT jsonb_object_keys(cr.etim_feature_conditions) LIMIT 1)
                    AND CASE
                        WHEN cr.etim_feature_conditions->(f->>'FEATUREID')->>'operator' = 'equals' THEN
                            (f->>'fvalueB')::TEXT = cr.etim_feature_conditions->(f->>'FEATUREID')->>'value'
                        ELSE false
                    END
              ))

          -- Rule matches text pattern
          OR (cr.text_pattern IS NOT NULL
              AND (pi.description_short ~* cr.text_pattern
                   OR pi.description_long ~* cr.text_pattern))
      )
)
SELECT
    product_id,
    foss_pid,

    -- Taxonomy path (array of codes from root to leaf)
    array_agg(DISTINCT taxonomy_code) FILTER (WHERE taxonomy_code IS NOT NULL) AS taxonomy_path,

    -- Boolean flags (pivoted)
    bool_or(flag_name = 'indoor') AS indoor,
    bool_or(flag_name = 'outdoor') AS outdoor,
    bool_or(flag_name = 'ceiling') AS ceiling,
    bool_or(flag_name = 'wall') AS wall,
    bool_or(flag_name = 'pendant') AS pendant,
    bool_or(flag_name = 'floor') AS floor,
    bool_or(flag_name = 'recessed') AS recessed,
    bool_or(flag_name = 'surface_mounted') AS surface_mounted,
    bool_or(flag_name = 'track') AS track,
    bool_or(flag_name = 'dimmable') AS dimmable

FROM product_classifications
GROUP BY product_id, foss_pid;

-- Indexes for fast filtering
CREATE UNIQUE INDEX IF NOT EXISTS idx_product_taxonomy_flags_product
    ON search.product_taxonomy_flags(product_id);
CREATE INDEX IF NOT EXISTS idx_product_taxonomy_flags_indoor
    ON search.product_taxonomy_flags(indoor) WHERE indoor = true;
CREATE INDEX IF NOT EXISTS idx_product_taxonomy_flags_outdoor
    ON search.product_taxonomy_flags(outdoor) WHERE outdoor = true;
CREATE INDEX IF NOT EXISTS idx_product_taxonomy_flags_dimmable
    ON search.product_taxonomy_flags(dimmable) WHERE dimmable = true;

COMMENT ON MATERIALIZED VIEW search.product_taxonomy_flags IS
'Fast boolean flags for product classification. Refreshed after catalog imports
or rule changes. Enables instant filtering without JSON parsing.';

-- =====================================================================
-- 2. PRODUCT_FILTER_INDEX (Flattened feature index)
-- =====================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS search.product_filter_index AS
SELECT DISTINCT
    pi.product_id,
    pi.foss_pid,
    fd.filter_key,
    fd.filter_type,

    -- Extract values based on filter type - FIXED: Check fvalueR first (most common)
    CASE
        WHEN fd.filter_type = 'numeric_range' AND (f->>'fvalueR') IS NOT NULL THEN
            -- Extract lower bound from range
            lower((f->>'fvalueR')::numrange)
        WHEN fd.filter_type = 'numeric_range' AND (f->>'fvalueN') IS NOT NULL THEN
            (f->>'fvalueN')::NUMERIC
        ELSE NULL
    END AS numeric_value,

    CASE
        WHEN fd.filter_type = 'alphanumeric' THEN
            f->>'fvalueC_desc'
        ELSE NULL
    END AS alphanumeric_value,

    CASE
        WHEN fd.filter_type = 'boolean' THEN
            (f->>'fvalueB')::BOOLEAN
        ELSE NULL
    END AS boolean_value,

    -- Include unit for numeric values
    f->>'unit_abbrev' AS unit

FROM items.product_info pi
CROSS JOIN LATERAL jsonb_array_elements(pi.features) f
INNER JOIN search.filter_definitions fd
    ON fd.etim_feature_id = f->>'FEATUREID'
    AND fd.active = true
WHERE
    -- Exclude NULL values
    (fd.filter_type = 'numeric_range' AND (f->>'fvalueN' IS NOT NULL OR f->>'fvalueR' IS NOT NULL))
    OR (fd.filter_type = 'alphanumeric' AND f->>'fvalueC_desc' IS NOT NULL)
    OR (fd.filter_type = 'boolean' AND (f->>'fvalueB')::BOOLEAN = true);

-- Indexes for each filter type
CREATE INDEX IF NOT EXISTS idx_product_filter_index_product
    ON search.product_filter_index(product_id);
CREATE INDEX IF NOT EXISTS idx_product_filter_index_key
    ON search.product_filter_index(filter_key);
CREATE INDEX IF NOT EXISTS idx_product_filter_index_numeric
    ON search.product_filter_index(filter_key, numeric_value)
    WHERE numeric_value IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_product_filter_index_alphanumeric
    ON search.product_filter_index(filter_key, alphanumeric_value)
    WHERE alphanumeric_value IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_product_filter_index_boolean
    ON search.product_filter_index(filter_key, boolean_value)
    WHERE boolean_value = true;

COMMENT ON MATERIALIZED VIEW search.product_filter_index IS
'Flattened index of all filterable features. Enables fast faceted search
without JSON parsing. One row per product-filter combination.';

-- =====================================================================
-- 3. FILTER_FACETS (Aggregated facet counts)
-- =====================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS search.filter_facets AS
SELECT
    filter_key,
    filter_type,

    -- For numeric filters: min, max, avg, count
    CASE WHEN filter_type = 'numeric_range' THEN
        jsonb_build_object(
            'min', MIN(numeric_value),
            'max', MAX(numeric_value),
            'avg', ROUND(AVG(numeric_value)::numeric, 2),
            'count', COUNT(*)
        )
    ELSE NULL END AS numeric_stats,

    -- For alphanumeric filters: value counts
    CASE WHEN filter_type = 'alphanumeric' THEN
        jsonb_object_agg(alphanumeric_value, value_count)
    ELSE NULL END AS alphanumeric_counts,

    -- For boolean filters: true count
    CASE WHEN filter_type = 'boolean' THEN
        COUNT(*) FILTER (WHERE boolean_value = true)
    ELSE NULL END AS boolean_true_count

FROM (
    SELECT
        filter_key,
        filter_type,
        numeric_value,
        alphanumeric_value,
        boolean_value,
        COUNT(*) as value_count
    FROM search.product_filter_index
    GROUP BY filter_key, filter_type, numeric_value, alphanumeric_value, boolean_value
) subquery
GROUP BY filter_key, filter_type;

CREATE UNIQUE INDEX IF NOT EXISTS idx_filter_facets_key ON search.filter_facets(filter_key);

COMMENT ON MATERIALIZED VIEW search.filter_facets IS
'Aggregated facet counts and statistics for filter UI. Shows available
filter options and product counts before user applies filters.';

-- =====================================================================
-- 4. TAXONOMY_PRODUCT_COUNTS (Product counts per category)
-- =====================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS search.taxonomy_product_counts AS
SELECT
    t.code AS taxonomy_code,
    t.name_en,
    t.name_el,
    t.level,
    COUNT(DISTINCT ptf.product_id) AS product_count
FROM search.taxonomy t
LEFT JOIN search.product_taxonomy_flags ptf
    ON t.code = ANY(ptf.taxonomy_path)
WHERE t.active = true
GROUP BY t.code, t.name_en, t.name_el, t.level
HAVING COUNT(DISTINCT ptf.product_id) > 0;

CREATE UNIQUE INDEX IF NOT EXISTS idx_taxonomy_product_counts_code
    ON search.taxonomy_product_counts(taxonomy_code);

COMMENT ON MATERIALIZED VIEW search.taxonomy_product_counts IS
'Product counts per taxonomy category. Used for navigation menus.';

-- =====================================================================
-- REFRESH AND ANALYZE
-- =====================================================================

ANALYZE search.product_taxonomy_flags;
ANALYZE search.product_filter_index;
ANALYZE search.filter_facets;
ANALYZE search.taxonomy_product_counts;

-- =====================================================================
-- SUCCESS MESSAGE
-- =====================================================================

DO $$
DECLARE
    products_indexed INTEGER;
    filter_entries INTEGER;
    facets_count INTEGER;
    taxonomy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO products_indexed FROM search.product_taxonomy_flags;
    SELECT COUNT(*) INTO filter_entries FROM search.product_filter_index;
    SELECT COUNT(*) INTO facets_count FROM search.filter_facets;
    SELECT COUNT(*) INTO taxonomy_count FROM search.taxonomy_product_counts;

    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE 'Materialized views created and refreshed successfully!';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Statistics:';
    RAISE NOTICE '  ✓ Products indexed: %', products_indexed;
    RAISE NOTICE '  ✓ Filter index entries: %', filter_entries;
    RAISE NOTICE '  ✓ Available facets: %', facets_count;
    RAISE NOTICE '  ✓ Taxonomy nodes with products: %', taxonomy_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Materialized views created:';
    RAISE NOTICE '  ✓ search.product_taxonomy_flags';
    RAISE NOTICE '  ✓ search.product_filter_index';
    RAISE NOTICE '  ✓ search.filter_facets';
    RAISE NOTICE '  ✓ search.taxonomy_product_counts';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Run 04-create-search-functions.sql';
    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
END $$;
