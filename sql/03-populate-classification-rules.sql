-- =====================================================
-- File: 03-populate-classification-rules.sql
-- Purpose: Populate classification rules (migrated from items.category_switches)
-- Database: Foss SA Supabase
-- =====================================================

-- =====================================================
-- PART 1: Add Additional Taxonomy Entries
-- (Special categories, pendant, track accessories, driver types, lamp types)
-- =====================================================

INSERT INTO search.taxonomy (code, parent_code, level, name, description, display_order)
VALUES
    -- Special luminaire category (Level 2)
    ('LUM_SPEC', 'LUM', 2, 'Special', 'Special purpose lighting', 60),

    -- Special luminaire types (Level 3)
    ('LUM_SPEC_STRIP', 'LUM_SPEC', 3, 'LED Strips', 'LED strip lights', 10),
    ('LUM_SPEC_TRACK', 'LUM_SPEC', 3, 'Track Systems', 'Track lighting systems', 20),
    ('LUM_SPEC_BATTEN', 'LUM_SPEC', 3, 'Batten', 'Batten lights', 30),
    ('LUM_SPEC_POLE', 'LUM_SPEC', 3, 'Pole-mounted', 'Pole-mounted fixtures', 40),

    -- Decorative types (Level 3)
    ('LUM_DECO_TABLE', 'LUM_DECO', 3, 'Table Lamps', 'Decorative table lamps', 10),
    ('LUM_DECO_PEND', 'LUM_DECO', 3, 'Pendant Lights', 'Decorative pendant lights', 20),
    ('LUM_DECO_FLOOR', 'LUM_DECO', 3, 'Floor Lamps', 'Decorative floor lamps', 30),

    -- Accessory categories (Level 2)
    ('ACC_TRACK', 'ACC', 2, 'Track Components', 'Track system components and spares', 10),
    ('ACC_TRACK_PROF', 'ACC_TRACK', 3, 'Track Profiles', 'Track profiles for lighting systems', 10),
    ('ACC_TRACK_SPARE', 'ACC_TRACK', 3, 'Track Spares', 'Spare parts for track systems', 20),

    -- Driver types (Level 2)
    ('DRV_CC', 'DRV', 2, 'Constant Current', 'Constant current LED drivers', 10),
    ('DRV_CV', 'DRV', 2, 'Constant Voltage', 'Constant voltage LED drivers', 20),

    -- Lamp types (Level 2)
    ('LAMP_FIL', 'LAMP', 2, 'Filament Lamps', 'Filament light sources', 10),
    ('LAMP_MOD', 'LAMP', 2, 'LED Modules', 'LED modules and arrays', 20);

-- Update full_path for new entries
WITH RECURSIVE taxonomy_paths AS (
    SELECT code, ARRAY[code] as path
    FROM search.taxonomy
    WHERE parent_code IS NULL

    UNION ALL

    SELECT t.code, tp.path || t.code
    FROM search.taxonomy t
    INNER JOIN taxonomy_paths tp ON t.parent_code = tp.code
)
UPDATE search.taxonomy t
SET full_path = tp.path
FROM taxonomy_paths tp
WHERE t.code = tp.code AND t.full_path IS NULL;

-- =====================================================
-- PART 2: Root Category Classification Rules
-- Priority 1-20 (highest priority)
-- =====================================================

INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_group_ids, etim_class_ids, priority)
VALUES
    -- Drivers MUST be checked first (priority=5) because they share EG000030 with accessories
    -- FIXED: Remove etim_group_ids to match ONLY class EC002710 (83 products), not all EG000030 (1,494)
    ('drivers_root', 'LED drivers and power supplies (EC002710 only)', 'DRV', 'driver',
     NULL, ARRAY['EC002710'], 5),

    -- Root categories (priority=10)
    ('luminaires_root', 'Lighting fixtures', 'LUM', 'luminaire',
     ARRAY['EG000027'], NULL, 10),

    ('lamps_root', 'Light sources and lamps', 'LAMP', 'lamp',
     ARRAY['EG000028'], NULL, 10),

    -- Accessories checked after drivers (priority=20)
    ('accessories_root', 'Lighting accessories (excluding drivers)', 'ACC', 'accessory',
     ARRAY['EG000030'], NULL, 20);

-- =====================================================
-- PART 3: Text Pattern Rules (Indoor/Outdoor/Special)
-- Priority 100 (applied to all products)
-- =====================================================

INSERT INTO search.classification_rules (rule_name, description, flag_name, text_pattern, priority)
VALUES
    ('indoor_detection', 'Indoor lighting detection', 'indoor',
     'indoor|interior|internal', 100),

    ('outdoor_detection', 'Outdoor lighting detection', 'outdoor',
     'outdoor|exterior|external|garden', 100),

    ('submersible_detection', 'Submersible/waterproof detection', 'submersible',
     'submersible|waterproof|underwater', 100),

    ('trimless_detection', 'Trimless fixture detection', 'trimless',
     'trimless|plaster', 100);

-- =====================================================
-- PART 4: Luminaire Mounting Location Rules
-- Priority 30-40 (Level 2 categories)
-- =====================================================

-- Ceiling luminaires (combined rule: classes + feature)
INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_class_ids, etim_feature_conditions, priority)
VALUES
    ('ceiling_luminaires', 'Ceiling-mountable fixtures', 'LUM_CEIL', 'ceiling',
     ARRAY['EC001744', 'EC002892'],
     '{"EF021180": {"operator": "exists"}}'::jsonb, 30);

-- Wall luminaires (custom rule: classes + feature)
INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_class_ids, etim_feature_conditions, priority)
VALUES
    ('wall_luminaires', 'Wall-mountable fixtures', 'LUM_WALL', 'wall',
     ARRAY['EC001744', 'EC002892', 'EC000481'],
     '{"EF000664": {"operator": "exists"}}'::jsonb, 30);

-- Floor luminaires (custom rule: multiple classes)
INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_class_ids, priority)
VALUES
    ('floor_luminaires', 'Floor-mountable fixtures', 'LUM_FLOOR', 'floor',
     ARRAY['EC000758', 'EC000301', 'EC000300', 'EC002892', 'EC000481'], 30);

-- =====================================================
-- PART 5: Luminaire Installation Type Rules
-- Priority 50-60 (Level 3 categories)
-- =====================================================
-- IMPORTANT: These ETIM features (EF006760, EF007793, EF001265) don't exist in ANY products!
-- These rules are created but immediately disabled. Use text patterns instead if needed.
-- =====================================================

-- Recessed fixtures (feature-based)
INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_feature_conditions, priority, active)
VALUES
    ('recessed_fixtures', 'Recessed installation type (DISABLED - feature does not exist)', NULL, 'recessed',
     '{"EF006760": {"operator": "exists"}}'::jsonb, 50, false);

-- Surface-mounted fixtures (feature-based)
INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_feature_conditions, priority, active)
VALUES
    ('surface_mounted_fixtures', 'Surface-mounted installation type (DISABLED - feature does not exist)', NULL, 'surface_mounted',
     '{"EF007793": {"operator": "exists"}}'::jsonb, 50, false);

-- Suspended fixtures (feature-based)
INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_feature_conditions, priority, active)
VALUES
    ('suspended_fixtures', 'Suspended installation type (DISABLED - feature does not exist)', NULL, 'suspended',
     '{"EF001265": {"operator": "exists"}}'::jsonb, 50, false);

-- Specific installation combinations
INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_feature_conditions, priority, active)
VALUES
    ('ceiling_recessed', 'Recessed ceiling fixtures (DISABLED - feature does not exist)', 'LUM_CEIL_REC', 'ceiling_recessed',
     '{"EF006760": {"operator": "exists"}}'::jsonb, 60, false),

    ('ceiling_surface', 'Surface-mounted ceiling fixtures (DISABLED - feature does not exist)', 'LUM_CEIL_SURF', 'ceiling_surface',
     '{"EF007793": {"operator": "exists"}}'::jsonb, 60, false),

    ('ceiling_suspended', 'Suspended ceiling fixtures (DISABLED - feature does not exist)', 'LUM_CEIL_SUSP', 'ceiling_suspended',
     '{"EF001265": {"operator": "exists"}}'::jsonb, 60, false),

    ('wall_recessed', 'Recessed wall fixtures (DISABLED - feature does not exist)', 'LUM_WALL_REC', 'wall_recessed',
     '{"EF006760": {"operator": "exists"}}'::jsonb, 60, false),

    ('wall_surface', 'Surface-mounted wall fixtures (DISABLED - feature does not exist)', 'LUM_WALL_SURF', 'wall_surface',
     '{"EF007793": {"operator": "exists"}}'::jsonb, 60, false);

-- Floor installation types (class-based)
INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_class_ids, priority)
VALUES
    ('floor_recessed', 'Recessed floor fixtures (in-ground)', 'LUM_FLOOR_REC', 'floor_recessed',
     ARRAY['EC000758'], 60),

    ('floor_surface', 'Surface-mounted floor fixtures', 'LUM_FLOOR_SURF', 'floor_surface',
     ARRAY['EC000301'], 60);

-- =====================================================
-- PART 6: Decorative Luminaire Rules
-- Priority 70
-- =====================================================

INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_class_ids, priority)
VALUES
    ('decorative_table', 'Decorative table lamps', 'LUM_DECO_TABLE', 'decorative_table',
     ARRAY['EC000302'], 70),

    ('decorative_pendant', 'Decorative pendant lights', 'LUM_DECO_PEND', 'decorative_pendant',
     ARRAY['EC001743'], 70),

    ('decorative_floor', 'Decorative floor lamps', 'LUM_DECO_FLOOR', 'decorative_floor',
     ARRAY['EC000300'], 70);

-- =====================================================
-- PART 7: Special Luminaire Rules
-- Priority 70
-- =====================================================

INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_class_ids, priority)
VALUES
    ('special_strips', 'LED strip lights', 'LUM_SPEC_STRIP', 'led_strip',
     ARRAY['EC002706'], 70),

    ('special_tracks', 'Track lighting systems', 'LUM_SPEC_TRACK', 'track_system',
     ARRAY['EC000986'], 70),

    ('special_batten', 'Batten lights', 'LUM_SPEC_BATTEN', 'batten',
     ARRAY['EC000109'], 70),

    ('pole_mounted', 'Pole-mounted fixtures', 'LUM_SPEC_POLE', 'pole_mounted',
     ARRAY['EC000062'], 70);

-- =====================================================
-- PART 8: Accessory Subcategory Rules
-- Priority 80
-- =====================================================

INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_class_ids, priority)
VALUES
    ('track_profiles', 'Track profiles for lighting systems', 'ACC_TRACK_PROF', 'track_profile',
     ARRAY['EC000101'], 80),

    ('track_spares', 'Spare parts for track systems', 'ACC_TRACK_SPARE', 'track_spare',
     ARRAY['EC000293'], 80);

-- =====================================================
-- PART 9: Driver Type Rules
-- Priority 80 (subcategories of drivers)
-- =====================================================

INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_group_ids, etim_class_ids, etim_feature_conditions, priority)
VALUES
    ('driver_constant_current', 'Constant current LED drivers', 'DRV_CC', 'constant_current',
     ARRAY['EG000030'], ARRAY['EC002710'],
     '{"EF009471": {"operator": "exists"}}'::jsonb, 80),

    ('driver_constant_voltage', 'Constant voltage LED drivers', 'DRV_CV', 'constant_voltage',
     ARRAY['EG000030'], ARRAY['EC002710'],
     '{"EF009472": {"operator": "exists"}}'::jsonb, 80);

-- =====================================================
-- PART 10: Lamp Type Rules
-- Priority 80
-- =====================================================

INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_class_ids, priority)
VALUES
    ('filament_lamps', 'Filament light sources', 'LAMP_FIL', 'filament',
     ARRAY['EC001959'], 80),

    ('led_modules', 'LED modules and arrays', 'LAMP_MOD', 'led_module',
     ARRAY['EC000996'], 80);

-- =====================================================
-- Verification
-- =====================================================

DO $$
DECLARE
    total_rules INTEGER;
    root_rules INTEGER;
    text_rules INTEGER;
    luminaire_rules INTEGER;
    accessory_rules INTEGER;
    driver_rules INTEGER;
    lamp_rules INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_rules FROM search.classification_rules;
    SELECT COUNT(*) INTO root_rules FROM search.classification_rules WHERE priority <= 20;
    SELECT COUNT(*) INTO text_rules FROM search.classification_rules WHERE text_pattern IS NOT NULL;
    SELECT COUNT(*) INTO luminaire_rules FROM search.classification_rules
        WHERE taxonomy_code LIKE 'LUM%';
    SELECT COUNT(*) INTO accessory_rules FROM search.classification_rules
        WHERE taxonomy_code LIKE 'ACC%';
    SELECT COUNT(*) INTO driver_rules FROM search.classification_rules
        WHERE taxonomy_code LIKE 'DRV%';
    SELECT COUNT(*) INTO lamp_rules FROM search.classification_rules
        WHERE taxonomy_code LIKE 'LAMP%';

    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Classification Rules Migration Complete!';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Total rules created: %', total_rules;
    RAISE NOTICE '  Root category rules: %', root_rules;
    RAISE NOTICE '  Text pattern rules: %', text_rules;
    RAISE NOTICE '  Luminaire rules: %', luminaire_rules;
    RAISE NOTICE '  Accessory rules: %', accessory_rules;
    RAISE NOTICE '  Driver rules: %', driver_rules;
    RAISE NOTICE '  Lamp rules: %', lamp_rules;
    RAISE NOTICE '';
    RAISE NOTICE 'Migrated from items.category_switches:';
    RAISE NOTICE '  - All 35 category switches converted';
    RAISE NOTICE '  - Priority-based rule resolution';
    RAISE NOTICE '  - Drivers override accessories (priority 5 vs 20)';
    RAISE NOTICE '  - Indoor/outdoor detection via text patterns';
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Run 04-create-materialized-views.sql';
    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
END $$;

-- Display rules by priority
SELECT
    priority,
    rule_name,
    flag_name,
    taxonomy_code,
    CASE
        WHEN etim_group_ids IS NOT NULL THEN 'ETIM Group: ' || array_to_string(etim_group_ids, ', ')
        WHEN etim_class_ids IS NOT NULL THEN 'ETIM Class: ' || array_to_string(etim_class_ids, ', ')
        WHEN etim_feature_conditions IS NOT NULL THEN 'Feature Condition'
        WHEN text_pattern IS NOT NULL THEN 'Text Pattern: ' || text_pattern
        ELSE 'No condition'
    END as condition_type
FROM search.classification_rules
ORDER BY priority, rule_name;
