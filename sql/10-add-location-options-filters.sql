-- =====================================================
-- File: 10-add-location-options-filters.sql
-- Purpose: Add Location and Options filters to filter_definitions
-- Created: 2025-01-21
-- Part of: Taxonomy-Specific Filters - Phase 4
-- =====================================================

-- Add Location filters (applicable only to LUMINAIRE)
INSERT INTO search.filter_definitions
(filter_key, label, filter_type, etim_feature_id, etim_feature_type, ui_config, display_order, applicable_taxonomy_codes, active, description)
VALUES
-- Location category
('indoor', 'Indoor', 'boolean', NULL, 'L',
 '{"filter_category": "location", "icon": "🏠"}',
 100, ARRAY['LUMINAIRE'], true,
 'Suitable for indoor use'),

('outdoor', 'Outdoor', 'boolean', NULL, 'L',
 '{"filter_category": "location", "icon": "🌲"}',
 101, ARRAY['LUMINAIRE'], true,
 'Suitable for outdoor use'),

('submersible', 'Submersible', 'boolean', NULL, 'L',
 '{"filter_category": "location", "icon": "💧"}',
 102, ARRAY['LUMINAIRE'], true,
 'Can be submerged in water'),

-- Options category
('trimless', 'Trimless', 'boolean', NULL, 'L',
 '{"filter_category": "options", "icon": "✂️"}',
 110, ARRAY['LUMINAIRE'], true,
 'Trimless installation (flush with ceiling/wall)'),

('cut_shape_round', 'Round Cut', 'boolean', NULL, 'L',
 '{"filter_category": "options", "icon": "⭕"}',
 111, ARRAY['LUMINAIRE'], true,
 'Requires round cutout'),

('cut_shape_rectangular', 'Rectangular Cut', 'boolean', NULL, 'L',
 '{"filter_category": "options", "icon": "⬜"}',
 112, ARRAY['LUMINAIRE'], true,
 'Requires rectangular cutout')

ON CONFLICT (filter_key) DO UPDATE SET
  label = EXCLUDED.label,
  filter_type = EXCLUDED.filter_type,
  ui_config = EXCLUDED.ui_config,
  display_order = EXCLUDED.display_order,
  applicable_taxonomy_codes = EXCLUDED.applicable_taxonomy_codes,
  active = EXCLUDED.active,
  description = EXCLUDED.description;

-- =====================================================
-- Verification Queries
-- =====================================================

-- Test 1: Verify all 6 filters were added
-- SELECT filter_key, label, applicable_taxonomy_codes, ui_config->'filter_category' as category
-- FROM search.filter_definitions
-- WHERE filter_key IN ('indoor', 'outdoor', 'submersible', 'trimless', 'cut_shape_round', 'cut_shape_rectangular');

-- Test 2: Verify they only show for LUMINAIRE taxonomy
-- SELECT * FROM get_filter_definitions_with_type('LUMINAIRE')
-- WHERE filter_key IN ('indoor', 'outdoor', 'submersible', 'trimless', 'cut_shape_round', 'cut_shape_rectangular');

-- Test 3: Verify they DON'T show for ACCESSORIES taxonomy
-- SELECT * FROM get_filter_definitions_with_type('ACCESSORIES')
-- WHERE filter_key IN ('indoor', 'outdoor', 'submersible', 'trimless', 'cut_shape_round', 'cut_shape_rectangular');
