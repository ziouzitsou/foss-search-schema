-- =====================================================================
-- 05-grant-permissions-direct-schema.sql (SIMPLIFIED VERSION)
-- =====================================================================
-- Grants permissions for direct schema access (no public wrappers)
-- Works with: supabaseServer.schema('search').rpc('search_products', ...)
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
-- SUCCESS MESSAGE
-- =====================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE 'Permissions granted successfully (Direct Schema Access)!';
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
    RAISE NOTICE 'Usage from Next.js:';
    RAISE NOTICE '  const { data } = await supabaseServer';
    RAISE NOTICE '    .schema(''search'')';
    RAISE NOTICE '    .rpc(''search_products'', {';
    RAISE NOTICE '      p_indoor: true,';
    RAISE NOTICE '      p_power_min: 10,';
    RAISE NOTICE '      p_power_max: 50';
    RAISE NOTICE '    })';
    RAISE NOTICE '';
    RAISE NOTICE 'NOTE: No public schema wrappers created.';
    RAISE NOTICE 'Use .schema(''search'').rpc() pattern for all calls.';
    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
END $$;
