-- =====================================================================
-- 06-remove-greek-language.sql
-- =====================================================================
-- Removes all Greek language columns from the search schema
-- Updates taxonomy and filter_definitions to be English-only
-- =====================================================================

-- =====================================================================
-- 1. UPDATE TAXONOMY TABLE - REMOVE GREEK COLUMNS
-- =====================================================================

-- Drop Greek columns from taxonomy
ALTER TABLE search.taxonomy
DROP COLUMN IF EXISTS name_el,
DROP COLUMN IF EXISTS description_el;

COMMENT ON TABLE search.taxonomy IS
'Hierarchical product taxonomy for navigation (English only).
Maps business-friendly categories to technical ETIM classifications.';

-- =====================================================================
-- 2. UPDATE FILTER_DEFINITIONS TABLE - REMOVE GREEK COLUMNS
-- =====================================================================

-- Drop Greek columns from filter_definitions
ALTER TABLE search.filter_definitions
DROP COLUMN IF EXISTS label_el;

COMMENT ON TABLE search.filter_definitions IS
'Defines available filters for faceted search (English only).
Controls UI rendering and maps to ETIM features.';

-- =====================================================================
-- 3. UPDATE get_taxonomy_tree FUNCTION - ENGLISH ONLY
-- =====================================================================

CREATE OR REPLACE FUNCTION search.get_taxonomy_tree()
RETURNS TABLE (
    code TEXT,
    parent_code TEXT,
    level INTEGER,
    name TEXT,
    product_count BIGINT,
    icon TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.code,
        t.parent_code,
        t.level,
        t.name_en as name,
        COALESCE(tpc.product_count, 0) as product_count,
        t.icon
    FROM search.taxonomy t
    LEFT JOIN search.taxonomy_product_counts tpc ON t.code = tpc.taxonomy_code
    WHERE t.active = true
    ORDER BY t.level, t.display_order;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION search.get_taxonomy_tree IS
'Returns hierarchical taxonomy tree with product counts (English only).
Used for category navigation menus.';

-- =====================================================================
-- 4. UPDATE get_available_facets FUNCTION - ENGLISH ONLY
-- =====================================================================

CREATE OR REPLACE FUNCTION search.get_available_facets()
RETURNS TABLE (
    filter_key TEXT,
    filter_type TEXT,
    label TEXT,
    facet_data JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        fd.filter_key,
        fd.filter_type,
        fd.label_en as label,
        jsonb_build_object(
            'filter_key', fd.filter_key,
            'ui_component', fd.ui_component,
            'ui_config', fd.ui_config,
            'values', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'value', ff.facet_value,
                        'count', ff.product_count
                    )
                    ORDER BY ff.product_count DESC
                )
                FROM search.filter_facets ff
                WHERE ff.filter_key = fd.filter_key
            )
        ) as facet_data
    FROM search.filter_definitions fd
    WHERE fd.active = true
    ORDER BY fd.display_order;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION search.get_available_facets IS
'Returns all available filters with their current facet values and counts (English only).
Used to populate filter UI dynamically.';

-- =====================================================================
-- 5. UPDATE PUBLIC WRAPPERS - ENGLISH ONLY
-- =====================================================================

-- Update public wrapper for get_taxonomy_tree
CREATE OR REPLACE FUNCTION public.get_taxonomy_tree()
RETURNS TABLE (
    code TEXT,
    parent_code TEXT,
    level INTEGER,
    name TEXT,
    product_count BIGINT,
    icon TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM search.get_taxonomy_tree();
END;
$$ LANGUAGE plpgsql STABLE;

-- Update public wrapper for get_available_facets
CREATE OR REPLACE FUNCTION public.get_available_facets()
RETURNS TABLE (
    filter_key TEXT,
    filter_type TEXT,
    label TEXT,
    facet_data JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM search.get_available_facets();
END;
$$ LANGUAGE plpgsql STABLE;

-- =====================================================================
-- SUCCESS MESSAGE
-- =====================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE 'Greek language support removed successfully!';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Changes made:';
    RAISE NOTICE '  ✓ Removed name_el, description_el from taxonomy table';
    RAISE NOTICE '  ✓ Removed label_el from filter_definitions table';
    RAISE NOTICE '  ✓ Updated get_taxonomy_tree() - returns name only';
    RAISE NOTICE '  ✓ Updated get_available_facets() - returns label only';
    RAISE NOTICE '  ✓ Updated public wrappers for RPC access';
    RAISE NOTICE '';
    RAISE NOTICE 'Database is now English-only!';
    RAISE NOTICE '';
    RAISE NOTICE 'Remaining columns in taxonomy:';
    RAISE NOTICE '  - code, parent_code, level';
    RAISE NOTICE '  - name_en (only English name)';
    RAISE NOTICE '  - description_en (only English description)';
    RAISE NOTICE '  - icon, display_order, active, full_path';
    RAISE NOTICE '';
    RAISE NOTICE 'Remaining columns in filter_definitions:';
    RAISE NOTICE '  - filter_key, filter_type';
    RAISE NOTICE '  - label_en (only English label)';
    RAISE NOTICE '  - etim_feature_id, etim_unit_id';
    RAISE NOTICE '  - display_order, ui_component, ui_config';
    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
END $$;
