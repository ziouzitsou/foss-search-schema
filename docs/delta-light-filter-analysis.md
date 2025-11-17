# Delta Light Filter System Analysis

**Date**: 2025-01-15
**URL Analyzed**: https://deltalight.com/en/product-browser (Indoor > Ceiling > Recessed)
**Screenshots**: `/home/sysadmin/tools/searchdb/.playwright-mcp/delta-filters-panel.png`

---

## Executive Summary

Delta Light uses a **three-category filter grouping system** that organizes 18 different filters based on user concerns: Electricals, Design, and Light Engine. The filters are context-aware and change based on the selected product category (e.g., different filters for ceiling recessed vs wall-mounted).

---

## Filter Organization Strategy

### 1. **Electricals** (Technical Specifications)
Filters related to electrical properties and power requirements:

- ☐ **Light source** - Type of light technology (LED, halogen, etc.)
- ☐ **Class** - Electrical protection class (Class I, II, III)
- ☐ **Power supply included** - Boolean filter (yes/no)
- ☐ **Dimming Method** - Type of dimming (DALI, 0-10V, Phase cut, etc.)
- ☐ **Voltage** - Operating voltage (12V, 230V, etc.)

**User Perspective**: "What electrical infrastructure do I need?"

### 2. **Design** (Physical/Aesthetic Properties)
Filters related to appearance, installation, and physical characteristics:

- ☐ **Finishing colour** - Product color/finish (black, white, chrome, etc.)
- ☐ **Ceiling type** - Type of ceiling installation
- ☐ **IP** - Ingress Protection rating (IP20, IP44, IP65, etc.)
- ☐ **IK** - Impact Protection rating (IK07, IK08, IK10, etc.)
- ☐ **Min. recessed depth** - Minimum ceiling depth required
- ☐ **Adjustability** - Can the fixture be adjusted/aimed

**User Perspective**: "How will it look and fit in my space?"

### 3. **Light engine** (Light Quality/Performance)
Filters related to optical and light quality characteristics:

- ☐ **CRI** - Color Rendering Index (80+, 90+, etc.)
- ☐ **Light distribution** - Beam pattern (narrow, medium, wide, wallwash, etc.)
- ☐ **LED lm** - Luminous flux in lumens
- ☐ **Efficacy (min.)** - Efficiency in lumens per watt (lm/W)
- ☐ **CCT** - Correlated Color Temperature (2700K, 3000K, 4000K, etc.)
- ☐ **Beam angle type** - Beam angle classification (spot, flood, etc.)

**User Perspective**: "What quality and type of light will I get?"

---

## Key UX Features Observed

### Checkbox Selection Model
- All filters use checkboxes (multi-select)
- No filters are pre-selected by default
- Users can select multiple values within each filter
- "Reset filters" button to clear all selections at once

### Filter Panel Design
- **Modal/Drawer Interface**: Filters open in a slide-out panel overlay
- **"Add filters" Button**: Clear call-to-action to open filter panel
- **"Update filters" Button**: Apply selections (not real-time)
- **Grouped Sections**: Three collapsible/visible sections (Electricals, Design, Light engine)
- **Visual Hierarchy**: Section headings clearly separate filter categories

### Context-Aware Filtering (CONFIRMED FINDINGS)

**Testing conducted on 2025-01-15 with 3 ceiling installation types:**

| Installation Type | URL Parameter | Product Families | Filters Shown |
|------------------|---------------|------------------|---------------|
| Ceiling Recessed | `installation=14b89d16` | 26 families | 18 filters |
| Ceiling Surface Mounted | `installation=14b8c2e6` | 23 families | 18 filters |
| Ceiling Suspended | `installation=14b8d812` | 22 families | 18 filters |

**All three show IDENTICAL filter lists**, including filters that don't apply:
- "Min. recessed depth" shown for surface mounted (not applicable)
- "Min. recessed depth" shown for suspended (not applicable)
- "Ceiling type" shown for all three (may only apply to some)

**Conclusion**: Delta's filtering is **NOT installation-type specific** within the same fixation category.

**Filter Scope Strategy Revealed**:
1. **Fixation-level grouping**: Filters likely change at the fixation level (Ceiling vs Wall vs Floor), not installation level
2. **Show all, filter in backend**: All filters are displayed regardless of applicability
3. **No dynamic UI hiding**: Filters don't disappear based on context
4. **Backend handles irrelevance**: Non-matching filters simply return 0 results or are disabled

**Implication for Our Implementation**:

✅ **Simpler architecture**:
- Define one filter set per main category (Luminaires, Accessories, etc.)
- No need for complex conditional logic to show/hide filters
- Backend query handles non-matching filters gracefully

✅ **User-friendly approach**:
- Consistent interface across all product types
- Users don't need to learn different filter sets
- Clear when filters return 0 results

✅ **Implementation simplicity**:
```typescript
// Single filter configuration for all ceiling products
const LUMINAIRE_FILTERS = [...]; // 18 filters

// Applied to all subcategories
- Indoor > Ceiling > Recessed → LUMINAIRE_FILTERS
- Indoor > Ceiling > Surface → LUMINAIRE_FILTERS
- Indoor > Ceiling > Suspended → LUMINAIRE_FILTERS
```

**Still to test**:
- Wall-mounted products (different fixation type)
- Outdoor products (different location)
- Accessories/Drivers (different product category)

These MAY have different filter sets, but installation type does NOT affect filters.

### User Journey
1. **Top-level Category Selection** (Location → Fixation → Installation)
   - Indoor/Outdoor
   - Ceiling/Wall/Floor/Suspended/Track
   - Recessed/Surface/Pendant/etc.

2. **Coarse Filtering** (Product Families, Shape)
   - Browse by product family
   - Filter by shape

3. **Fine-Tuning** (Add Filters)
   - Apply detailed technical filters
   - Refine based on specific requirements

---

## Comparison to Our Current System

### What We Have
✅ Power (W) - range filter
✅ IP rating - multi-select
✅ CCT (Color temperature) - range or multi-select
✅ Basic category navigation (Luminaires, Accessories, etc.)

### What Delta Has (That We Don't)
❌ **Grouped filter organization** (Electricals/Design/Light engine)
❌ **CRI** (Color Rendering Index)
❌ **Light source type** (LED, halogen, etc.)
❌ **Dimming method** (DALI, 0-10V, etc.)
❌ **IK rating** (Impact protection)
❌ **Light distribution** (spot, flood, wallwash, etc.)
❌ **Efficacy** (lm/W efficiency)
❌ **Beam angle type**
❌ **Finishing colour**
❌ **Voltage** options
❌ **Electrical class**
❌ **Power supply included** (boolean)
❌ **Adjustability** (boolean)
❌ **Min. recessed depth** (for recessed fixtures)
❌ **Ceiling type** (for ceiling fixtures)

---

## Implementation Recommendations

### Phase 1: High-Impact Filters (Quick Wins)
Filters with high user value and likely available in our ETIM data:

1. **CCT (Color Temperature)** - already mapped
2. **CRI (Color Rendering Index)** - check ETIM
3. **Light source type** - ETIM should have this
4. **Finishing colour** - check ETIM
5. **Voltage** - likely in ETIM

**Effort**: 1-2 hours
**Data**: Need to verify ETIM feature IDs

### Phase 2: Medium Complexity
Filters requiring more ETIM exploration:

6. **Luminous flux (LED lm)** - range filter
7. **Beam angle** - multi-select or range
8. **Dimming method** - multi-select
9. **IK rating** - multi-select
10. **Light distribution** - multi-select

**Effort**: 2-3 hours
**Data**: ETIM feature mapping required

### Phase 3: Advanced/Product-Specific
Filters that may need custom logic or are product-specific:

11. **Efficacy (lm/W)** - calculated field (lumens / watts)
12. **Min. recessed depth** - only for recessed fixtures
13. **Ceiling type** - only for ceiling fixtures
14. **Adjustability** - boolean, product-specific
15. **Power supply included** - boolean, product-specific
16. **Electrical class** - might be in ETIM

**Effort**: 3-5 hours
**Data**: Requires research + possible custom attributes

---

## UI/UX Design Recommendations

### Option A: Delta's Modal Approach (Recommended)
**Pros**:
- Clean, uncluttered main page
- Users opt-in to advanced filtering
- Grouped categories help users understand filter purpose
- Mobile-friendly (full-screen overlay)

**Cons**:
- Requires extra click to access filters
- Filters not immediately visible

**Implementation**:
```tsx
<FilterPanel>
  <FilterGroup title="Electricals">
    <FilterCheckbox name="light_source" />
    <FilterCheckbox name="dimming_method" />
    <FilterCheckbox name="voltage" />
  </FilterGroup>

  <FilterGroup title="Design">
    <FilterCheckbox name="ip_rating" />
    <FilterCheckbox name="ik_rating" />
    <FilterCheckbox name="finishing_colour" />
  </FilterGroup>

  <FilterGroup title="Light Engine">
    <FilterRange name="cct" />
    <FilterCheckbox name="cri" />
    <FilterRange name="led_lm" />
  </FilterGroup>
</FilterPanel>
```

### Option B: Sidebar with Grouped Accordions
**Pros**:
- Filters always visible
- No modal interaction needed
- Good for desktop users

**Cons**:
- Takes up screen real estate
- Can feel overwhelming with 18+ filters
- Mobile experience requires careful design

### Option C: Hybrid Approach
- **Primary filters** always visible (Power, IP, CCT)
- **"More filters" button** opens modal with grouped advanced filters
- Best of both worlds

---

## Technical Implementation Notes

### Filter Data Structure
```typescript
interface FilterGroup {
  id: string;
  label: string;
  filters: Filter[];
}

interface Filter {
  id: string;
  label: string;
  type: 'checkbox' | 'range' | 'boolean';
  etim_feature_id?: string;
  values?: FilterValue[];
  min?: number;
  max?: number;
  context_specific?: boolean; // Only show for certain product types
}

const filterGroups: FilterGroup[] = [
  {
    id: 'electricals',
    label: 'Electricals',
    filters: [
      { id: 'light_source', label: 'Light source', type: 'checkbox', etim_feature_id: 'EF??????' },
      { id: 'dimming_method', label: 'Dimming Method', type: 'checkbox', etim_feature_id: 'EF??????' },
      // ...
    ]
  },
  {
    id: 'design',
    label: 'Design',
    filters: [
      { id: 'ip_rating', label: 'IP', type: 'checkbox', etim_feature_id: 'EF??????' },
      // ...
    ]
  },
  {
    id: 'light_engine',
    label: 'Light engine',
    filters: [
      { id: 'cct', label: 'CCT', type: 'range', min: 2700, max: 6500 },
      // ...
    ]
  }
];
```

### Database Query Pattern
```sql
-- Example: Multi-filter query
SELECT DISTINCT p.*
FROM items.product_info p
JOIN search.product_filter_index f ON p.product_id = f.product_id
WHERE
  -- Category filter (taxonomy)
  EXISTS (
    SELECT 1 FROM search.product_taxonomy_flags ptf
    WHERE ptf.product_id = p.product_id
    AND ptf.ceiling = true
  )
  -- IP rating filter
  AND EXISTS (
    SELECT 1 FROM search.product_filter_index pfi
    WHERE pfi.product_id = p.product_id
    AND pfi.filter_key = 'ip_rating'
    AND pfi.alphanumeric_value IN ('IP44', 'IP65')
  )
  -- CCT filter
  AND EXISTS (
    SELECT 1 FROM search.product_filter_index pfi
    WHERE pfi.product_id = p.product_id
    AND pfi.filter_key = 'cct'
    AND pfi.numeric_value BETWEEN 2700 AND 3000
  )
  -- CRI filter
  AND EXISTS (
    SELECT 1 FROM search.product_filter_index pfi
    WHERE pfi.product_id = p.product_id
    AND pfi.filter_key = 'cri'
    AND pfi.numeric_value >= 90
  )
LIMIT 50;
```

---

## Next Steps for Our Implementation

### Immediate Actions
1. **Run ETIM feature discovery queries** to find feature IDs for:
   - CRI (Color Rendering Index)
   - Light source type
   - Dimming method
   - IK rating
   - Luminous flux (lumens)
   - Beam angle
   - Finishing colour
   - Voltage
   - Light distribution patterns

2. **Review `search.product_filter_index`** to see which features are already populated

3. **Decide on UI approach** (Modal vs Sidebar vs Hybrid)

### Questions to Resolve
- Which filters are **most important** for your users?
- Should filters be **context-aware** (show different filters for ceiling vs wall fixtures)?
- Do we want **real-time filtering** (like our current system) or **"Apply filters" button** (like Delta)?
- Should we implement **filter grouping** (Electricals/Design/Light Engine) or keep a flat list?

### Data Exploration Priority
Before building the UI, we should run queries like:
```sql
-- Check which ETIM features exist and are populated
SELECT
  f."FEATUREDESC" as feature_name,
  f."FEATUREID" as feature_id,
  COUNT(DISTINCT pf.product_id) as product_count,
  COUNT(DISTINCT pf.value_alphanumeric) as unique_values
FROM items.product_features pf
JOIN etim.feature f ON pf.feature_id = f."FEATUREID"
WHERE f."FEATUREDESC" ILIKE '%CRI%'
   OR f."FEATUREDESC" ILIKE '%color rendering%'
   OR f."FEATUREDESC" ILIKE '%dimm%'
   OR f."FEATUREDESC" ILIKE '%light distribution%'
   OR f."FEATUREDESC" ILIKE '%beam angle%'
   OR f."FEATUREDESC" ILIKE '%voltage%'
   OR f."FEATUREDESC" ILIKE '%efficacy%'
   OR f."FEATUREDESC" ILIKE '%finish%'
GROUP BY f."FEATUREID", f."FEATUREDESC"
HAVING COUNT(DISTINCT pf.product_id) > 100
ORDER BY product_count DESC;
```

---

## Visual Design Notes

### Filter Panel Layout (from screenshot)
- **White background** with clear section dividers
- **Checkbox style**: Square checkboxes with clear labels
- **Typography**:
  - Section headings: Bold, larger font
  - Filter labels: Regular weight, readable size
- **Spacing**: Generous padding between sections and filters
- **Buttons**:
  - Primary action: "UPDATE FILTERS" (black background, white text)
  - Secondary: "Reset filters" (icon + text, light styling)

### Interaction Patterns
- Checkboxes are **not checked by default**
- Modal opens with **slide animation** from right
- "Close" button (X icon) in top-right corner
- "Update filters" button **sticky at bottom** of modal
- Smooth scrolling for long filter lists

---

## Conclusion

Delta Light's filtering system is **professional, user-focused, and well-organized**. Their three-category grouping (Electricals, Design, Light engine) makes sense from both a technical and user perspective.

**Key Takeaways**:
1. **Group filters by user concern**, not by data structure
2. **Context-aware filtering** improves UX (show relevant filters only)
3. **Modal approach** keeps main page clean while offering advanced filtering
4. **18 filters is manageable** when properly organized
5. **Multi-select checkboxes** give users flexibility

**Recommended Approach for Our System**:
- Start with **Phase 1 filters** (5-6 high-impact filters)
- Implement **grouped modal design** (similar to Delta)
- Use our existing **real-time filtering** for better UX
- **Incrementally add filters** based on user feedback and data availability
