-- =====================================================
-- File: 10-create-filter-definitions-function.sql
-- Purpose: Create RPC function for taxonomy-specific filter loading
-- Created: 2025-01-21
-- Part of: Phase 1 - Taxonomy-Specific Filters Implementation
-- =====================================================

-- Drop existing functions if they exist (may be in Supabase console or previous migrations)
DROP FUNCTION IF EXISTS search.get_filter_definitions_with_type(TEXT);
DROP FUNCTION IF EXISTS public.get_filter_definitions_with_type(TEXT);

-- =====================================================
-- search.get_filter_definitions_with_type()
-- Returns filter definitions for a specific taxonomy
-- =====================================================

CREATE OR REPLACE FUNCTION search.get_filter_definitions_with_type(
    p_taxonomy_code TEXT DEFAULT 'LUMINAIRE'
)
RETURNS TABLE (
    filter_key TEXT,
    label TEXT,
    filter_type TEXT,
    etim_feature_id TEXT,
    etim_feature_type TEXT,
    ui_config JSONB,
    display_order INTEGER
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        fd.filter_key,
        fd.label,
        fd.filter_type,
        fd.etim_feature_id,
        'A'::TEXT as etim_feature_type,  -- Default to 'A' (Alphanumeric) - etim.feature table doesn't have TYPE column
        fd.ui_config,
        fd.display_order
    FROM search.filter_definitions fd
    WHERE fd.active = true
      -- ⭐ KEY LOGIC: Filter by taxonomy code
      -- If applicable_taxonomy_codes is NULL → Universal filter (show everywhere)
      -- If taxonomy code is IN the array → Show for this taxonomy
      AND (
        fd.applicable_taxonomy_codes IS NULL
        OR p_taxonomy_code = ANY(fd.applicable_taxonomy_codes)
      )
    ORDER BY fd.display_order;
END;
$$;

COMMENT ON FUNCTION search.get_filter_definitions_with_type IS
'Returns filter definitions applicable to a specific taxonomy code.

Filters with NULL applicable_taxonomy_codes are universal (shown everywhere).
Filters with taxonomy codes only appear when that taxonomy is selected.

Examples:
  - applicable_taxonomy_codes = NULL → Shows in all categories
  - applicable_taxonomy_codes = ARRAY[''LUMINAIRE''] → Shows only in Luminaires
  - applicable_taxonomy_codes = ARRAY[''LUMINAIRE'', ''ACCESSORIES''] → Shows in both

Parameters:
  - p_taxonomy_code: Taxonomy code to get filters for (e.g., ''LUMINAIRE'', ''ACCESSORIES'', ''DRIVERS'')

Returns:
  - filter_key: Unique filter identifier
  - label: Display label for the filter
  - filter_type: Type of filter (boolean, multi-select, range)
  - etim_feature_id: ETIM feature this filter maps to
  - etim_feature_type: ETIM data type (A=Alphanumeric, L=Logical, N=Numeric, R=Range)
  - ui_config: JSONB configuration for UI rendering
  - display_order: Sort order for displaying filters
';

-- =====================================================
-- Public wrapper (for anon/authenticated access)
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_filter_definitions_with_type(
    p_taxonomy_code TEXT DEFAULT 'LUMINAIRE'
)
RETURNS TABLE (
    filter_key TEXT,
    label TEXT,
    filter_type TEXT,
    etim_feature_id TEXT,
    etim_feature_type TEXT,
    ui_config JSONB,
    display_order INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM search.get_filter_definitions_with_type(p_taxonomy_code);
END;
$$;

-- Grant permissions for public access (required for search UI)
GRANT EXECUTE ON FUNCTION public.get_filter_definitions_with_type(TEXT) TO anon, authenticated;

COMMENT ON FUNCTION public.get_filter_definitions_with_type IS
'Public wrapper for search.get_filter_definitions_with_type().
Returns taxonomy-specific filter definitions for the search UI.

Security: SECURITY DEFINER allows anon/authenticated users to query search.filter_definitions
through this function without direct table access.

Usage from frontend:
  const { data } = await supabase.rpc(''get_filter_definitions_with_type'', {
    p_taxonomy_code: ''LUMINAIRE''
  })
';

-- =====================================================
-- Verification Queries (Run these after deployment)
-- =====================================================

-- Test 1: Get LUMINAIRE filters (should return 8 filters)
-- SELECT * FROM get_filter_definitions_with_type('LUMINAIRE');

-- Test 2: Get ACCESSORIES filters (should return 0 currently - all marked as LUMINAIRE)
-- SELECT * FROM get_filter_definitions_with_type('ACCESSORIES');

-- Test 3: Get DRIVERS filters (should return 0 currently)
-- SELECT * FROM get_filter_definitions_with_type('DRIVERS');

-- Test 4: Check what taxonomy codes are configured for each filter
-- SELECT
--   filter_key,
--   label,
--   applicable_taxonomy_codes,
--   CASE
--     WHEN applicable_taxonomy_codes IS NULL THEN 'Universal (all categories)'
--     ELSE array_to_string(applicable_taxonomy_codes, ', ')
--   END as applies_to
-- FROM search.filter_definitions
-- WHERE active = true
-- ORDER BY display_order;
