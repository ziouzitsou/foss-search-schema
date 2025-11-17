-- =====================================================================
-- 02-populate-example-data.sql
-- =====================================================================
-- Populates configuration tables with example data
-- Uses ACTUAL ETIM IDs from the Foss SA database
-- =====================================================================

-- =====================================================================
-- 1. POPULATE TAXONOMY
-- =====================================================================

INSERT INTO search.taxonomy (code, parent_code, level, name_el, name_en, description_el, description_en, display_order, full_path)
VALUES
    -- Root
    ('LUM', NULL, 0, 'Φωτιστικά', 'Luminaires', 'Όλα τα φωτιστικά', 'All luminaires', 1, ARRAY['LUM']),

    -- Level 1: Indoor/Outdoor
    ('LUM_IND', 'LUM', 1, 'Εσωτερικού χώρου', 'Indoor', 'Φωτιστικά εσωτερικού χώρου', 'Indoor luminaires', 1, ARRAY['LUM', 'LUM_IND']),
    ('LUM_OUT', 'LUM', 1, 'Εξωτερικού χώρου', 'Outdoor', 'Φωτιστικά εξωτερικού χώρου', 'Outdoor luminaires', 2, ARRAY['LUM', 'LUM_OUT']),

    -- Level 2: Indoor mounting types
    ('LUM_IND_CEIL', 'LUM_IND', 2, 'Οροφής', 'Ceiling', 'Φωτιστικά οροφής', 'Ceiling luminaires', 1, ARRAY['LUM', 'LUM_IND', 'LUM_IND_CEIL']),
    ('LUM_IND_WALL', 'LUM_IND', 2, 'Τοίχου', 'Wall', 'Φωτιστικά τοίχου', 'Wall luminaires', 2, ARRAY['LUM', 'LUM_IND', 'LUM_IND_WALL']),
    ('LUM_IND_PEND', 'LUM_IND', 2, 'Κρεμαστά', 'Pendant', 'Κρεμαστά φωτιστικά', 'Pendant luminaires', 3, ARRAY['LUM', 'LUM_IND', 'LUM_IND_PEND']),
    ('LUM_IND_FLOOR', 'LUM_IND', 2, 'Δαπέδου', 'Floor', 'Φωτιστικά δαπέδου', 'Floor luminaires', 4, ARRAY['LUM', 'LUM_IND', 'LUM_IND_FLOOR']),
    ('LUM_IND_TRACK', 'LUM_IND', 2, 'Ράγας', 'Track', 'Φωτιστικά ράγας', 'Track luminaires', 5, ARRAY['LUM', 'LUM_IND', 'LUM_IND_TRACK']),

    -- Level 3: Indoor ceiling subtypes
    ('LUM_IND_CEIL_REC', 'LUM_IND_CEIL', 3, 'Χωνευτά', 'Recessed', 'Χωνευτά φωτιστικά οροφής', 'Recessed ceiling luminaires', 1, ARRAY['LUM', 'LUM_IND', 'LUM_IND_CEIL', 'LUM_IND_CEIL_REC']),
    ('LUM_IND_CEIL_SURF', 'LUM_IND_CEIL', 3, 'Επιφανείας', 'Surface-mounted', 'Φωτιστικά επιφανείας οροφής', 'Surface-mounted ceiling luminaires', 2, ARRAY['LUM', 'LUM_IND', 'LUM_IND_CEIL', 'LUM_IND_CEIL_SURF']),

    -- Level 2: Outdoor types
    ('LUM_OUT_WALL', 'LUM_OUT', 2, 'Τοίχου', 'Wall', 'Φωτιστικά τοίχου εξωτερικού χώρου', 'Outdoor wall luminaires', 1, ARRAY['LUM', 'LUM_OUT', 'LUM_OUT_WALL']),
    ('LUM_OUT_GROUND', 'LUM_OUT', 2, 'Εδάφους', 'Ground', 'Φωτιστικά εδάφους', 'Ground luminaires', 2, ARRAY['LUM', 'LUM_OUT', 'LUM_OUT_GROUND']),
    ('LUM_OUT_BOLLARD', 'LUM_OUT', 2, 'Πασσάλου', 'Bollard', 'Φωτιστικά πασσάλου', 'Bollard luminaires', 3, ARRAY['LUM', 'LUM_OUT', 'LUM_OUT_BOLLARD']),
    ('LUM_OUT_STREET', 'LUM_OUT', 2, 'Οδοφωτισμός', 'Street', 'Φωτιστικά δρόμου', 'Street luminaires', 4, ARRAY['LUM', 'LUM_OUT', 'LUM_OUT_STREET'])
ON CONFLICT (code) DO NOTHING;

-- =====================================================================
-- 2. POPULATE CLASSIFICATION RULES
-- =====================================================================
-- Using ACTUAL ETIM Groups and Classes from Foss SA database

INSERT INTO search.classification_rules (rule_name, description, taxonomy_code, flag_name, etim_group_ids, etim_class_ids, priority)
VALUES
    -- Main luminaires group (13,336 products)
    ('all_luminaires', 'All luminaire products', 'LUM', NULL, ARRAY['EG000027'], NULL, 1),

    -- Indoor/Outdoor based on common classes
    ('indoor_downlights', 'Indoor downlights and spots', 'LUM_IND_CEIL', 'indoor', NULL, ARRAY['EC001744'], 10),
    ('indoor_ceiling_wall', 'Indoor ceiling/wall luminaires', 'LUM_IND_CEIL', 'indoor', NULL, ARRAY['EC002892'], 11),
    ('indoor_pendant', 'Indoor pendant luminaires', 'LUM_IND_PEND', 'indoor', NULL, ARRAY['EC001743'], 12),
    ('indoor_floor', 'Indoor floor luminaires', 'LUM_IND_FLOOR', 'indoor', NULL, ARRAY['EC000300'], 13),
    ('indoor_track', 'Indoor track systems', 'LUM_IND_TRACK', 'indoor', NULL, ARRAY['EC000101', 'EC000986'], 14),

    -- Outdoor types
    ('outdoor_ground', 'Outdoor ground luminaires', 'LUM_OUT_GROUND', 'outdoor', NULL, ARRAY['EC000758'], 20),
    ('outdoor_bollard', 'Outdoor bollard luminaires', 'LUM_OUT_BOLLARD', 'outdoor', NULL, ARRAY['EC000301'], 21),
    ('outdoor_street', 'Outdoor street luminaires', 'LUM_OUT_STREET', 'outdoor', NULL, ARRAY['EC000062'], 22),
    ('outdoor_orientation', 'Outdoor orientation lights', 'LUM_OUT', 'outdoor', NULL, ARRAY['EC000481'], 23)
ON CONFLICT (rule_name) DO NOTHING;

-- Feature-based rules (using actual ETIM feature IDs)
INSERT INTO search.classification_rules (rule_name, description, flag_name, etim_feature_conditions, priority)
VALUES
    ('dimmable_feature', 'Products with dimmable feature', 'dimmable',
     '{"EF000137": {"operator": "equals", "value": "true"}}'::jsonb, 30)
ON CONFLICT (rule_name) DO NOTHING;

-- =====================================================================
-- 3. POPULATE FILTER DEFINITIONS
-- =====================================================================
-- Using ACTUAL ETIM Feature IDs from Foss SA database

INSERT INTO search.filter_definitions (
    filter_key, filter_type, label_el, label_en,
    etim_feature_id, etim_unit_id, display_order, ui_component, ui_config
)
VALUES
    -- Power filter (EF000280 = "Suitable for lamp power")
    ('power', 'numeric_range', 'Ισχύς', 'Power',
     'EF000280', 'EU570054', 1, 'slider',
     '{"min": 0, "max": 300, "step": 5, "unit": "W"}'::jsonb),

    -- IP Rating filter (EF005474 = "Degree of protection (IP)")
    ('ip_rating', 'alphanumeric', 'Βαθμός προστασίας IP', 'IP Rating',
     'EF005474', NULL, 2, 'multiselect',
     '{"options": ["IP20", "IP44", "IP54", "IP65", "IP67", "IP68"]}'::jsonb),

    -- Dimmable filter (EF000137 = "Dimmable")
    ('dimmable', 'boolean', 'Με δυνατότητα dimming', 'Dimmable',
     'EF000137', NULL, 3, 'checkbox', '{}'::jsonb),

    -- Color temperature (EF009346 = "Colour temperature")
    ('color_temp', 'numeric_range', 'Θερμοκρασία χρώματος', 'Color Temperature',
     'EF009346', 'EU570076', 4, 'slider',
     '{"min": 2000, "max": 6500, "step": 100, "unit": "K"}'::jsonb),

    -- Luminous flux (EF018714 = "Rated luminous flux according to IEC 62722-2-1")
    ('luminous_flux', 'numeric_range', 'Φωτεινή ροή', 'Luminous Flux',
     'EF018714', 'EU570108', 5, 'slider',
     '{"min": 0, "max": 10000, "step": 100, "unit": "lm"}'::jsonb)
ON CONFLICT (filter_key) DO NOTHING;

-- =====================================================================
-- SUCCESS MESSAGE
-- =====================================================================

DO $$
DECLARE
    taxonomy_count INTEGER;
    rules_count INTEGER;
    filters_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO taxonomy_count FROM search.taxonomy WHERE active = true;
    SELECT COUNT(*) INTO rules_count FROM search.classification_rules WHERE active = true;
    SELECT COUNT(*) INTO filters_count FROM search.filter_definitions WHERE active = true;

    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE 'Example data populated successfully!';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Statistics:';
    RAISE NOTICE '  ✓ Taxonomy nodes: %', taxonomy_count;
    RAISE NOTICE '  ✓ Classification rules: %', rules_count;
    RAISE NOTICE '  ✓ Filter definitions: %', filters_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Using ACTUAL ETIM IDs from Foss SA database:';
    RAISE NOTICE '  • EF000280 = Suitable for lamp power';
    RAISE NOTICE '  • EF000137 = Dimmable';
    RAISE NOTICE '  • EF009346 = Colour temperature';
    RAISE NOTICE '  • EF005474 = Degree of protection (IP)';
    RAISE NOTICE '  • EF018714 = Rated luminous flux';
    RAISE NOTICE '';
    RAISE NOTICE '  • EG000027 = Luminaires (13,336 products)';
    RAISE NOTICE '  • EC001744 = Downlight/spot/floodlight (5,794 products)';
    RAISE NOTICE '  • EC002892 = Ceiling-/wall luminaire (1,566 products)';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Run 03-create-materialized-views.sql';
    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
END $$;
