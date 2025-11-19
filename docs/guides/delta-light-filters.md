# Delta Light-Style Filter Implementation

**Implementation Date**: November 15, 2025
**Current Status**: ✅ Phase 1 Complete (8 filters deployed)
**Database**: 14,889 products, 13,336 luminaires
**Reference App**: search-test-app (localhost:3001)

---

## Overview

This guide documents the implementation of **Delta Light-style universal filters** - a comprehensive technical filtering system inspired by Delta Light's professional luminaire catalog interface.

### What Are Delta Light Filters?

Delta Light uses a **universal filter strategy**: the same 18 filters shown for ALL product types (Indoor, Outdoor, Tracks, Accessories). This approach:
- ✅ Provides consistency across product categories
- ✅ Simplifies UI (one filter panel for everything)
- ✅ Handles non-applicable filters gracefully (shows 0 results)
- ✅ Requires no conditional logic per product type

### Our Implementation

We adopted this strategy and mapped Delta's filters to our ETIM features:

**Phase 1** (Nov 15, 2025): 8 core filters ✅ Deployed
**Phase 2** (Planned): 6 advanced filters 🔜 Ready
**Phase 3** (Optional): 4 specialized filters 📋 Documented

---

## Filter Categories

Delta Light organizes filters into 3 categories that we've adopted:

### 1. ELECTRICALS
Technical electrical specifications and compatibility

### 2. DESIGN
Physical appearance, protection ratings, installation

### 3. LIGHT ENGINE
Light output, quality, and distribution characteristics

---

## Phase 1: Core Filters (✅ Deployed)

**Implementation**: November 15, 2025
**Coverage**: 13,000+ products per filter
**SQL Files**: `sql/02-populate-filter-definitions.sql`, `sql/03-populate-filter-index.sql`

### ELECTRICALS (3 filters)

#### 1. Voltage
- **ETIM**: `EF005127` (Nominal voltage)
- **Type**: Multi-select
- **Values**: 12V, 24V, 110-240V, 220-240V, etc.
- **Coverage**: 13,441 products
- **UI**: Checkbox list with common voltages

#### 2. Dimmable
- **ETIM**: `EF000137` (Dimmable)
- **Type**: Boolean (Yes/No)
- **Coverage**: 13,288 products
- **UI**: Three-state toggle (Yes/No/Any)
- **Counts**:
  - Yes: 11,220 products
  - No: 1,833 products

#### 3. Protection Class
- **ETIM**: `EF000004` (Protection class according to IEC 61140)
- **Type**: Multi-select
- **Values**: Class I, Class II, Class III
- **Coverage**: 13,805 products
- **UI**: Checkbox list
- **Distribution**:
  - Class III: 8,517 products
  - Class I: 3,611 products
  - Class II: 1,207 products

### DESIGN (2 filters)

#### 4. IP Rating
- **ETIM**: `EF003118` (Degree of protection (IP), front side)
- **Type**: Multi-select (alphanumeric)
- **Values**: IP20, IP44, IP54, IP65, IP67, IP68
- **Coverage**: 7,446 products
- **UI**: Icon-based checkboxes (water drop icons)
- **Distribution**:
  - IP20: 5,001 products (indoor)
  - IP65: 1,277 products (outdoor)
  - IP44: 484 products (splash-proof)
  - IP54, IP67, IP68: Various

#### 5. Finishing Colour
- **ETIM**: `EF000136` (Housing colour)
- **Type**: Multi-select (categorical)
- **Values**: Black, White, Gold, Chrome, Bronze, Custom RAL, etc.
- **Coverage**: 13,467 products
- **UI**: Color swatches with checkboxes
- **Distribution**:
  - Black: 4,190 products
  - White: 3,726 products
  - Gold: 1,808 products
  - Custom RAL: 1,234 products

### LIGHT ENGINE (3 filters)

#### 6. CCT (Correlated Color Temperature)
- **ETIM**: `EF009346` (Colour temperature)
- **Type**: Range slider (numeric)
- **Range**: 2700K - 6500K
- **Coverage**: 13,510 products
- **UI**: Dual-handle slider with presets:
  - Warm White: 2700-3000K
  - Neutral White: 3500-4500K
  - Cool White: 5000-6500K

#### 7. CRI (Color Rendering Index)
- **ETIM**: `EF000442` (Colour rendering index CRI)
- **Type**: Range slider (numeric)
- **Range**: 70-100
- **Coverage**: 13,463 products
- **UI**: Single threshold slider (min. CRI)
- **Common values**: 80+, 90+, 95+

#### 8. Luminous Flux (Lumens Output)
- **ETIM**: `EF018714` (Rated luminous flux according to IEC 62722-2-1)
- **Type**: Range slider (numeric)
- **Range**: 0 - 50,000 lm
- **Coverage**: 13,402 products
- **UI**: Dual-handle slider with presets:
  - Low: 0-500 lm (ambient)
  - Medium: 500-2000 lm (task lighting)
  - High: 2000+ lm (high output)

---

## Phase 2: Advanced Filters (🔜 Ready)

**Status**: SQL ready in `sql/02-populate-filter-definitions.sql` (commented out)
**Deployment**: Uncomment Phase 2 section and refresh views

### ELECTRICALS (2 filters)

#### 9. Light Source
- **ETIM**: `EF000048` (Lamp holder)
- **Type**: Multi-select
- **Values**: LED, Halogen, CFL, etc.
- **Coverage**: 13,379 products
- **Note**: Verify this shows actual light source types

#### 10. Dimming Method (Extended)
- **ETIM**: Multiple features
  - `EF012154` - Dimming DALI (13,137 products)
  - `EF012153` - Dimming 1-10V (13,068 products)
  - `EF012152` - Dimming 0-10V (13,050 products)
  - `EF015824` - Dimming DALI-2
  - `EF012155` - Dimming DMX
- **Type**: Multi-select (multiple methods can apply)
- **UI**: Checkbox list
- **Note**: Extends basic "Dimmable" boolean with specific protocols

### DESIGN (2 filters)

#### 11. IK Rating (Impact Resistance)
- **ETIM**: `EF004293` (Impact strength)
- **Type**: Multi-select
- **Values**: IK02, IK04, IK06, IK08, IK10
- **Coverage**: 9,641 products
- **UI**: Checkbox list with impact icons

#### 12. Adjustability
- **ETIM**: `EF009351` (Adjustability)
- **Type**: Multi-select
- **Values**: Tiltable, Rotatable, Fixed, etc.
- **Coverage**: 5,853 products
- **UI**: Checkbox list

### LIGHT ENGINE (2 filters)

#### 13. Light Distribution
- **ETIM**: `EF004283` (Light distribution)
- **Type**: Multi-select
- **Values**: Direct, Indirect, Direct/Indirect, Symmetric, Asymmetric
- **Coverage**: 13,306 products
- **UI**: Checkbox list with distribution diagrams (optional)

#### 14. Beam Angle
- **ETIM**: `EF008157` (Beam angle)
- **Type**: Range slider
- **Range**: 0° - 360°
- **Coverage**: 11,838 products
- **Common ranges**:
  - Spot: 10-30°
  - Flood: 30-60°
  - Wide Flood: 60-120°

---

## Phase 3: Specialized Filters (📋 Documented)

**Status**: Documented in SQL, commented out
**Deployment**: Uncomment Phase 3 after Phase 2 validated

### ELECTRICALS (1 filter)

#### 15. Driver Included
- **ETIM**: `EF007556` (With control gear)
- **Type**: Boolean
- **Coverage**: 13,420 products
- **UI**: Three-state toggle

### DESIGN (2 filters)

#### 16. Min. Recessed Depth
- **ETIM**: `EF010795` (Built-in height)
- **Type**: Range slider (mm)
- **Coverage**: 5,732 products
- **UI**: Dual-handle slider
- **Note**: Only applicable for recessed luminaires

#### 17. Ceiling Type
- **Status**: ⚠️ Not mapped
- **Reason**: Product-specific, not standardized in ETIM
- **Alternative**: May skip or implement as custom field

### LIGHT ENGINE (1 filter)

#### 18. Efficacy (Luminous Efficacy)
- **ETIM**: `EF018713` (Luminaire efficacy)
- **Type**: Range slider (lm/W)
- **Range**: 0 - 200 lm/W
- **Coverage**: 12,209 products
- **UI**: Single threshold slider (min. efficacy)
- **Note**: May need calculation (lumens ÷ power)

---

## Bonus Filters (Not in Delta Light)

Your database has additional ETIM features not in Delta's standard set:

### Power (Already Implemented)
- **ETIM**: `EF009347` (Max power)
- **Type**: Range slider (W)
- **Coverage**: 13,469 products
- **Status**: ✅ Implemented in Phase 1 (preferred over "Suitable for lamp power")

### Material
- **ETIM**: `EF001596` (Material)
- **Type**: Multi-select
- **Values**: Aluminum, Plastic, Glass, Steel, etc.
- **Coverage**: 13,118 products
- **Use Case**: Housing material filter

### Physical Dimensions
- **Height/Depth**: `EF001456` (13,853 products)
- **Outer Diameter**: `EF000015` (7,817 products)
- **Built-in Diameter**: `EF016380` (5,732 products)

### Advanced Color Quality
- **Colour Consistency**: `EF011946` (McAdam ellipse, 12,344 products)
- **Use Case**: For professional spec'ers requiring tight color binning

---

## Implementation Details

### Database Schema

Filters are defined in three tables:

1. **`search.filter_definitions`**
   - Stores filter metadata (name, ETIM feature, UI config)
   - Grouped by `filter_category` (electricals/design/light_engine)
   - UI config includes: unit, min, max, step, presets

2. **`search.product_filter_index`** (Materialized View)
   - Flattens ETIM features from `items.product_info`
   - One row per product per filter
   - Indexes: `filter_key`, `product_id`, `value_numeric`, `value_alpha`

3. **`search.filter_facets`** (Materialized View)
   - Pre-calculates filter options and product counts
   - Grouped by `filter_key` and `value`
   - Used for UI dropdowns and count badges

### SQL Functions

**`get_filter_definitions_with_type(p_taxonomy_code)`**
- Returns filter definitions for a taxonomy
- Includes ETIM feature type (N=numeric, A=alphanumeric, L=logical)
- Used by FilterPanel to determine UI component

**`get_dynamic_facets(p_taxonomy_codes, p_filters, ...)`**
- Returns context-aware filter options
- Counts update based on current selections
- Filters out zero-count options

**`search_products_with_filters(p_filters, ...)`**
- Main search function accepting filter object
- Format: `{"cct": {"min": 3000, "max": 4000}, "ip": ["IP65", "IP67"]}`
- Returns products matching ALL selected filters (AND logic)

### UI Components

**`FilterPanel.tsx`** (319 lines)
- Main filter container
- Loads definitions and facets
- Three collapsible categories
- Handles filter state and callbacks

**Filter Components**:
- **`BooleanFilter`**: Three-state toggle (Yes/No/Any)
- **`MultiSelectFilter`**: Checkbox list with search
- **`RangeFilter`**: Dual-handle slider with presets

**Features**:
- ✅ Real-time facet updates
- ✅ Clear individual filters
- ✅ Clear all filters
- ✅ Active filter count badge
- ✅ Collapsible categories
- ✅ Color swatches for colour filters
- ✅ Icons for IP ratings

---

## ETIM Feature Mapping Table

Complete mapping of Delta Light filters to ETIM features:

| Filter | Category | ETIM ID | ETIM Name | Type | Coverage | Phase |
|--------|----------|---------|-----------|------|----------|-------|
| Voltage | Electricals | EF005127 | Nominal voltage | M | 13,441 | 1 ✅ |
| Dimmable | Electricals | EF000137 | Dimmable | B | 13,288 | 1 ✅ |
| Protection Class | Electricals | EF000004 | Protection class (IEC 61140) | M | 13,805 | 1 ✅ |
| Light Source | Electricals | EF000048 | Lamp holder | M | 13,379 | 2 🔜 |
| Dimming DALI | Electricals | EF012154 | Dimming DALI | B | 13,137 | 2 🔜 |
| Dimming 1-10V | Electricals | EF012153 | Dimming 1-10 V | B | 13,068 | 2 🔜 |
| Dimming 0-10V | Electricals | EF012152 | Dimming 0-10 V | B | 13,050 | 2 🔜 |
| Driver Included | Electricals | EF007556 | With control gear | B | 13,420 | 3 📋 |
| IP Rating | Design | EF003118 | Degree of protection (IP) | M | 7,446 | 1 ✅ |
| Finishing Colour | Design | EF000136 | Housing colour | M | 13,467 | 1 ✅ |
| IK Rating | Design | EF004293 | Impact strength | M | 9,641 | 2 🔜 |
| Adjustability | Design | EF009351 | Adjustability | M | 5,853 | 2 🔜 |
| Min. Recessed Depth | Design | EF010795 | Built-in height | R | 5,732 | 3 📋 |
| CCT | Light Engine | EF009346 | Colour temperature | R | 13,510 | 1 ✅ |
| CRI | Light Engine | EF000442 | Colour rendering index | R | 13,463 | 1 ✅ |
| Luminous Flux | Light Engine | EF018714 | Rated luminous flux | R | 13,402 | 1 ✅ |
| Light Distribution | Light Engine | EF004283 | Light distribution | M | 13,306 | 2 🔜 |
| Beam Angle | Light Engine | EF008157 | Beam angle | R | 11,838 | 2 🔜 |
| Efficacy | Light Engine | EF018713 | Luminaire efficacy | R | 12,209 | 3 📋 |

**Legend**: B=Boolean, M=Multi-select, R=Range

---

## Deployment Workflow

### Phase 1 (Already Done ✅)

1. Executed `sql/02-populate-filter-definitions.sql` (Phase 1 uncommented)
2. Executed `sql/03-populate-filter-index.sql`
3. Executed `sql/09-add-dynamic-facets.sql`
4. Refreshed materialized views
5. Tested in search-test-app
6. **Result**: 8 filters working perfectly

### Phase 2 (When Ready 🔜)

1. Edit `sql/02-populate-filter-definitions.sql`
2. Uncomment Phase 2 section (lines X-Y)
3. Execute SQL file
4. Refresh `product_filter_index` materialized view
5. Refresh `filter_facets` materialized view
6. Test each filter in search-test-app
7. Verify counts and options
8. **Expected**: 6 new filters added

### Phase 3 (Optional 📋)

Same workflow as Phase 2, uncomment Phase 3 section.

---

## Testing & Validation

### Filter Functionality Tests

**Test 1: Single Filter**
```sql
SELECT * FROM search.search_products_with_filters(
  p_filters := '{"cct": {"min": 3000, "max": 4000}}'::jsonb
);
-- Should return products with CCT between 3000-4000K
```

**Test 2: Multi-Select**
```sql
SELECT * FROM search.search_products_with_filters(
  p_filters := '{"ip": ["IP65", "IP67"]}'::jsonb
);
-- Should return products with IP65 OR IP67
```

**Test 3: Boolean**
```sql
SELECT * FROM search.search_products_with_filters(
  p_filters := '{"dimmable": true}'::jsonb
);
-- Should return only dimmable products
```

**Test 4: Combined**
```sql
SELECT * FROM search.search_products_with_filters(
  p_filters := '{
    "cct": {"min": 3000, "max": 4000},
    "ip": ["IP65"],
    "dimmable": true
  }'::jsonb
);
-- Should return products matching ALL filters (AND logic)
```

### Dynamic Facet Tests

**Test: Context-Aware Counts**
```sql
-- Get facets with NO filters applied
SELECT * FROM search.get_dynamic_facets(
  p_taxonomy_codes := ARRAY['LUMINAIRE-INDOOR-CEILING']
);

-- Get facets with CCT filter applied
SELECT * FROM search.get_dynamic_facets(
  p_taxonomy_codes := ARRAY['LUMINAIRE-INDOOR-CEILING'],
  p_filters := '{"cct": {"min": 3000, "max": 4000}}'::jsonb
);
-- Counts should be LOWER for other filters (showing only compatible products)
```

---

## Performance Considerations

### Query Performance

- **Filter queries**: <100ms (materialized views)
- **Dynamic facets**: <100ms (indexed lookups)
- **Combined filters**: <200ms (multiple AND conditions)

### View Refresh Time

- **`product_filter_index`**: 3-5 seconds (~125,000 rows)
- **`filter_facets`**: 1 second (pre-aggregated)
- **Total**: ~6 seconds (vs. hours for real-time computation)

### Optimization Tips

1. **Index Strategy**:
   - Composite indexes on `(filter_key, value_numeric)` and `(filter_key, value_alpha)`
   - B-tree indexes on `product_id` for joins

2. **Refresh Strategy**:
   - Daily after catalog imports (not real-time)
   - Use `REFRESH MATERIALIZED VIEW CONCURRENTLY` to avoid locking

3. **Caching**:
   - FilterPanel caches definitions (reload only on taxonomy change)
   - Facets refresh on every filter change (dynamic)

---

## Troubleshooting

### Problem: Filter shows no options

**Cause**: No products have this ETIM feature
**Solution**:
```sql
-- Check feature coverage
SELECT COUNT(*)
FROM items.product_info p
JOIN items.product_features_mv pf ON pf.product_id = p.product_id
WHERE pf."FEATUREID" = 'EF009346'; -- CCT example
```

### Problem: Filter counts don't update

**Cause**: Dynamic facets function not called
**Solution**: Check FilterPanel.tsx calls `get_dynamic_facets()` in useEffect

### Problem: Range filter shows wrong min/max

**Cause**: UI config in `filter_definitions` incorrect
**Solution**:
```sql
-- Update bounds
UPDATE search.filter_definitions
SET ui_config = jsonb_set(
  ui_config,
  '{min}',
  '2700'::jsonb
)
WHERE filter_key = 'cct';
```

---

## Migration from product_custom_feature_group

The ETIM mappings originally came from `items.product_custom_feature_group` table. This was migrated to `search.filter_definitions` in November 2025.

**Original table structure**:
```sql
items.product_custom_feature_group (
  id, group_name, feature_id, feature_name,
  feature_type, sort_order
)
```

**New structure**:
```sql
search.filter_definitions (
  filter_key, label, etim_feature_id,
  filter_type, ui_config
)
```

**Migration notes**:
- `group_name` → `ui_config->filter_category`
- `feature_id` → `etim_feature_id`
- `feature_type` → `filter_type` (mapped N→range, A→multi-select, L→boolean)
- `sort_order` → `sort_order`

---

## Future Enhancements

### Planned Features

1. **Filter Presets**
   - "Warm White Indoor Dimmable" (predefined combinations)
   - Saved searches per user

2. **Advanced Dimming**
   - Combine dimming method multi-select with boolean dimmable
   - Show protocols only for dimmable products

3. **Smart Defaults**
   - Pre-select common values (e.g., IP20 for indoor)
   - Remember last-used filters

4. **Filter Analytics**
   - Track most-used filters
   - Remove unused filters from UI

### Possible Additions

- **Installation Ease**: Quick-mount, tool-free, etc.
- **Emergency Function**: Emergency lighting capability
- **Warranty**: Warranty period filter
- **Certifications**: CE, UL, ENEC, etc.

---

## Related Documentation

- **UI Components**: [docs/architecture/ui-components.md](../architecture/ui-components.md)
- **SQL Functions**: [docs/reference/sql-functions.md](../reference/sql-functions.md)
- **FOSSAPP Integration**: [docs/guides/fossapp-integration.md](./fossapp-integration.md)
- **Original Implementation Docs**: [docs/archive/2025-11-15-delta-implementation/](../archive/2025-11-15-delta-implementation/)

---

**Last Updated**: November 19, 2025
**Status**: Phase 1 deployed, Phase 2 ready, Phase 3 documented
**Contact**: Dimitri (Foss SA)
