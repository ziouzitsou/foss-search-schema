# Implementation Plan: Taxonomy-Specific Filters

**Status**: 📋 PLANNING PHASE
**Created**: 2025-01-21
**Author**: Claude Code (with Dimitri)
**Priority**: HIGH - Core architectural feature
**Estimated Time**: 4-5 hours total

---

## 🎯 Vision Statement

> "A light engineer should be able to adjust filter definitions in the database (via SQL or future frontend admin app), and the search frontend automatically adapts to show the correct filters for each product category (Luminaires, Accessories, Drivers, etc.). **Zero code changes required.**"

This is the **core architectural principle** of the searchdb system: **Configuration over Code**.

---

## 📊 Current Status Analysis

### ✅ What Works (Database-Driven)

1. **Taxonomy System** - 100% database-driven
   - Tabs dynamically loaded from `search.taxonomy` WHERE `level = 1`
   - Category tree built from `search.taxonomy` parent-child relationships
   - Product counts calculated automatically
   - Adding taxonomy row → Appears in UI immediately

2. **Filter Definitions Exist**
   - Table: `search.filter_definitions`
   - Field: `applicable_taxonomy_codes TEXT[]` (supports taxonomy filtering)
   - 8 Phase 1 filters populated (voltage, dimmable, ip, class, etc.)
   - All currently marked as `ARRAY['LUMINAIRE']`

3. **Dynamic Filter Components**
   - `FilterPanel.tsx` reads filters from database via RPC
   - `BooleanFilter`, `MultiSelectFilter`, `RangeFilter` render based on DB config
   - `ui_config` JSONB controls component behavior
   - `filter_category` groups filters (electricals, design, light_engine)

### ❌ Critical Gaps (Not Yet Database-Driven)

1. **RPC Function Ignores Taxonomy**
   - Function: `get_filter_definitions_with_type(p_taxonomy_code)`
   - Current behavior: Returns ALL active filters (ignores parameter)
   - Expected behavior: Return only filters where `p_taxonomy_code = ANY(applicable_taxonomy_codes)`
   - **Impact**: Clicking Accessories tab still shows Luminaire filters

2. **Frontend Always Uses 'LUMINAIRE'**
   - File: `search-test-app/components/FilterPanel.tsx:36`
   - Hardcoded: `taxonomyCode = 'LUMINAIRE'` (default prop)
   - File: `search-test-app/app/page.tsx:357-370`
   - Condition: `activeTab === 'LUMINAIRE'` before showing FilterPanel
   - **Impact**: Filters never adapt to selected category

3. **All Filters Limited to LUMINAIRE**
   - Database: All 8 filters have `applicable_taxonomy_codes = ARRAY['LUMINAIRE']`
   - Missing: Multi-category filters (IP Rating should apply to all)
   - Missing: Category-specific filters (Material for Accessories, Output Current for Drivers)

### ⚠️ Documentation Gaps

- Docs explain database schema but not the taxonomy-specific vision
- No guide for adding filters for new categories
- No examples of multi-category filter configuration
- Missing: How frontend adapts automatically

---

## 🔧 Implementation Plan

### Phase 1: Create/Fix RPC Function (30 minutes)

**Objective**: Make `get_filter_definitions_with_type()` respect taxonomy filtering

#### Step 1.1: Create SQL File

**File**: `/home/dimitris/foss/searchdb/sql/10-create-filter-definitions-function.sql`

```sql
-- =====================================================
-- File: 10-create-filter-definitions-function.sql
-- Purpose: Create RPC function for taxonomy-specific filter loading
-- =====================================================

-- Drop existing function if it exists (may be in Supabase console)
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
        COALESCE(f."TYPE", 'A') as etim_feature_type,
        fd.ui_config,
        fd.display_order
    FROM search.filter_definitions fd
    LEFT JOIN etim.feature f ON f."FEATUREID" = fd.etim_feature_id
    WHERE fd.active = true
      -- ⭐ KEY LOGIC: Filter by taxonomy code
      AND (
        fd.applicable_taxonomy_codes IS NULL  -- Universal filter (all categories)
        OR p_taxonomy_code = ANY(fd.applicable_taxonomy_codes)  -- Specific to this taxonomy
      )
    ORDER BY fd.display_order;
END;
$$;

COMMENT ON FUNCTION search.get_filter_definitions_with_type IS
'Returns filter definitions applicable to a specific taxonomy code.
Filters with NULL applicable_taxonomy_codes are universal (shown everywhere).
Filters with taxonomy codes only appear when that taxonomy is selected.';

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

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_filter_definitions_with_type(TEXT) TO anon, authenticated;

COMMENT ON FUNCTION public.get_filter_definitions_with_type IS
'Public wrapper for search.get_filter_definitions_with_type().
Returns taxonomy-specific filter definitions for the search UI.';
```

#### Step 1.2: Deploy to Supabase

```bash
# Option 1: Via Supabase MCP
# (Use mcp__supabase__execute_sql tool)

# Option 2: Via SQL Editor in Supabase Dashboard
# Copy-paste the SQL file contents

# Option 3: Via psql (if you have direct access)
psql $DATABASE_URL -f sql/10-create-filter-definitions-function.sql
```

#### Step 1.3: Verify Function Works

```sql
-- Test 1: Get LUMINAIRE filters (should return 8 filters)
SELECT * FROM get_filter_definitions_with_type('LUMINAIRE');

-- Test 2: Get ACCESSORIES filters (should return 0 currently)
SELECT * FROM get_filter_definitions_with_type('ACCESSORIES');

-- Test 3: Get DRIVERS filters (should return 0 currently)
SELECT * FROM get_filter_definitions_with_type('DRIVERS');
```

**Expected Result**: Function exists and returns correct count per taxonomy.

---

### Phase 2: Update Frontend (1 hour)

**Objective**: Make FilterPanel dynamically adapt to selected taxonomy

#### Step 2.1: Track Selected Taxonomy in Main Page

**File**: `/home/dimitris/foss/searchdb/search-test-app/app/page.tsx`

**Current Code** (lines 68-69):
```typescript
const [selectedTaxonomies, setSelectedTaxonomies] = useState<string[]>([])
const [activeTab, setActiveTab] = useState('') // Holds taxonomy code (e.g., 'LUMINAIRE')
```

**Current Issue** (lines 357-370):
```typescript
{activeTab === 'LUMINAIRE' && selectedTaxonomies.length > 0 ? (
  <FilterPanel
    onFilterChange={handleFilterChange}
    taxonomyCode={activeTab}  // ← Always 'LUMINAIRE'
    // ...
  />
) : (
  <div>Select a category to see technical filters</div>
)}
```

**Fix Required**:
```typescript
{/* Show filters when any category is selected (not just LUMINAIRE) */}
{selectedTaxonomies.length > 0 ? (
  <FilterPanel
    onFilterChange={handleFilterChange}
    taxonomyCode={selectedTaxonomies[0]}  // ← Use first selected taxonomy
    selectedTaxonomies={selectedTaxonomies}
    indoor={indoor}
    outdoor={outdoor}
    submersible={submersible}
    trimless={trimless}
    cutShapeRound={cutShapeRound}
    cutShapeRectangular={cutShapeRectangular}
    query={query || null}
    suppliers={suppliers}
  />
) : (
  <div className="bg-gradient-to-br from-slate-50 to-white rounded-xl shadow-lg border border-slate-200 p-8 text-center">
    <div className="text-slate-400 text-sm">
      <div className="mb-2">🔍</div>
      Select a category to see technical filters
    </div>
  </div>
)}
```

**Why This Works**:
- `selectedTaxonomies[0]` contains the taxonomy code user clicked
- Examples: `'LUMINAIRE-INDOOR-CEILING'`, `'ACCESSORIES'`, `'DRIVERS'`
- FilterPanel now receives dynamic taxonomy, not hardcoded `'LUMINAIRE'`

#### Step 2.2: Verify FilterPanel Props

**File**: `/home/dimitris/foss/searchdb/search-test-app/components/FilterPanel.tsx`

**Current Code** (line 36):
```typescript
export default function FilterPanel({
  onFilterChange,
  taxonomyCode = 'LUMINAIRE',  // ← Remove default, make required
  selectedTaxonomies,
  // ...
```

**Fix Required**:
```typescript
export default function FilterPanel({
  onFilterChange,
  taxonomyCode,  // ← No default, passed dynamically
  selectedTaxonomies,
  // ...
```

**Verify RPC Call** (lines 78-81):
```typescript
const { data: definitions, error: defError } = await supabase
  .rpc('get_filter_definitions_with_type', {
    p_taxonomy_code: taxonomyCode  // ← This will now be dynamic!
  })
```

**Add Loading State** when taxonomy changes:
```typescript
useEffect(() => {
  console.log('🔄 FilterPanel: Taxonomy changed to:', taxonomyCode)
  loadFilterDefinitions()
}, [taxonomyCode])  // Re-load when taxonomy changes
```

#### Step 2.3: Test User Flow

**Test Scenario 1**: Click different tabs
1. Click "Luminaires" tab → See luminaire filters (8 filters)
2. Click "Accessories" tab → See "Select a category" (0 filters currently)
3. Click "Drivers" tab → See "Select a category" (0 filters currently)

**Test Scenario 2**: Click subcategories under Luminaires
1. Click "Ceiling" → See luminaire filters (inherited from parent)
2. Click "Wall" → See luminaire filters
3. Console should show: `🔄 FilterPanel: Taxonomy changed to: LUMINAIRE-INDOOR-CEILING`

**Expected Behavior**: FilterPanel adapts to selected category, but Accessories/Drivers show no filters yet (Phase 3 will add them).

---

### Phase 3: Expand Filter Definitions (2 hours)

**Objective**: Configure multi-category and category-specific filters

#### Step 3.1: Make Universal Filters

**File**: Create `/home/dimitris/foss/searchdb/sql/11-update-filter-taxonomy-mapping.sql`

```sql
-- =====================================================
-- File: 11-update-filter-taxonomy-mapping.sql
-- Purpose: Configure which filters appear for which categories
-- =====================================================

-- =====================================================
-- Universal Filters (All Categories)
-- =====================================================

-- IP Rating - All product types need ingress protection
UPDATE search.filter_definitions
SET applicable_taxonomy_codes = ARRAY['LUMINAIRE', 'ACCESSORIES', 'DRIVERS', 'LAMPS']
WHERE filter_key = 'ip';

-- Voltage - All electrical products need voltage specification
UPDATE search.filter_definitions
SET applicable_taxonomy_codes = ARRAY['LUMINAIRE', 'ACCESSORIES', 'DRIVERS', 'LAMPS']
WHERE filter_key = 'voltage';

-- =====================================================
-- Luminaire-Specific Filters
-- =====================================================

-- Light output (only luminaires produce light)
UPDATE search.filter_definitions
SET applicable_taxonomy_codes = ARRAY['LUMINAIRE']
WHERE filter_key IN ('lumens_output', 'cct', 'cri', 'beam_angle_type');

-- Dimmable (primarily luminaires, some accessories)
UPDATE search.filter_definitions
SET applicable_taxonomy_codes = ARRAY['LUMINAIRE', 'ACCESSORIES']
WHERE filter_key = 'dimmable';

-- Finishing colour (luminaires and visible accessories)
UPDATE search.filter_definitions
SET applicable_taxonomy_codes = ARRAY['LUMINAIRE', 'ACCESSORIES']
WHERE filter_key = 'finishing_colour';

-- Protection class (electrical safety for luminaires and drivers)
UPDATE search.filter_definitions
SET applicable_taxonomy_codes = ARRAY['LUMINAIRE', 'DRIVERS']
WHERE filter_key = 'class';

-- Verify changes
SELECT
  filter_key,
  label,
  array_to_string(applicable_taxonomy_codes, ', ') as applies_to
FROM search.filter_definitions
WHERE active = true
ORDER BY display_order;
```

#### Step 3.2: Add Accessory-Specific Filters

**Prerequisites**:
1. Find ETIM feature IDs for accessory features:
```sql
-- Find material feature
SELECT "FEATUREID", "FEATUREDESC"
FROM etim.feature
WHERE "FEATUREDESC" ILIKE '%material%'
LIMIT 10;

-- Find track length feature
SELECT "FEATUREID", "FEATUREDESC"
FROM etim.feature
WHERE "FEATUREDESC" ILIKE '%length%' AND "FEATUREDESC" ILIKE '%track%'
LIMIT 10;
```

2. Add filter definitions:
```sql
-- Material filter (for accessories)
INSERT INTO search.filter_definitions
(filter_key, label, filter_type, etim_feature_id,
 applicable_taxonomy_codes, ui_config, display_order, active)
VALUES
(
  'material',
  'Material',
  'multi-select',
  'EF______',  -- Replace with actual ETIM feature ID
  ARRAY['ACCESSORIES'],
  jsonb_build_object(
    'filter_category', 'design',
    'show_count', true
  ),
  55,
  true
);

-- Track length filter (for track system accessories)
INSERT INTO search.filter_definitions
(filter_key, label, filter_type, etim_feature_id,
 applicable_taxonomy_codes, ui_config, display_order, active)
VALUES
(
  'track_length',
  'Track Length (mm)',
  'range',
  'EF______',  -- Replace with actual ETIM feature ID
  ARRAY['ACCESSORIES'],
  jsonb_build_object(
    'filter_category', 'design',
    'min', 0,
    'max', 5000,
    'step', 100,
    'unit', 'mm'
  ),
  60,
  true
);
```

#### Step 3.3: Add Driver-Specific Filters

```sql
-- Output current (for LED drivers)
INSERT INTO search.filter_definitions
(filter_key, label, filter_type, etim_feature_id,
 applicable_taxonomy_codes, ui_config, display_order, active)
VALUES
(
  'output_current',
  'Output Current (mA)',
  'range',
  'EF______',  -- Replace with actual ETIM feature ID
  ARRAY['DRIVERS'],
  jsonb_build_object(
    'filter_category', 'electricals',
    'min', 0,
    'max', 3000,
    'step', 50,
    'unit', 'mA'
  ),
  85,
  true
);

-- Driver efficiency (for drivers)
INSERT INTO search.filter_definitions
(filter_key, label, filter_type, etim_feature_id,
 applicable_taxonomy_codes, ui_config, display_order, active)
VALUES
(
  'efficiency',
  'Efficiency (%)',
  'range',
  'EF______',  -- Replace with actual ETIM feature ID
  ARRAY['DRIVERS'],
  jsonb_build_object(
    'filter_category', 'electricals',
    'min', 50,
    'max', 100,
    'step', 5,
    'unit', '%'
  ),
  90,
  true
);
```

#### Step 3.4: Test Each Category

**Test Luminaires**:
```bash
# Navigate to: http://localhost:3001
# Click: Luminaires tab → Ceiling
# Expected: 8 filters (voltage, dimmable, ip, class, finishing_colour, cct, cri, lumens)
```

**Test Accessories**:
```bash
# Click: Accessories tab → Track Systems
# Expected: 4 filters (ip, voltage, material, track_length)
```

**Test Drivers**:
```bash
# Click: Drivers tab
# Expected: 4 filters (ip, voltage, class, output_current, efficiency)
```

**Verify Dynamic Behavior**:
1. Switch between tabs → Filters change instantly
2. Console shows: `✅ Dynamic filter definitions loaded: 4 filters for ACCESSORIES`

---

### Phase 4: Documentation Updates (1 hour)

**Objective**: Document the taxonomy-specific filter architecture

#### Step 4.1: Create Taxonomy-Specific Filters Guide

**File**: `/home/dimitris/foss/searchdb/docs/guides/taxonomy-specific-filters.md`

**Content Outline**:
1. Vision statement (configuration over code)
2. Architecture overview (how it works)
3. Database schema (`applicable_taxonomy_codes` field)
4. Adding filters for new categories (step-by-step)
5. Multi-category filters (universal filters)
6. Testing and verification
7. Troubleshooting

**Key Examples to Include**:
- Add filter for single category
- Add filter for multiple categories
- Make existing filter universal
- Remove filter from category

#### Step 4.2: Update Existing Documentation

**File**: `/home/dimitris/foss/searchdb/docs/guides/delta-light-filters.md`

**Add Section** (after Phase 3):
```markdown
## Phase 4: Taxonomy-Specific Filter Configuration

### Concept

Filters can be configured to appear only for specific product categories.
This is controlled by the `applicable_taxonomy_codes` field in the
`filter_definitions` table.

### Examples

#### Universal Filter (All Categories)
```sql
UPDATE search.filter_definitions
SET applicable_taxonomy_codes = ARRAY['LUMINAIRE', 'ACCESSORIES', 'DRIVERS', 'LAMPS']
WHERE filter_key = 'ip';
```

#### Category-Specific Filter
```sql
UPDATE search.filter_definitions
SET applicable_taxonomy_codes = ARRAY['ACCESSORIES']
WHERE filter_key = 'material';
```

### Inheritance

Filters are inherited by child taxonomies. Example:
- Filter applies to: `ARRAY['LUMINAIRE']`
- Visible in: LUMINAIRE, LUMINAIRE-INDOOR-CEILING, LUMINAIRE-INDOOR-WALL, etc.
```

**File**: `/home/dimitris/foss/searchdb/README.md`

**Add to Key Concepts** section:
```markdown
### Taxonomy-Specific Filters

Filters automatically adapt based on the selected product category:
- **Luminaires**: Light output, color temperature, beam angle
- **Accessories**: Material, dimensions, compatibility
- **Drivers**: Output current, efficiency, power factor

Configuration is 100% database-driven via the `applicable_taxonomy_codes`
field. No code changes required to add/remove filters for categories.
```

#### Step 4.3: Update Filter Types Reference

**File**: `/home/dimitris/foss/searchdb/docs/reference/filter-types.md`

**Add Section** at the end:
```markdown
## Taxonomy-Specific Configuration

### Overview

Each filter definition can specify which product categories it applies to
using the `applicable_taxonomy_codes` field.

### Schema

```sql
CREATE TABLE search.filter_definitions (
    -- ... other fields ...
    applicable_taxonomy_codes TEXT[],  -- NULL = universal
);
```

### Values

| Value | Behavior |
|-------|----------|
| `NULL` | Universal - appears in all categories |
| `ARRAY['LUMINAIRE']` | Only appears when LUMINAIRE taxonomy selected |
| `ARRAY['LUMINAIRE', 'ACCESSORIES']` | Appears for both categories |

### Examples

See `docs/guides/taxonomy-specific-filters.md` for complete examples.
```

---

### Phase 5: Verification & Testing (30 minutes)

**Objective**: Ensure everything works end-to-end

#### Test Case 1: Luminaire Filters

**Steps**:
1. Navigate to http://localhost:3001
2. Click "Luminaires" tab
3. Click "Ceiling" category
4. Verify filters appear: Voltage, Dimmable, IP Rating, Class, Finishing Colour, CCT, CRI, Lumens Output
5. Select filters, verify products update
6. Check console: No errors

**Expected**: ✅ 8 filters visible, all functional

#### Test Case 2: Accessory Filters

**Steps**:
1. Click "Accessories" tab
2. Click any subcategory
3. Verify filters appear: IP Rating, Voltage, Material, Track Length
4. Select filters, verify products update

**Expected**: ✅ 4 filters visible (different from Luminaire filters)

#### Test Case 3: Driver Filters

**Steps**:
1. Click "Drivers" tab
2. Verify filters appear: IP Rating, Voltage, Class, Output Current, Efficiency
3. Select filters, verify products update

**Expected**: ✅ 5 filters visible (different from both above)

#### Test Case 4: Dynamic Addition

**Steps**:
1. Open Supabase SQL Editor
2. Add new filter:
```sql
INSERT INTO search.filter_definitions
(filter_key, label, filter_type, etim_feature_id,
 applicable_taxonomy_codes, ui_config, display_order, active)
VALUES
('new_accessory_filter', 'New Filter', 'boolean', 'EF______',
 ARRAY['ACCESSORIES'], '{"filter_category": "design"}'::jsonb, 999, true);
```
3. Refresh frontend (Ctrl+R)
4. Click "Accessories" tab
5. Verify new filter appears

**Expected**: ✅ New filter visible in Accessories, not in Luminaires

#### Test Case 5: Category Switching

**Steps**:
1. Click "Luminaires" → See 8 filters
2. Click "Accessories" → See 4 different filters
3. Click "Luminaires" again → See original 8 filters
4. Check browser DevTools Network tab
5. Verify RPC calls to `get_filter_definitions_with_type`

**Expected**: ✅ Filters change instantly, correct RPC calls logged

#### Test Case 6: Filter Updates

**Steps**:
1. Update existing filter:
```sql
UPDATE search.filter_definitions
SET applicable_taxonomy_codes = ARRAY['LUMINAIRE', 'ACCESSORIES', 'DRIVERS']
WHERE filter_key = 'ip';
```
2. Refresh frontend
3. Verify IP Rating now appears in all three categories

**Expected**: ✅ Filter moves to all categories

---

## 🎯 Success Criteria

### Must Have (MVP)
- ✅ RPC function filters by taxonomy code
- ✅ Frontend passes dynamic taxonomy to FilterPanel
- ✅ Different filters appear for Luminaires vs Accessories vs Drivers
- ✅ Adding filter to DB makes it appear in correct category
- ✅ Documentation explains the architecture

### Nice to Have (Future)
- Admin UI for managing filters (no SQL required)
- Visual taxonomy tree editor
- Filter preview before saving
- Bulk operations (copy filters between categories)

---

## 📝 Implementation Checklist

### Phase 1: RPC Function ✅ COMPLETE
- [x] Create `sql/10-create-filter-definitions-function.sql`
- [x] Deploy to Supabase
- [x] Test with `SELECT * FROM get_filter_definitions_with_type('LUMINAIRE')` → Returns 11 filters
- [x] Test with `SELECT * FROM get_filter_definitions_with_type('ACCESSORIES')` → Returns 3 universal filters
- [x] Verify function returns correct count per taxonomy → Working correctly!

### Phase 2: Frontend
- [ ] Update `app/page.tsx` - Remove `activeTab === 'LUMINAIRE'` condition
- [ ] Update `app/page.tsx` - Pass `taxonomyCode={selectedTaxonomies[0]}`
- [ ] Update `components/FilterPanel.tsx` - Remove default `taxonomyCode`
- [ ] Add console logging for taxonomy changes
- [ ] Test: Click different tabs, verify filters change

### Phase 3: Filter Definitions
- [ ] Create `sql/11-update-filter-taxonomy-mapping.sql`
- [ ] Make IP Rating universal (all categories)
- [ ] Make Voltage universal (all categories)
- [ ] Keep light output filters for LUMINAIRE only
- [ ] Add Material filter for ACCESSORIES
- [ ] Add Track Length filter for ACCESSORIES
- [ ] Add Output Current filter for DRIVERS
- [ ] Add Efficiency filter for DRIVERS
- [ ] Deploy and verify

### Phase 4: Documentation
- [ ] Create `docs/guides/taxonomy-specific-filters.md`
- [ ] Update `docs/guides/delta-light-filters.md`
- [ ] Update `docs/reference/filter-types.md`
- [ ] Update `README.md` key concepts
- [ ] Add examples and troubleshooting

### Phase 5: Verification
- [ ] Test Case 1: Luminaire filters (8 filters)
- [ ] Test Case 2: Accessory filters (4 filters)
- [ ] Test Case 3: Driver filters (5 filters)
- [ ] Test Case 4: Dynamic addition works
- [ ] Test Case 5: Category switching instant
- [ ] Test Case 6: Filter updates propagate

---

## 🚀 Quick Start After Context Refresh

**When you return to this project:**

1. **Check where we left off:**
   ```bash
   cat /home/dimitris/foss/searchdb/docs/guides/IMPLEMENTATION-PLAN-taxonomy-specific-filters.md | grep "\- \[ \]" | head -5
   ```

2. **Run the next unchecked step:**
   - If Phase 1 incomplete → Create RPC function SQL file
   - If Phase 2 incomplete → Update frontend files
   - If Phase 3 incomplete → Expand filter definitions
   - Etc.

3. **Test after each phase:**
   ```bash
   cd /home/dimitris/foss/searchdb/search-test-app
   npm run dev  # Should already be running
   # Open http://localhost:3001 and test
   ```

4. **Mark completed:**
   ```bash
   # Update this file's checkboxes as you complete each step
   # Change [ ] to [x]
   ```

---

## 🔍 Debugging Guide

### Issue: Filters not changing when clicking tabs

**Check**:
1. Browser console: Are there errors?
2. Network tab: Is `get_filter_definitions_with_type` being called?
3. RPC parameter: What value is `p_taxonomy_code`?
4. Database: Does filter have correct `applicable_taxonomy_codes`?

**Fix**:
```typescript
// Add logging in FilterPanel.tsx
console.log('🔄 FilterPanel received taxonomyCode:', taxonomyCode)
console.log('✅ Loaded filter definitions:', definitions)
```

### Issue: RPC function returns wrong filters

**Check**:
```sql
-- What taxonomy code is being passed?
SELECT * FROM get_filter_definitions_with_type('ACCESSORIES');

-- What does the filter definition say?
SELECT filter_key, applicable_taxonomy_codes
FROM search.filter_definitions
WHERE filter_key = 'material';
```

### Issue: New filter not appearing

**Checklist**:
- [ ] Filter has `active = true`
- [ ] Filter has correct `applicable_taxonomy_codes`
- [ ] RPC function includes taxonomy filtering logic
- [ ] Frontend refreshed (Ctrl+R)
- [ ] No console errors

---

## 📚 Related Documentation

- `docs/architecture/overview.md` - System architecture
- `docs/guides/delta-light-filters.md` - Filter implementation
- `docs/reference/filter-types.md` - Filter type reference
- `docs/reference/sql-functions.md` - RPC function reference
- `sql/01-create-search-schema.sql` - Database schema
- `sql/05-populate-filter-definitions.sql` - Current filter definitions

---

## 🎓 Learning Resources

### Key Concepts to Understand

1. **Taxonomy Hierarchy**: ROOT → Level 1 (tabs) → Level 2 (categories) → Level 3 (types)
2. **Filter Inheritance**: Child taxonomies inherit parent filters
3. **NULL vs Array**: `NULL` = universal, `ARRAY[...]` = specific
4. **RPC Function**: How to query with taxonomy parameter
5. **React Props**: How taxonomy flows from page → FilterPanel

### SQL Examples

See `sql/11-update-filter-taxonomy-mapping.sql` for complete examples of:
- Making filters universal
- Restricting filters to categories
- Adding category-specific filters

---

**Last Updated**: 2025-01-21
**Next Update**: After Phase 1 completion
**Delete This File**: After all phases complete and main docs updated
