-- =====================================================
-- File: 05-populate-filter-definitions.sql
-- Purpose: Research ETIM features and create filter definitions
-- Database: Foss SA Supabase
-- =====================================================

-- =====================================================
-- STEP 1: Research ETIM Feature IDs
-- Run these queries to find actual ETIM codes in your database
-- =====================================================

-- Power feature (Wattage)
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'STEP 1: Finding ETIM Feature IDs';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Run these queries to find your ETIM feature codes:';
    RAISE NOTICE '';
END $$;

-- Query 1: Find Power feature
RAISE NOTICE '1. Finding Power feature:';
SELECT DISTINCT
    f->>'id' as feature_id,
    f->>'desc' as description,
    COUNT(*) as product_count
FROM items.product_info pi,
     jsonb_array_elements(pi.features) f
WHERE f->>'desc' ILIKE '%power%'
   OR f->>'desc' ILIKE '%watt%'
   OR f->>'desc' ILIKE '%ισχύ%'
GROUP BY f->>'id', f->>'desc'
ORDER BY product_count DESC
LIMIT 5;

-- Query 2: Find IP Rating feature
RAISE NOTICE '2. Finding IP Rating feature:';
SELECT DISTINCT
    f->>'id' as feature_id,
    f->>'desc' as description,
    COUNT(*) as product_count
FROM items.product_info pi,
     jsonb_array_elements(pi.features) f
WHERE f->>'desc' ILIKE '%IP%'
   OR f->>'desc' ILIKE '%protection%'
   OR f->>'desc' ILIKE '%degree%'
GROUP BY f->>'id', f->>'desc'
ORDER BY product_count DESC
LIMIT 5;

-- Query 3: Find Color Temperature feature
RAISE NOTICE '3. Finding Color Temperature feature:';
SELECT DISTINCT
    f->>'id' as feature_id,
    f->>'desc' as description,
    COUNT(*) as product_count
FROM items.product_info pi,
     jsonb_array_elements(pi.features) f
WHERE f->>'desc' ILIKE '%color%temp%'
   OR f->>'desc' ILIKE '%kelvin%'
   OR f->>'desc' ILIKE '%CCT%'
GROUP BY f->>'id', f->>'desc'
ORDER BY product_count DESC
LIMIT 5;

-- Query 4: Find Luminous Flux feature
RAISE NOTICE '4. Finding Luminous Flux (lumen) feature:';
SELECT DISTINCT
    f->>'id' as feature_id,
    f->>'desc' as description,
    COUNT(*) as product_count
FROM items.product_info pi,
     jsonb_array_elements(pi.features) f
WHERE f->>'desc' ILIKE '%lumen%'
   OR f->>'desc' ILIKE '%flux%'
   OR f->>'desc' ILIKE '%lm%'
GROUP BY f->>'id', f->>'desc'
ORDER BY product_count DESC
LIMIT 5;

-- Query 5: Find CRI feature
RAISE NOTICE '5. Finding CRI (Color Rendering Index) feature:';
SELECT DISTINCT
    f->>'id' as feature_id,
    f->>'desc' as description,
    COUNT(*) as product_count
FROM items.product_info pi,
     jsonb_array_elements(pi.features) f
WHERE f->>'desc' ILIKE '%CRI%'
   OR f->>'desc' ILIKE '%color%rendering%'
   OR f->>'desc' ILIKE '%Ra%'
GROUP BY f->>'id', f->>'desc'
ORDER BY product_count DESC
LIMIT 5;

-- Query 6: Find Beam Angle feature
RAISE NOTICE '6. Finding Beam Angle feature:';
SELECT DISTINCT
    f->>'id' as feature_id,
    f->>'desc' as description,
    COUNT(*) as product_count
FROM items.product_info pi,
     jsonb_array_elements(pi.features) f
WHERE f->>'desc' ILIKE '%beam%'
   OR f->>'desc' ILIKE '%angle%'
   OR f->>'desc' ILIKE '%γωνία%'
GROUP BY f->>'id', f->>'desc'
ORDER BY product_count DESC
LIMIT 5;

-- Query 7: Find Voltage feature
RAISE NOTICE '7. Finding Voltage feature:';
SELECT DISTINCT
    f->>'id' as feature_id,
    f->>'desc' as description,
    COUNT(*) as product_count
FROM items.product_info pi,
     jsonb_array_elements(pi.features) f
WHERE f->>'desc' ILIKE '%voltage%'
   OR f->>'desc' ILIKE '%volt%'
   OR f->>'desc' ILIKE '%τάση%'
GROUP BY f->>'id', f->>'desc'
ORDER BY product_count DESC
LIMIT 5;

-- Query 8: Find Dimmable feature
RAISE NOTICE '8. Finding Dimmable feature:';
SELECT DISTINCT
    f->>'id' as feature_id,
    f->>'desc' as description,
    COUNT(*) as product_count
FROM items.product_info pi,
     jsonb_array_elements(pi.features) f
WHERE f->>'desc' ILIKE '%dimm%'
   OR f->>'desc' ILIKE '%dim%control%'
GROUP BY f->>'id', f->>'desc'
ORDER BY product_count DESC
LIMIT 5;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'IMPORTANT: Copy the feature IDs above!';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Update the INSERT statements below with your';
    RAISE NOTICE 'actual ETIM feature IDs before running.';
    RAISE NOTICE '';
    RAISE NOTICE 'Example: Replace ''EF000001'' with actual ID';
    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
END $$;

-- =====================================================
-- STEP 2: Create Filter Definitions
-- UPDATE THE ETIM FEATURE IDs BELOW WITH ACTUAL VALUES!
-- =====================================================

-- PLACEHOLDER FILTER DEFINITIONS
-- These use example ETIM codes - you MUST update them!

/*
-- Uncomment and update after finding your ETIM feature IDs:

INSERT INTO search.filter_definitions (
    filter_key,
    filter_type,
    label,
    etim_feature_id,
    etim_unit_id,
    ui_component,
    ui_config,
    display_order,
    applicable_taxonomy_codes
) VALUES
    -- Power filter (numeric range)
    (
        'power',
        'numeric_range',
        'Power',
        'EF000001',  -- UPDATE THIS: Replace with actual power feature ID
        'EU570001',  -- UPDATE THIS: Replace with actual watt unit ID
        'slider',
        '{"min": 0, "max": 300, "step": 5, "unit": "W"}'::jsonb,
        10,
        ARRAY['LUM']  -- Only for luminaires
    ),

    -- Luminous Flux filter (numeric range)
    (
        'luminous_flux',
        'numeric_range',
        'Luminous Flux',
        'EF000002',  -- UPDATE THIS
        'EU570002',  -- UPDATE THIS
        'slider',
        '{"min": 0, "max": 10000, "step": 100, "unit": "lm"}'::jsonb,
        20,
        ARRAY['LUM', 'LAMP']
    ),

    -- Color Temperature filter (numeric range)
    (
        'color_temperature',
        'numeric_range',
        'Color Temperature',
        'EF000003',  -- UPDATE THIS
        'EU570003',  -- UPDATE THIS
        'slider',
        '{"min": 2700, "max": 6500, "step": 100, "unit": "K"}'::jsonb,
        30,
        NULL  -- All categories
    ),

    -- IP Rating filter (alphanumeric multiselect)
    (
        'ip_rating',
        'alphanumeric',
        'IP Rating',
        'EF000004',  -- UPDATE THIS
        NULL,
        'multiselect',
        '{"options": ["IP20", "IP44", "IP54", "IP65", "IP66", "IP67", "IP68"]}'::jsonb,
        40,
        NULL  -- All categories
    ),

    -- CRI filter (numeric range)
    (
        'cri',
        'numeric_range',
        'CRI (Color Rendering Index)',
        'EF000005',  -- UPDATE THIS
        NULL,
        'slider',
        '{"min": 70, "max": 98, "step": 1, "unit": "Ra"}'::jsonb,
        50,
        ARRAY['LUM', 'LAMP']
    ),

    -- Beam Angle filter (numeric range)
    (
        'beam_angle',
        'numeric_range',
        'Beam Angle',
        'EF000006',  -- UPDATE THIS
        'EU570004',  -- UPDATE THIS (degrees unit)
        'slider',
        '{"min": 0, "max": 360, "step": 5, "unit": "°"}'::jsonb,
        60,
        ARRAY['LUM']  -- Only for luminaires
    ),

    -- Voltage filter (numeric range)
    (
        'voltage',
        'numeric_range',
        'Voltage',
        'EF000007',  -- UPDATE THIS
        'EU570005',  -- UPDATE THIS (volt unit)
        'slider',
        '{"min": 12, "max": 240, "step": 12, "unit": "V"}'::jsonb,
        70,
        NULL  -- All categories
    ),

    -- Dimmable filter (boolean checkbox)
    (
        'dimmable',
        'boolean',
        'Dimmable',
        'EF000008',  -- UPDATE THIS
        NULL,
        'checkbox',
        NULL,
        80,
        ARRAY['LUM', 'LAMP']
    );

-- Verification
SELECT
    filter_key,
    filter_type,
    label,
    etim_feature_id,
    ui_component,
    display_order
FROM search.filter_definitions
ORDER BY display_order;

RAISE NOTICE 'Filter definitions created successfully!';
RAISE NOTICE 'Next step: Run 06-refresh-and-verify.sql';
*/

-- =====================================================
-- Alternative: Manual Entry Template
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'MANUAL FILTER DEFINITION TEMPLATE';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Use this template to add filters manually:';
    RAISE NOTICE '';
    RAISE NOTICE 'INSERT INTO search.filter_definitions (';
    RAISE NOTICE '    filter_key, filter_type, label,';
    RAISE NOTICE '    etim_feature_id, ui_component, display_order';
    RAISE NOTICE ') VALUES (';
    RAISE NOTICE '    ''power'',          -- filter_key';
    RAISE NOTICE '    ''numeric_range'',  -- filter_type';
    RAISE NOTICE '    ''Power'',          -- label';
    RAISE NOTICE '    ''EF______'',       -- YOUR ETIM FEATURE ID HERE';
    RAISE NOTICE '    ''slider'',         -- ui_component';
    RAISE NOTICE '    10                -- display_order';
    RAISE NOTICE ');';
    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
END $$;

-- =====================================================
-- Check current filter definitions
-- =====================================================

SELECT
    COUNT(*) as total_filters,
    COUNT(*) FILTER (WHERE filter_type = 'numeric_range') as numeric_filters,
    COUNT(*) FILTER (WHERE filter_type = 'alphanumeric') as alphanumeric_filters,
    COUNT(*) FILTER (WHERE filter_type = 'boolean') as boolean_filters
FROM search.filter_definitions;

DO $$
DECLARE
    filter_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO filter_count FROM search.filter_definitions;

    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    IF filter_count = 0 THEN
        RAISE NOTICE 'NO FILTERS DEFINED YET';
        RAISE NOTICE '===============================================';
        RAISE NOTICE 'Action required:';
        RAISE NOTICE '  1. Run the ETIM feature queries above';
        RAISE NOTICE '  2. Note the feature IDs';
        RAISE NOTICE '  3. Uncomment and update INSERT statements';
        RAISE NOTICE '  4. Run this file again';
    ELSE
        RAISE NOTICE 'Filter Definitions: % filters', filter_count;
        RAISE NOTICE '===============================================';
        RAISE NOTICE 'Filters are ready!';
        RAISE NOTICE 'Next step: Run 06-refresh-and-verify.sql';
    END IF;
    RAISE NOTICE '';
END $$;
