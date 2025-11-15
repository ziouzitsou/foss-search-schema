-- =====================================================
-- File: 02-populate-taxonomy.sql
-- Purpose: Populate taxonomy hierarchy (English only)
-- Database: Foss SA Supabase
-- =====================================================

-- =====================================================
-- Level 0: Root
-- =====================================================

INSERT INTO search.taxonomy (code, parent_code, level, name, description, display_order)
VALUES
    ('ROOT', NULL, 0, 'Products', 'All products in catalog', 0);

-- =====================================================
-- Level 1: Main Categories (Based on ETIM Groups)
-- =====================================================

INSERT INTO search.taxonomy (code, parent_code, level, name, description, display_order)
VALUES
    -- Luminaires (EG000027) - 89.5% of products
    ('LUM', 'ROOT', 1, 'Luminaires', 'Lighting fixtures and systems', 10),

    -- Lamps (EG000028) - 0.3% of products
    ('LAMP', 'ROOT', 1, 'Lamps', 'Light sources and bulbs', 20),

    -- Accessories (EG000030 excluding EC002710) - 9.5% of products
    ('ACC', 'ROOT', 1, 'Accessories', 'Lighting accessories and components', 30),

    -- Drivers (EG000030 + EC002710) - 0.6% of products
    ('DRV', 'ROOT', 1, 'Drivers', 'LED drivers and power supplies', 40);

-- =====================================================
-- Level 2: Luminaire Subcategories (Mounting Location)
-- =====================================================

INSERT INTO search.taxonomy (code, parent_code, level, name, description, display_order)
VALUES
    -- Mounting locations
    ('LUM_CEIL', 'LUM', 2, 'Ceiling', 'Ceiling-mounted luminaires', 10),
    ('LUM_WALL', 'LUM', 2, 'Wall', 'Wall-mounted luminaires', 20),
    ('LUM_FLOOR', 'LUM', 2, 'Floor', 'Floor-mounted and ground luminaires', 30),
    ('LUM_PEND', 'LUM', 2, 'Pendant', 'Pendant and suspended luminaires', 40),
    ('LUM_DECO', 'LUM', 2, 'Decorative', 'Decorative lighting fixtures', 50);

-- =====================================================
-- Level 3: Ceiling Installation Types
-- =====================================================

INSERT INTO search.taxonomy (code, parent_code, level, name, description, display_order)
VALUES
    ('LUM_CEIL_REC', 'LUM_CEIL', 3, 'Recessed', 'Recessed ceiling fixtures', 10),
    ('LUM_CEIL_SURF', 'LUM_CEIL', 3, 'Surface-mounted', 'Surface-mounted ceiling fixtures', 20),
    ('LUM_CEIL_SUSP', 'LUM_CEIL', 3, 'Suspended', 'Suspended ceiling fixtures', 30);

-- =====================================================
-- Level 3: Wall Installation Types
-- =====================================================

INSERT INTO search.taxonomy (code, parent_code, level, name, description, display_order)
VALUES
    ('LUM_WALL_REC', 'LUM_WALL', 3, 'Recessed', 'Recessed wall fixtures', 10),
    ('LUM_WALL_SURF', 'LUM_WALL', 3, 'Surface-mounted', 'Surface-mounted wall fixtures', 20);

-- =====================================================
-- Level 3: Floor Installation Types
-- =====================================================

INSERT INTO search.taxonomy (code, parent_code, level, name, description, display_order)
VALUES
    ('LUM_FLOOR_REC', 'LUM_FLOOR', 3, 'Recessed', 'Recessed floor fixtures (in-ground)', 10),
    ('LUM_FLOOR_SURF', 'LUM_FLOOR', 3, 'Surface-mounted', 'Surface-mounted floor fixtures', 20);

-- =====================================================
-- Compute full_path for all taxonomy entries
-- =====================================================

-- Update full_path arrays using recursive CTE
WITH RECURSIVE taxonomy_paths AS (
    -- Start with root nodes
    SELECT
        code,
        ARRAY[code] as path
    FROM search.taxonomy
    WHERE parent_code IS NULL

    UNION ALL

    -- Recursively add children
    SELECT
        t.code,
        tp.path || t.code
    FROM search.taxonomy t
    INNER JOIN taxonomy_paths tp ON t.parent_code = tp.code
)
UPDATE search.taxonomy t
SET full_path = tp.path
FROM taxonomy_paths tp
WHERE t.code = tp.code;

-- =====================================================
-- Verification
-- =====================================================

DO $$
DECLARE
    total_count INTEGER;
    level_0_count INTEGER;
    level_1_count INTEGER;
    level_2_count INTEGER;
    level_3_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_count FROM search.taxonomy;
    SELECT COUNT(*) INTO level_0_count FROM search.taxonomy WHERE level = 0;
    SELECT COUNT(*) INTO level_1_count FROM search.taxonomy WHERE level = 1;
    SELECT COUNT(*) INTO level_2_count FROM search.taxonomy WHERE level = 2;
    SELECT COUNT(*) INTO level_3_count FROM search.taxonomy WHERE level = 3;

    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Taxonomy Population Complete!';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Total taxonomy entries: %', total_count;
    RAISE NOTICE '  Level 0 (Root): %', level_0_count;
    RAISE NOTICE '  Level 1 (Main categories): %', level_1_count;
    RAISE NOTICE '  Level 2 (Subcategories): %', level_2_count;
    RAISE NOTICE '  Level 3 (Types): %', level_3_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Main Categories:';
    RAISE NOTICE '  - LUM: Luminaires (13,336 expected products)';
    RAISE NOTICE '  - LAMP: Lamps (50 expected products)';
    RAISE NOTICE '  - ACC: Accessories (1,411 expected products)';
    RAISE NOTICE '  - DRV: Drivers (83 expected products)';
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Run 03-populate-classification-rules.sql';
    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
END $$;

-- Display taxonomy tree
SELECT
    repeat('  ', level) || name as hierarchy,
    code,
    level,
    full_path
FROM search.taxonomy
ORDER BY full_path;
