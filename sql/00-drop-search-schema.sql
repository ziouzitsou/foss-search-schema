-- =====================================================
-- File: 00-drop-search-schema.sql
-- Purpose: Drop existing search schema for clean reinstall
-- Database: Foss SA Supabase
-- WARNING: This will delete all search schema data!
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'WARNING: Dropping search schema';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'This will delete:';
    RAISE NOTICE '  - All tables in search schema';
    RAISE NOTICE '  - All materialized views';
    RAISE NOTICE '  - All functions';
    RAISE NOTICE '  - All data in search schema';
    RAISE NOTICE '';
    RAISE NOTICE 'Existing tables/views will be removed...';
    RAISE NOTICE '';
END $$;

-- Drop materialized views if they exist
DROP MATERIALIZED VIEW IF EXISTS search.filter_facets CASCADE;
DROP MATERIALIZED VIEW IF EXISTS search.product_filter_index CASCADE;
DROP MATERIALIZED VIEW IF EXISTS search.product_taxonomy_flags CASCADE;

-- Drop tables if they exist
DROP TABLE IF EXISTS search.filter_definitions CASCADE;
DROP TABLE IF EXISTS search.classification_rules CASCADE;
DROP TABLE IF EXISTS search.taxonomy CASCADE;

-- Drop functions if they exist
DROP FUNCTION IF EXISTS search.evaluate_feature_condition(jsonb, jsonb) CASCADE;
DROP FUNCTION IF EXISTS search.build_histogram(numeric[], integer) CASCADE;

-- Drop schema
DROP SCHEMA IF EXISTS search CASCADE;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Cleanup Complete!';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Search schema has been dropped.';
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Run 01-create-search-schema.sql';
    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
END $$;
