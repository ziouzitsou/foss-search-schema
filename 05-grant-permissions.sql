-- =====================================================================
-- 05-grant-permissions.sql
-- =====================================================================
-- Grants necessary permissions for Supabase RPC access
-- Run this after creating all functions
-- =====================================================================

-- =====================================================================
-- 1. GRANT SCHEMA ACCESS
-- =====================================================================

-- Grant usage on search schema to anon and authenticated users
GRANT USAGE ON SCHEMA search TO anon, authenticated;

-- Grant usage on items schema (needed for product_info access)
GRANT USAGE ON SCHEMA items TO anon, authenticated;

-- =====================================================================
-- 2. GRANT TABLE ACCESS
-- =====================================================================

-- Grant select on all tables in search schema
GRANT SELECT ON ALL TABLES IN SCHEMA search TO anon, authenticated;

-- Grant select on product_info (used by search functions)
GRANT SELECT ON items.product_info TO anon, authenticated;

-- =====================================================================
-- 3. GRANT FUNCTION ACCESS
-- =====================================================================

-- Grant execute on all functions in search schema
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA search TO anon, authenticated;

-- =====================================================================
-- 4. CREATE PUBLIC SCHEMA WRAPPERS (For Supabase RPC)
-- =====================================================================
-- Supabase RPC looks for functions in the public schema by default
-- These wrappers make search functions accessible via supabase.rpc()

-- 4.1 search_products wrapper
CREATE OR REPLACE FUNCTION public.search_products(
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
    SELECT * FROM search.search_products(
        p_query, p_indoor, p_outdoor, p_ceiling, p_wall, p_pendant,
        p_recessed, p_dimmable, p_power_min, p_power_max,
        p_color_temp_min, p_color_temp_max, p_ip_ratings, p_suppliers,
        p_sort_by, p_limit, p_offset
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- 4.2 get_search_statistics wrapper
CREATE OR REPLACE FUNCTION public.get_search_statistics()
RETURNS TABLE (
    stat_name TEXT,
    stat_value BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM search.get_search_statistics();
END;
$$ LANGUAGE plpgsql STABLE;

-- 4.3 get_available_facets wrapper
CREATE OR REPLACE FUNCTION public.get_available_facets()
RETURNS TABLE (
    filter_key TEXT,
    filter_type TEXT,
    label_el TEXT,
    label_en TEXT,
    facet_data JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM search.get_available_facets();
END;
$$ LANGUAGE plpgsql STABLE;

-- 4.4 get_taxonomy_tree wrapper
CREATE OR REPLACE FUNCTION public.get_taxonomy_tree()
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
    SELECT * FROM search.get_taxonomy_tree();
END;
$$ LANGUAGE plpgsql STABLE;

-- =====================================================================
-- 5. GRANT PUBLIC WRAPPER PERMISSIONS
-- =====================================================================

GRANT EXECUTE ON FUNCTION public.search_products TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_search_statistics TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_available_facets TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_taxonomy_tree TO anon, authenticated;

-- =====================================================================
-- SUCCESS MESSAGE
-- =====================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE 'Permissions granted successfully!';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Granted access to:';
    RAISE NOTICE '  ✓ anon (unauthenticated users)';
    RAISE NOTICE '  ✓ authenticated (logged-in users)';
    RAISE NOTICE '';
    RAISE NOTICE 'Schemas accessible:';
    RAISE NOTICE '  ✓ search schema (all tables and functions)';
    RAISE NOTICE '  ✓ items.product_info (read-only)';
    RAISE NOTICE '';
    RAISE NOTICE 'Public RPC wrappers created:';
    RAISE NOTICE '  ✓ public.search_products()';
    RAISE NOTICE '  ✓ public.get_search_statistics()';
    RAISE NOTICE '  ✓ public.get_available_facets()';
    RAISE NOTICE '  ✓ public.get_taxonomy_tree()';
    RAISE NOTICE '';
    RAISE NOTICE 'Usage from Next.js:';
    RAISE NOTICE '  const { data } = await supabase.rpc(''search_products'', {';
    RAISE NOTICE '    p_indoor: true,';
    RAISE NOTICE '    p_power_min: 10,';
    RAISE NOTICE '    p_power_max: 50';
    RAISE NOTICE '  })';
    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
END $$;
