-- =====================================================
-- File: 06-refresh-and-verify.sql
-- Purpose: Refresh materialized views and verify installation
-- Database: Foss SA Supabase
-- Estimated time: 8-10 minutes
-- =====================================================

\timing on

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Starting Materialized View Refresh';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'This will take approximately 8-10 minutes...';
    RAISE NOTICE '';
END $$;

-- =====================================================
-- STEP 1: Refresh product_taxonomy_flags
-- Time: ~3 minutes
-- =====================================================

RAISE NOTICE 'Step 1/3: Refreshing product_taxonomy_flags...';
REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;
ANALYZE search.product_taxonomy_flags;
RAISE NOTICE 'Step 1/3: Complete!';

-- =====================================================
-- STEP 2: Refresh product_filter_index
-- Time: ~4 minutes (only if filter_definitions exist)
-- =====================================================

RAISE NOTICE 'Step 2/3: Refreshing product_filter_index...';

DO $$
DECLARE
    filter_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO filter_count FROM search.filter_definitions;

    IF filter_count = 0 THEN
        RAISE NOTICE 'Skipping product_filter_index (no filters defined yet)';
        RAISE NOTICE 'Run 05-populate-filter-definitions.sql first';
    ELSE
        REFRESH MATERIALIZED VIEW search.product_filter_index;
        ANALYZE search.product_filter_index;
        RAISE NOTICE 'Step 2/3: Complete!';
    END IF;
END $$;

-- =====================================================
-- STEP 3: Refresh filter_facets
-- Time: ~1 minute (only if filter_definitions exist)
-- =====================================================

RAISE NOTICE 'Step 3/3: Refreshing filter_facets...';

DO $$
DECLARE
    filter_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO filter_count FROM search.filter_definitions;

    IF filter_count = 0 THEN
        RAISE NOTICE 'Skipping filter_facets (no filters defined yet)';
    ELSE
        REFRESH MATERIALIZED VIEW search.filter_facets;
        ANALYZE search.filter_facets;
        RAISE NOTICE 'Step 3/3: Complete!';
    END IF;
END $$;

\timing off

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'VERIFICATION RESULTS';
    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
END $$;

-- 1. Check product_taxonomy_flags population
DO $$
DECLARE
    total_products INTEGER;
    luminaire_count INTEGER;
    lamp_count INTEGER;
    driver_count INTEGER;
    accessory_count INTEGER;
    indoor_count INTEGER;
    outdoor_count INTEGER;
    both_count INTEGER;
    submersible_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_products FROM search.product_taxonomy_flags;
    SELECT COUNT(*) INTO luminaire_count FROM search.product_taxonomy_flags WHERE luminaire = true;
    SELECT COUNT(*) INTO lamp_count FROM search.product_taxonomy_flags WHERE lamp = true;
    SELECT COUNT(*) INTO driver_count FROM search.product_taxonomy_flags WHERE driver = true;
    SELECT COUNT(*) INTO accessory_count FROM search.product_taxonomy_flags WHERE accessory = true;
    SELECT COUNT(*) INTO indoor_count FROM search.product_taxonomy_flags WHERE indoor = true AND NOT outdoor;
    SELECT COUNT(*) INTO outdoor_count FROM search.product_taxonomy_flags WHERE outdoor = true AND NOT indoor;
    SELECT COUNT(*) INTO both_count FROM search.product_taxonomy_flags WHERE indoor = true AND outdoor = true;
    SELECT COUNT(*) INTO submersible_count FROM search.product_taxonomy_flags WHERE submersible = true;

    RAISE NOTICE '1. Product Taxonomy Flags:';
    RAISE NOTICE '   Total products indexed: %', total_products;
    RAISE NOTICE '';
    RAISE NOTICE '   Root Categories:';
    RAISE NOTICE '     Luminaires: % (expected: 13,336)', luminaire_count;
    RAISE NOTICE '     Lamps: % (expected: 50)', lamp_count;
    RAISE NOTICE '     Drivers: % (expected: 83)', driver_count;
    RAISE NOTICE '     Accessories: % (expected: 1,411)', accessory_count;
    RAISE NOTICE '';
    RAISE NOTICE '   Environment Detection:';
    RAISE NOTICE '     Indoor only: %', indoor_count;
    RAISE NOTICE '     Outdoor only: %', outdoor_count;
    RAISE NOTICE '     Both indoor & outdoor: %', both_count;
    RAISE NOTICE '     Submersible: %', submersible_count;
    RAISE NOTICE '';
END $$;

-- 2. Check installation types
DO $$
DECLARE
    recessed_count INTEGER;
    surface_count INTEGER;
    suspended_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO recessed_count FROM search.product_taxonomy_flags WHERE recessed = true;
    SELECT COUNT(*) INTO surface_count FROM search.product_taxonomy_flags WHERE surface_mounted = true;
    SELECT COUNT(*) INTO suspended_count FROM search.product_taxonomy_flags WHERE suspended = true;

    RAISE NOTICE '2. Installation Types:';
    RAISE NOTICE '     Recessed: %', recessed_count;
    RAISE NOTICE '     Surface-mounted: %', surface_count;
    RAISE NOTICE '     Suspended: %', suspended_count;
    RAISE NOTICE '';
END $$;

-- 3. Check product_filter_index
DO $$
DECLARE
    total_entries INTEGER;
    unique_products INTEGER;
    unique_filters INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_entries FROM search.product_filter_index;
    SELECT COUNT(DISTINCT product_id) INTO unique_products FROM search.product_filter_index;
    SELECT COUNT(DISTINCT filter_key) INTO unique_filters FROM search.product_filter_index;

    IF total_entries > 0 THEN
        RAISE NOTICE '3. Product Filter Index:';
        RAISE NOTICE '     Total filter entries: %', total_entries;
        RAISE NOTICE '     Unique products: %', unique_products;
        RAISE NOTICE '     Active filters: %', unique_filters;
        RAISE NOTICE '';
    ELSE
        RAISE NOTICE '3. Product Filter Index: EMPTY';
        RAISE NOTICE '     Run 05-populate-filter-definitions.sql first';
        RAISE NOTICE '';
    END IF;
END $$;

-- 4. Check filter_facets
DO $$
DECLARE
    facet_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO facet_count FROM search.filter_facets;

    IF facet_count > 0 THEN
        RAISE NOTICE '4. Filter Facets:';
        RAISE NOTICE '     Available facets: %', facet_count;
        RAISE NOTICE '';
    ELSE
        RAISE NOTICE '4. Filter Facets: EMPTY';
        RAISE NOTICE '     Run 05-populate-filter-definitions.sql first';
        RAISE NOTICE '';
    END IF;
END $$;

-- =====================================================
-- TEST QUERIES
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'TEST QUERIES';
    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
END $$;

-- Test 1: Find indoor recessed ceiling luminaires
RAISE NOTICE 'Test 1: Indoor recessed ceiling luminaires';
SELECT COUNT(*) as count,
       'Indoor recessed ceiling luminaires' as description
FROM search.product_taxonomy_flags
WHERE luminaire = true
  AND indoor = true
  AND recessed = true
  AND ceiling = true;

-- Test 2: Find outdoor luminaires
RAISE NOTICE 'Test 2: Outdoor luminaires';
SELECT COUNT(*) as count,
       'Outdoor luminaires' as description
FROM search.product_taxonomy_flags
WHERE luminaire = true
  AND outdoor = true;

-- Test 3: Find all drivers
RAISE NOTICE 'Test 3: All drivers';
SELECT COUNT(*) as count,
       'Total drivers' as description
FROM search.product_taxonomy_flags
WHERE driver = true;

-- Test 4: Browse by taxonomy path
RAISE NOTICE 'Test 4: Products in LUM_CEIL_REC taxonomy';
SELECT COUNT(*) as count,
       'Products in LUM_CEIL_REC' as description
FROM search.product_taxonomy_flags
WHERE 'LUM_CEIL_REC' = ANY(taxonomy_path);

-- Test 5: Check taxonomy distribution
RAISE NOTICE 'Test 5: Taxonomy path distribution (top 10)';
SELECT
    taxonomy_path,
    COUNT(*) as product_count
FROM search.product_taxonomy_flags
WHERE taxonomy_path IS NOT NULL
GROUP BY taxonomy_path
ORDER BY product_count DESC
LIMIT 10;

-- =====================================================
-- PERFORMANCE TEST
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'PERFORMANCE TEST';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Running sample query to test performance...';
    RAISE NOTICE '';
END $$;

\timing on

-- Complex filter query (should be <50ms)
EXPLAIN ANALYZE
SELECT
    pi.product_id,
    pi.foss_pid,
    pi.description_short,
    ptf.taxonomy_path
FROM search.product_taxonomy_flags ptf
JOIN items.product_info pi ON pi.product_id = ptf.product_id
WHERE ptf.luminaire = true
  AND ptf.indoor = true
  AND ptf.recessed = true
LIMIT 20;

\timing off

-- =====================================================
-- FINAL STATUS
-- =====================================================

DO $$
DECLARE
    total_products INTEGER;
    has_filters BOOLEAN;
    status TEXT;
BEGIN
    SELECT COUNT(*) INTO total_products FROM search.product_taxonomy_flags;
    SELECT EXISTS(SELECT 1 FROM search.filter_definitions) INTO has_filters;

    RAISE NOTICE '';
    RAISE NOTICE '===============================================';

    IF total_products = 0 THEN
        status := '❌ FAILED';
        RAISE NOTICE '% Installation Status', status;
        RAISE NOTICE '===============================================';
        RAISE NOTICE 'ERROR: No products indexed!';
        RAISE NOTICE 'Check classification_rules and retry refresh.';
    ELSIF total_products < 14000 THEN
        status := '⚠️  PARTIAL';
        RAISE NOTICE '% Installation Status', status;
        RAISE NOTICE '===============================================';
        RAISE NOTICE 'WARNING: Expected ~14,889 products, got %', total_products;
        RAISE NOTICE 'Some classification rules may not be working.';
    ELSE
        status := '✅ SUCCESS';
        RAISE NOTICE '% Installation Status', status;
        RAISE NOTICE '===============================================';
        RAISE NOTICE 'Products indexed: %', total_products;

        IF has_filters THEN
            RAISE NOTICE 'Filters: Configured';
            RAISE NOTICE '';
            RAISE NOTICE 'Search schema is READY for production!';
        ELSE
            RAISE NOTICE 'Filters: Not configured yet';
            RAISE NOTICE '';
            RAISE NOTICE 'Next step:';
            RAISE NOTICE '  - Run 05-populate-filter-definitions.sql';
            RAISE NOTICE '  - Then run this file again';
        END IF;
    END IF;

    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
END $$;

-- =====================================================
-- MAINTENANCE COMMANDS
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'DAILY MAINTENANCE COMMANDS';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Add these to your existing catalog refresh routine:';
    RAISE NOTICE '';
    RAISE NOTICE 'REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;';
    RAISE NOTICE 'REFRESH MATERIALIZED VIEW search.product_filter_index;';
    RAISE NOTICE 'REFRESH MATERIALIZED VIEW search.filter_facets;';
    RAISE NOTICE 'ANALYZE search.product_taxonomy_flags;';
    RAISE NOTICE 'ANALYZE search.product_filter_index;';
    RAISE NOTICE '';
    RAISE NOTICE 'Total refresh time: ~8 minutes';
    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
END $$;
