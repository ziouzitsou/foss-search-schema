-- =====================================================
-- File: 04-create-materialized-views.sql
-- Purpose: Create materialized views for fast product search
-- Database: Foss SA Supabase
-- Estimated time: 10-15 minutes (initial creation + refresh)
-- =====================================================

-- =====================================================
-- 1. search.product_taxonomy_flags
-- Purpose: Boolean flags per product from classification rules
-- Refresh time: ~3 minutes for 14,889 products
-- =====================================================

CREATE MATERIALIZED VIEW search.product_taxonomy_flags AS
WITH product_classifications AS (
    -- Apply all active classification rules to products
    SELECT DISTINCT
        pi.product_id,
        pi.foss_pid,
        cr.taxonomy_code,
        cr.flag_name,
        cr.priority
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
                  WHERE search.evaluate_feature_condition(f, cr.etim_feature_conditions)
              ))

          -- Rule matches text pattern (case-insensitive)
          OR (cr.text_pattern IS NOT NULL
              AND (pi.description_short ~* cr.text_pattern
                   OR pi.description_long ~* cr.text_pattern))
      )
)
SELECT
    product_id,
    foss_pid,

    -- Taxonomy path (array of codes from root to leaf)
    array_agg(DISTINCT taxonomy_code ORDER BY taxonomy_code)
        FILTER (WHERE taxonomy_code IS NOT NULL) AS taxonomy_path,

    -- Root category flags (priority 1-20)
    bool_or(flag_name = 'luminaire') AS luminaire,
    bool_or(flag_name = 'lamp') AS lamp,
    bool_or(flag_name = 'driver') AS driver,
    bool_or(flag_name = 'accessory') AS accessory,

    -- Environment flags (text pattern, priority 100)
    bool_or(flag_name = 'indoor') AS indoor,
    bool_or(flag_name = 'outdoor') AS outdoor,
    bool_or(flag_name = 'submersible') AS submersible,
    bool_or(flag_name = 'trimless') AS trimless,

    -- Mounting location flags (priority 30-40)
    bool_or(flag_name = 'ceiling') AS ceiling,
    bool_or(flag_name = 'wall') AS wall,
    bool_or(flag_name = 'floor') AS floor,

    -- Installation type flags (priority 50-60)
    bool_or(flag_name = 'recessed') AS recessed,
    bool_or(flag_name = 'surface_mounted') AS surface_mounted,
    bool_or(flag_name = 'suspended') AS suspended,

    -- Specific combination flags (priority 60)
    bool_or(flag_name = 'ceiling_recessed') AS ceiling_recessed,
    bool_or(flag_name = 'ceiling_surface') AS ceiling_surface,
    bool_or(flag_name = 'ceiling_suspended') AS ceiling_suspended,
    bool_or(flag_name = 'wall_recessed') AS wall_recessed,
    bool_or(flag_name = 'wall_surface') AS wall_surface,
    bool_or(flag_name = 'floor_recessed') AS floor_recessed,
    bool_or(flag_name = 'floor_surface') AS floor_surface,

    -- Decorative type flags (priority 70)
    bool_or(flag_name = 'decorative_table') AS decorative_table,
    bool_or(flag_name = 'decorative_pendant') AS decorative_pendant,
    bool_or(flag_name = 'decorative_floor') AS decorative_floor,

    -- Special type flags (priority 70)
    bool_or(flag_name = 'led_strip') AS led_strip,
    bool_or(flag_name = 'track_system') AS track_system,
    bool_or(flag_name = 'batten') AS batten,
    bool_or(flag_name = 'pole_mounted') AS pole_mounted,

    -- Accessory type flags (priority 80)
    bool_or(flag_name = 'track_profile') AS track_profile,
    bool_or(flag_name = 'track_spare') AS track_spare,

    -- Driver type flags (priority 80)
    bool_or(flag_name = 'constant_current') AS constant_current,
    bool_or(flag_name = 'constant_voltage') AS constant_voltage,

    -- Lamp type flags (priority 80)
    bool_or(flag_name = 'filament') AS filament,
    bool_or(flag_name = 'led_module') AS led_module

FROM product_classifications
GROUP BY product_id, foss_pid;

-- Indexes for fast filtering
CREATE UNIQUE INDEX idx_product_taxonomy_flags_product
    ON search.product_taxonomy_flags(product_id);

CREATE INDEX idx_product_taxonomy_flags_foss_pid
    ON search.product_taxonomy_flags(foss_pid);

CREATE INDEX idx_product_taxonomy_flags_taxonomy_path
    ON search.product_taxonomy_flags USING GIN(taxonomy_path);

-- Root category indexes
CREATE INDEX idx_product_taxonomy_flags_luminaire
    ON search.product_taxonomy_flags(luminaire) WHERE luminaire = true;
CREATE INDEX idx_product_taxonomy_flags_lamp
    ON search.product_taxonomy_flags(lamp) WHERE lamp = true;
CREATE INDEX idx_product_taxonomy_flags_driver
    ON search.product_taxonomy_flags(driver) WHERE driver = true;
CREATE INDEX idx_product_taxonomy_flags_accessory
    ON search.product_taxonomy_flags(accessory) WHERE accessory = true;

-- Environment indexes
CREATE INDEX idx_product_taxonomy_flags_indoor
    ON search.product_taxonomy_flags(indoor) WHERE indoor = true;
CREATE INDEX idx_product_taxonomy_flags_outdoor
    ON search.product_taxonomy_flags(outdoor) WHERE outdoor = true;
CREATE INDEX idx_product_taxonomy_flags_submersible
    ON search.product_taxonomy_flags(submersible) WHERE submersible = true;

-- Installation type indexes
CREATE INDEX idx_product_taxonomy_flags_recessed
    ON search.product_taxonomy_flags(recessed) WHERE recessed = true;
CREATE INDEX idx_product_taxonomy_flags_surface_mounted
    ON search.product_taxonomy_flags(surface_mounted) WHERE surface_mounted = true;

COMMENT ON MATERIALIZED VIEW search.product_taxonomy_flags IS
'Fast boolean flags for product classification. Refreshed after catalog imports
or rule changes. Enables instant filtering without JSON parsing.';

-- =====================================================
-- 2. search.product_filter_index
-- Purpose: Flattened ETIM features for faceted search
-- Refresh time: ~4 minutes
-- =====================================================

CREATE MATERIALIZED VIEW search.product_filter_index AS
SELECT DISTINCT
    pi.product_id,
    pi.foss_pid,
    fd.filter_key,
    fd.filter_type,

    -- Extract values based on filter type
    CASE
        WHEN fd.filter_type = 'numeric_range' THEN
            (f->>'fvalueN')::NUMERIC
        ELSE NULL
    END AS numeric_value,

    CASE
        WHEN fd.filter_type = 'alphanumeric' THEN
            COALESCE(f->>'fvalueC_desc', f->>'fvalueC')
        ELSE NULL
    END AS alphanumeric_value,

    CASE
        WHEN fd.filter_type = 'boolean' THEN
            (f->>'fvalueB')::BOOLEAN
        ELSE NULL
    END AS boolean_value,

    -- Include unit for numeric values
    f->>'unit_abbrev' AS unit_abbrev,
    f->>'unit' AS unit_id

FROM items.product_info pi
CROSS JOIN LATERAL jsonb_array_elements(pi.features) f
INNER JOIN search.filter_definitions fd
    ON fd.etim_feature_id = f->>'id'
    AND fd.active = true
WHERE
    -- Exclude NULL values
    (fd.filter_type = 'numeric_range' AND f->>'fvalueN' IS NOT NULL)
    OR (fd.filter_type = 'alphanumeric' AND (f->>'fvalueC_desc' IS NOT NULL OR f->>'fvalueC' IS NOT NULL))
    OR (fd.filter_type = 'boolean' AND f->>'fvalueB' IS NOT NULL);

-- Indexes for each filter type
CREATE INDEX idx_product_filter_index_product
    ON search.product_filter_index(product_id);

CREATE INDEX idx_product_filter_index_foss_pid
    ON search.product_filter_index(foss_pid);

CREATE INDEX idx_product_filter_index_key
    ON search.product_filter_index(filter_key);

CREATE INDEX idx_product_filter_index_numeric
    ON search.product_filter_index(filter_key, numeric_value)
    WHERE numeric_value IS NOT NULL;

CREATE INDEX idx_product_filter_index_alphanumeric
    ON search.product_filter_index(filter_key, alphanumeric_value)
    WHERE alphanumeric_value IS NOT NULL;

CREATE INDEX idx_product_filter_index_boolean
    ON search.product_filter_index(filter_key, boolean_value)
    WHERE boolean_value = true;

COMMENT ON MATERIALIZED VIEW search.product_filter_index IS
'Flattened index of all filterable features. Enables fast faceted search
without JSON parsing. One row per product-filter combination.';

-- =====================================================
-- 3. search.filter_facets
-- Purpose: Pre-calculated filter options and counts
-- Refresh time: ~1 minute
-- =====================================================

CREATE MATERIALIZED VIEW search.filter_facets AS
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
) subquery
GROUP BY filter_key, filter_type;

CREATE UNIQUE INDEX idx_filter_facets_key ON search.filter_facets(filter_key);

COMMENT ON MATERIALIZED VIEW search.filter_facets IS
'Aggregated facet counts and statistics for filter UI. Shows available
filter options and product counts before user applies filters.';

-- =====================================================
-- Verification
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Materialized Views Created Successfully!';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Views created:';
    RAISE NOTICE '  1. search.product_taxonomy_flags';
    RAISE NOTICE '  2. search.product_filter_index';
    RAISE NOTICE '  3. search.filter_facets';
    RAISE NOTICE '';
    RAISE NOTICE 'IMPORTANT: Views are EMPTY until refreshed!';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Run 05-populate-filter-definitions.sql';
    RAISE NOTICE '  2. Run 06-refresh-and-verify.sql (REQUIRED!)';
    RAISE NOTICE '';
    RAISE NOTICE 'Estimated refresh time:';
    RAISE NOTICE '  - product_taxonomy_flags: ~3 minutes';
    RAISE NOTICE '  - product_filter_index: ~4 minutes';
    RAISE NOTICE '  - filter_facets: ~1 minute';
    RAISE NOTICE '  Total: ~8 minutes';
    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
END $$;
