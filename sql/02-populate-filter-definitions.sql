-- =====================================================================
-- Step 2: Populate search.filter_definitions from Temporary Table
-- =====================================================================
-- Purpose: Migrate ETIM feature mappings from items.product_custom_feature_group
-- Database: FOSSAPP Supabase
-- Date: 2025-01-15
-- Source: items.product_custom_feature_group (custom_group = 'Luminaires', active = true)
-- Target: search.filter_definitions
-- Note: Extract these mappings NOW before the temp table is deprecated!

-- =====================================================================
-- Clear existing filter definitions (if re-running)
-- =====================================================================

-- CAUTION: Uncomment only if you want to start fresh
-- DELETE FROM search.filter_definitions WHERE filter_key IN (
--   SELECT LOWER(REPLACE(custom_feature_name, ' ', '_'))
--   FROM items.product_custom_feature_group
--   WHERE custom_group = 'Luminaires' AND active = true
-- );

-- =====================================================================
-- Phase 1: Core Filters (8 filters - RECOMMENDED START)
-- =====================================================================
-- Migrates Delta Light's Phase 1 filters with highest product coverage

INSERT INTO search.filter_definitions (
  filter_key,
  filter_type,
  label,
  etim_feature_id,
  etim_unit_id,
  display_order,
  ui_component,
  ui_config,
  applicable_taxonomy_codes,
  active
)
VALUES
  -- ELECTRICALS (3 filters)
  ('voltage', 'multi-select', 'Voltage', 'EF005127', NULL, 10,
   'FilterMultiSelect',
   '{"filter_category": "electricals", "show_count": true, "sort_by": "numeric"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  ('dimmable', 'boolean', 'Dimmable', 'EF000137', NULL, 20,
   'FilterBoolean',
   '{"filter_category": "electricals", "true_label": "Yes", "false_label": "No"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  ('class', 'multi-select', 'Protection Class', 'EF000004', NULL, 30,
   'FilterMultiSelect',
   '{"filter_category": "electricals", "show_count": true}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  -- DESIGN (2 filters)
  ('ip', 'multi-select', 'IP Rating', 'EF003118', NULL, 40,
   'FilterMultiSelect',
   '{"filter_category": "design", "show_count": true, "sort_by": "alphanumeric"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  ('finishing_colour', 'multi-select', 'Finishing Colour', 'EF000136', NULL, 50,
   'FilterMultiSelect',
   '{"filter_category": "design", "show_count": true}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  -- LIGHT ENGINE (3 filters)
  ('cct', 'range', 'CCT (K)', 'EF009346', 'EU570172', 60,
   'FilterRange',
   '{"filter_category": "light_engine", "min": 2700, "max": 6500, "step": 100, "unit": "K"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  ('cri', 'multi-select', 'CRI', 'EF000442', NULL, 70,
   'FilterMultiSelect',
   '{"filter_category": "light_engine", "show_count": true, "sort_by": "numeric"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  ('lumens_output', 'range', 'Luminous Flux (lm)', 'EF018714', 'EU570050', 80,
   'FilterRange',
   '{"filter_category": "light_engine", "min": 0, "max": 50000, "step": 100, "unit": "lm"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true)

ON CONFLICT (filter_key) DO UPDATE SET
  filter_type = EXCLUDED.filter_type,
  label = EXCLUDED.label,
  etim_feature_id = EXCLUDED.etim_feature_id,
  etim_unit_id = EXCLUDED.etim_unit_id,
  display_order = EXCLUDED.display_order,
  ui_component = EXCLUDED.ui_component,
  ui_config = EXCLUDED.ui_config,
  applicable_taxonomy_codes = EXCLUDED.applicable_taxonomy_codes,
  active = EXCLUDED.active,
  updated_at = NOW();

-- =====================================================================
-- Phase 2: Advanced Filters (6 filters - ADD AFTER PHASE 1 VALIDATED)
-- =====================================================================
-- Comment out this section initially, uncomment after Phase 1 is working

/*
INSERT INTO search.filter_definitions (
  filter_key,
  filter_type,
  label,
  etim_feature_id,
  display_order,
  ui_component,
  ui_config,
  applicable_taxonomy_codes,
  active
)
VALUES
  -- ELECTRICALS (2 filters)
  ('light_source', 'multi-select', 'Light Source', 'EF000048', 15,
   'FilterMultiSelect',
   '{"filter_category": "electricals", "show_count": true}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  ('dimming_dali', 'boolean', 'Dimming DALI', 'EF012154', 21,
   'FilterBoolean',
   '{"filter_category": "electricals"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  -- DESIGN (2 filters)
  ('ik', 'multi-select', 'IK Rating', 'EF004293', 45,
   'FilterMultiSelect',
   '{"filter_category": "design", "show_count": true}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  ('adjustability', 'boolean', 'Adjustability', 'EF009351', 55,
   'FilterBoolean',
   '{"filter_category": "design"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  -- LIGHT ENGINE (2 filters)
  ('light_distribution', 'multi-select', 'Light Distribution', 'EF004283', 75,
   'FilterMultiSelect',
   '{"filter_category": "light_engine", "show_count": true}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  ('beam_angle', 'range', 'Beam Angle', 'EF008157', 85,
   'FilterRange',
   '{"filter_category": "light_engine", "min": 0, "max": 360, "step": 5, "unit": "°"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true)

ON CONFLICT (filter_key) DO UPDATE SET
  filter_type = EXCLUDED.filter_type,
  label = EXCLUDED.label,
  etim_feature_id = EXCLUDED.etim_feature_id,
  display_order = EXCLUDED.display_order,
  ui_component = EXCLUDED.ui_component,
  ui_config = EXCLUDED.ui_config,
  applicable_taxonomy_codes = EXCLUDED.applicable_taxonomy_codes,
  active = EXCLUDED.active,
  updated_at = NOW();
*/

-- =====================================================================
-- Phase 3: Optional Filters (3 filters - NICE TO HAVE)
-- =====================================================================
-- Comment out this section initially, uncomment after Phase 2 is working

/*
INSERT INTO search.filter_definitions (
  filter_key,
  filter_type,
  label,
  etim_feature_id,
  display_order,
  ui_component,
  ui_config,
  applicable_taxonomy_codes,
  active
)
VALUES
  -- ELECTRICALS (1 filter)
  ('driver_included', 'boolean', 'Driver Included', 'EF007556', 25,
   'FilterBoolean',
   '{"filter_category": "electricals"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  -- DESIGN (1 filter)
  ('builtin_height', 'range', 'Min. Recessed Depth (mm)', 'EF010795', 52,
   'FilterRange',
   '{"filter_category": "design", "min": 0, "max": 500, "step": 10, "unit": "mm"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  -- LIGHT ENGINE (1 filter)
  ('efficacy', 'range', 'Efficacy (lm/W)', 'EF018713', 77,
   'FilterRange',
   '{"filter_category": "light_engine", "min": 0, "max": 200, "step": 5, "unit": "lm/W"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true)

ON CONFLICT (filter_key) DO UPDATE SET
  filter_type = EXCLUDED.filter_type,
  label = EXCLUDED.label,
  etim_feature_id = EXCLUDED.etim_feature_id,
  display_order = EXCLUDED.display_order,
  ui_component = EXCLUDED.ui_component,
  ui_config = EXCLUDED.ui_config,
  applicable_taxonomy_codes = EXCLUDED.applicable_taxonomy_codes,
  active = EXCLUDED.active,
  updated_at = NOW();
*/

-- =====================================================================
-- BONUS Filters: Features from temp table NOT in Delta (Optional)
-- =====================================================================
-- Uncomment these if you want additional filters beyond Delta's set

/*
INSERT INTO search.filter_definitions (
  filter_key,
  filter_type,
  label,
  etim_feature_id,
  display_order,
  ui_component,
  ui_config,
  applicable_taxonomy_codes,
  active
)
VALUES
  -- ELECTRICALS (Bonus)
  ('max_power', 'range', 'Max Power (W)', 'EF009347', 26,
   'FilterRange',
   '{"filter_category": "electricals", "min": 0, "max": 500, "step": 5, "unit": "W"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  ('current', 'range', 'Current (mA)', 'EF009345', 27,
   'FilterRange',
   '{"filter_category": "electricals", "min": 0, "max": 5000, "step": 50, "unit": "mA"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  -- DESIGN (Bonus)
  ('material', 'multi-select', 'Material', 'EF001596', 56,
   'FilterMultiSelect',
   '{"filter_category": "design", "show_count": true}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  ('height_or_depth', 'range', 'Height/Depth (mm)', 'EF001456', 57,
   'FilterRange',
   '{"filter_category": "design", "min": 0, "max": 1000, "step": 10, "unit": "mm"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  ('outer_diameter', 'range', 'Outer Diameter (mm)', 'EF000015', 58,
   'FilterRange',
   '{"filter_category": "design", "min": 0, "max": 500, "step": 10, "unit": "mm"}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true),

  -- LIGHT ENGINE (Bonus)
  ('colour_consistency', 'multi-select', 'Colour Consistency (McAdam)', 'EF011946', 76,
   'FilterMultiSelect',
   '{"filter_category": "light_engine", "show_count": true}'::jsonb,
   ARRAY['LUMINAIRE']::text[], true)

ON CONFLICT (filter_key) DO UPDATE SET
  filter_type = EXCLUDED.filter_type,
  label = EXCLUDED.label,
  etim_feature_id = EXCLUDED.etim_feature_id,
  display_order = EXCLUDED.display_order,
  ui_component = EXCLUDED.ui_component,
  ui_config = EXCLUDED.ui_config,
  applicable_taxonomy_codes = EXCLUDED.applicable_taxonomy_codes,
  active = EXCLUDED.active,
  updated_at = NOW();
*/

-- =====================================================================
-- Verification: Show what was inserted
-- =====================================================================

SELECT
  filter_key,
  label,
  filter_type,
  etim_feature_id,
  ui_config->>'filter_category' as category,
  display_order,
  active
FROM search.filter_definitions
WHERE applicable_taxonomy_codes @> ARRAY['LUMINAIRE']::text[]
ORDER BY display_order;

-- =====================================================================
-- Completion Message
-- =====================================================================

DO $$
DECLARE
  filter_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO filter_count
  FROM search.filter_definitions
  WHERE applicable_taxonomy_codes @> ARRAY['LUMINAIRE']::text[]
    AND active = true;

  RAISE NOTICE '✅ Filter definitions populated successfully!';
  RAISE NOTICE '   - % active filters for luminaires', filter_count;
  RAISE NOTICE '';
  RAISE NOTICE '⚡ Phase 1 (8 core filters) is now configured';
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '   1. Run 03-populate-filter-index.sql to index products';
  RAISE NOTICE '   2. REFRESH MATERIALIZED VIEW search.filter_facets;';
  RAISE NOTICE '   3. Test in UI with Phase 1 filters';
  RAISE NOTICE '   4. Uncomment Phase 2 & 3 when ready to expand';
END $$;
