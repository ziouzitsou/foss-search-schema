# Dynamic Facets - Context-Aware Filter Counts

**Implementation Date**: November 15, 2025
**Current Status**: ✅ Production (deployed in search-test-app)
**SQL File**: `sql/09-add-dynamic-facets.sql`
**Function**: `search.get_dynamic_facets()`

---

## Overview

**Dynamic facets** (also called "faceted search" or "guided navigation") is a user experience pattern where filter options and their counts **update in real-time** based on the user's current selections.

### The Problem It Solves

**Without Dynamic Facets** (Static Counts):
```
User sees: "IP65 (1,277 products)"
User selects: Category = "Indoor Ceiling"
User still sees: "IP65 (1,277 products)" ← WRONG! Most are outdoor
```

**With Dynamic Facets** (Context-Aware):
```
User sees: "IP65 (1,277 products)"
User selects: Category = "Indoor Ceiling"
User now sees: "IP65 (23 products)" ← CORRECT! Only indoor ceiling with IP65
```

### Benefits

✅ **Prevents Dead Ends**: Users never select filters that yield zero results
✅ **Guides Discovery**: Shows what's actually available in current context
✅ **Improves UX**: Counts feel responsive and intelligent
✅ **Reduces Frustration**: No "0 products found" surprises

---

## How It Works

### Architecture

```
User selects filter (e.g., "Indoor")
         ↓
FilterPanel component detects change
         ↓
Calls get_dynamic_facets() with current context
         ↓
Function filters products by context
         ↓
Counts filter options from filtered set
         ↓
Returns updated counts to UI
         ↓
UI updates filter badges (e.g., "IP65 (23)")
```

### Database Flow

```sql
-- Step 1: Filter products by current context
WITH filtered_products AS (
    SELECT product_id
    FROM items.product_info pi
    JOIN search.product_taxonomy_flags ptf USING (product_id)
    WHERE
        taxonomy_path && ARRAY['LUMINAIRE-INDOOR-CEILING']  -- User's category
        AND indoor = true  -- User's boolean filter
        AND supplier_name = ANY(ARRAY['Delta Light'])  -- User's supplier
)

-- Step 2: Count filter options from filtered products only
SELECT
    filter_key,
    filter_value,
    COUNT(*) as product_count
FROM search.product_filter_index
WHERE product_id IN (SELECT product_id FROM filtered_products)
GROUP BY filter_key, filter_value
ORDER BY product_count DESC;
```

### Result

Only filter values that **actually exist** in the filtered product set are returned, with accurate counts.

---

## Implementation

### SQL Function

**Function**: `search.get_dynamic_facets()`

**Location**: `sql/09-add-dynamic-facets.sql`

**Signature**:
```sql
CREATE FUNCTION search.get_dynamic_facets(
    p_taxonomy_codes TEXT[] DEFAULT NULL,    -- Selected categories
    p_filters JSONB DEFAULT '{}'::JSONB,     -- Active technical filters (future)
    p_suppliers TEXT[] DEFAULT NULL,          -- Selected suppliers
    p_indoor BOOLEAN DEFAULT NULL,            -- Indoor flag
    p_outdoor BOOLEAN DEFAULT NULL,           -- Outdoor flag
    p_submersible BOOLEAN DEFAULT NULL,       -- Submersible flag
    p_trimless BOOLEAN DEFAULT NULL,          -- Trimless flag
    p_cut_shape_round BOOLEAN DEFAULT NULL,   -- Cut shape round
    p_cut_shape_rectangular BOOLEAN DEFAULT NULL, -- Cut shape rectangular
    p_query TEXT DEFAULT NULL                 -- Search query
) RETURNS TABLE (
    filter_category TEXT,  -- "electricals", "design", "light_engine"
    filter_key TEXT,       -- "ip", "cct", "voltage"
    filter_value TEXT,     -- "IP65", "3000", "12V"
    product_count BIGINT   -- Number of products with this value
)
```

**How It Works**:
1. **Filters products** by taxonomy, boolean flags, suppliers, query
2. **Joins** with `product_filter_index` to get technical filter values
3. **Groups** by filter_key and filter_value
4. **Counts** products per value
5. **Returns** only values with product_count > 0

---

## UI Integration

### FilterPanel Component

**File**: `search-test-app/components/FilterPanel.tsx`

**Key Code**:
```typescript
useEffect(() => {
  loadFilters()
}, [
  taxonomyCode,
  selectedTaxonomies.join(','),
  indoor,
  outdoor,
  submersible,
  trimless,
  cutShapeRound,
  cutShapeRectangular,
  query,
  suppliers.join(',')
])

const loadFilters = async () => {
  // Get DYNAMIC filter facets based on selected taxonomies AND context
  const { data: facets, error } = await supabase
    .rpc('get_dynamic_facets', {
      p_taxonomy_codes: selectedTaxonomies.length > 0 ? selectedTaxonomies : null,
      p_filters: null,
      p_suppliers: suppliers.length > 0 ? suppliers : null,
      p_indoor: indoor,
      p_outdoor: outdoor,
      p_submersible: submersible,
      p_trimless: trimless,
      p_cut_shape_round: cutShapeRound,
      p_cut_shape_rectangular: cutShapeRectangular,
      p_query: query
    })

  setFilterFacets(facets || [])
  console.log('✅ Dynamic technical filter facets loaded with context')
}
```

**When Facets Reload**:
- User selects/deselects a category
- User toggles a boolean filter (indoor/outdoor/etc.)
- User changes supplier filter
- User types in search box

**Result**: Filter options and counts update immediately to reflect available products.

---

## Boolean Flag Facets

In addition to technical filters, we also have **dynamic boolean flag facets** for the Location/Options section.

### Function: `get_filter_facets_with_context()`

**Location**: `sql/08-add-dynamic-filter-search.sql`

**Signature**:
```sql
CREATE FUNCTION search.get_filter_facets_with_context(
    p_query TEXT DEFAULT NULL,
    p_taxonomy_codes TEXT[] DEFAULT NULL,
    p_suppliers TEXT[] DEFAULT NULL,
    -- All boolean filters as params
) RETURNS TABLE (
    flag_name TEXT,
    true_count BIGINT,
    false_count BIGINT
)
```

**Returns**:
```
flag_name      | true_count | false_count
---------------|------------|-------------
indoor         | 8,245      | 3,102
outdoor        | 1,456      | 9,891
submersible    | 234        | 11,113
trimless       | 1,892      | 9,455
```

**UI Usage**:
```typescript
// page.tsx - Main search interface
const [flagCounts, setFlagCounts] = useState<Record<string, {...}>>({})

useEffect(() => {
  const { data } = await supabase.rpc('get_filter_facets_with_context', {
    p_taxonomy_codes: selectedTaxonomies,
    p_indoor: indoor,
    p_outdoor: outdoor,
    // ... other filters
  })

  setFlagCounts(Object.fromEntries(
    data.map(item => [item.flag_name, {
      true_count: item.true_count,
      false_count: item.false_count
    }])
  ))
}, [selectedTaxonomies, indoor, outdoor, ...])

// Render with count
<span>Indoor {flagCounts.indoor && `(${flagCounts.indoor.true_count})`}</span>
```

---

## Performance

### Query Optimization

**Without Dynamic Facets**:
- Static materialized view: `search.filter_facets`
- Refreshed daily
- Shows ALL values (including zero-count)
- Query time: <50ms ✅

**With Dynamic Facets**:
- Real-time query on `product_filter_index`
- Filtered by current context
- Shows ONLY available values
- Query time: <100ms ✅

**Tradeoff**: Slightly slower (50ms → 100ms) but much better UX

### Optimization Techniques

1. **Indexed Filtering**:
   - `product_taxonomy_flags`: Indexed on `indoor`, `outdoor`, etc.
   - `product_filter_index`: Composite indexes on `(filter_key, alphanumeric_value)` and `(filter_key, boolean_value)`

2. **Smart CTE**:
   - `filtered_products` CTE narrows down product set first
   - Then counts from smaller set (faster than full scan)

3. **Parameter Efficiency**:
   - NULL parameters skip filters (no performance penalty)
   - `WHERE (p_indoor IS NULL OR ptf.indoor = p_indoor)` ← Fast when NULL

4. **Client-Side Caching**:
   - FilterPanel caches facets until context changes
   - Prevents redundant calls on component re-renders

---

## Examples

### Example 1: Category Selection

**User Action**: Selects "Indoor Ceiling Recessed" category

**Before**:
```
IP Rating options:
- IP20 (5,001 products) ← Includes outdoor, floor, etc.
- IP44 (484 products)
- IP54 (198 products)
- IP65 (1,277 products) ← Many outdoor
```

**After** (with dynamic facets):
```
IP Rating options:
- IP20 (4,234 products) ← Only indoor ceiling recessed
- IP44 (123 products)
- IP54 (45 products)
- IP65 (23 products) ← Only indoor ceiling recessed IP65
```

### Example 2: Boolean Flag Selection

**User Action**: Checks "Indoor" checkbox

**Before**:
```
Outdoor checkbox shows: (2,225 products)
```

**After** (with dynamic facets):
```
Outdoor checkbox shows: (368 products) ← Only products that are BOTH indoor AND outdoor
```

**Explanation**: Products flagged as both `indoor=true` AND `outdoor=true` (versatile products)

### Example 3: Supplier Filter

**User Action**: Selects "Delta Light" supplier

**Before**:
```
CCT options:
- 2700K (3,456 products) ← Includes all suppliers
- 3000K (5,234 products)
- 4000K (2,789 products)
```

**After** (with dynamic facets):
```
CCT options:
- 2700K (234 products) ← Only Delta Light
- 3000K (456 products)
- 4000K (189 products)
```

---

## Comparison: Static vs Dynamic Facets

| Aspect | Static Facets | Dynamic Facets |
|--------|---------------|----------------|
| **Data Source** | Materialized view | Real-time query |
| **Update Frequency** | Daily refresh | Every filter change |
| **Counts** | All products | Filtered products only |
| **Zero-count values** | Shown | Hidden |
| **Query Performance** | <50ms | <100ms |
| **UX** | Can be misleading | Always accurate |
| **Implementation** | Simpler | More complex |

### When to Use Each

**Static Facets**:
- ✅ Initial page load (no filters applied)
- ✅ High-traffic pages (reduce DB load)
- ✅ Simple catalogs (few filters)

**Dynamic Facets**:
- ✅ After user applies filters (this is what we do)
- ✅ Complex product catalogs (many attributes)
- ✅ When preventing dead ends is critical

### Our Approach (Hybrid)

We use **dynamic facets** for technical filters but **could** use static facets as fallback:
- Load `filter_facets` materialized view on initial load (fast)
- Switch to `get_dynamic_facets()` after first filter applied (accurate)

**Current**: We use dynamic facets exclusively (simplicity over micro-optimization)

---

## Troubleshooting

### Problem: Counts don't update

**Symptom**: User selects a filter, counts stay the same

**Causes & Solutions**:
1. **useEffect not triggered**
   - Check dependency array includes all filter state
   - Add console.log to verify effect runs

2. **Function not called**
   - Check network tab for RPC call
   - Verify function name is correct

3. **Wrong parameters**
   - Log parameters being sent
   - Verify they match function signature

### Problem: All counts are zero

**Symptom**: After selecting filters, all facet counts show 0

**Causes**:
1. **Too restrictive filters** (no products match)
   - Check product count: `SELECT COUNT(*) FROM search.product_taxonomy_flags WHERE indoor=true AND outdoor=true`

2. **Wrong taxonomy codes**
   - Verify `selectedTaxonomies` array is correct
   - Check taxonomy codes exist: `SELECT * FROM search.taxonomy WHERE code = 'YOUR_CODE'`

3. **Database schema mismatch**
   - Verify column names match: `\d search.product_taxonomy_flags`
   - Check ETIM feature IDs exist in `product_filter_index`

### Problem: Slow performance (>500ms)

**Causes**:
1. **Missing indexes**
   ```sql
   -- Check existing indexes
   \d search.product_filter_index
   \d search.product_taxonomy_flags

   -- Add if missing
   CREATE INDEX IF NOT EXISTS idx_pfi_filter_key_alpha
   ON search.product_filter_index(filter_key, alphanumeric_value);
   ```

2. **Too many products**
   - Add LIMIT to CTE if acceptable
   - Consider pre-aggregating common filter combinations

3. **Stale statistics**
   ```sql
   ANALYZE search.product_filter_index;
   ANALYZE search.product_taxonomy_flags;
   ```

---

## Future Enhancements

### Planned Features

1. **Facet Caching**
   - Cache common filter combinations in Redis
   - Invalidate on catalog updates
   - Expected improvement: 100ms → 10ms

2. **Smart Filtering**
   - Hide filters with <5 options (not useful)
   - Auto-collapse categories with 0 options
   - Highlight filters with most variety

3. **Progressive Loading**
   - Load facets for visible filters only
   - Lazy-load counts for collapsed categories
   - Reduces initial query complexity

4. **Analytics Integration**
   - Track which filters users use most
   - Remove unused filters from UI
   - Optimize indexing for popular filters

### Possible Additions

**Cross-Filter Dependencies**:
```typescript
// If "Dimmable = Yes", only show dimming methods
if (filters.dimmable === true) {
  showFilters(['dimming_dali', 'dimming_0_10v'])
} else {
  hideFilters(['dimming_dali', 'dimming_0_10v'])
}
```

**Range Histograms**:
```sql
-- Show distribution of CCT values
SELECT
    FLOOR(numeric_value / 500) * 500 as cct_bucket,
    COUNT(*) as product_count
FROM search.product_filter_index
WHERE filter_key = 'cct'
GROUP BY cct_bucket
ORDER BY cct_bucket;

-- Returns: 2500 (234), 3000 (1,234), 3500 (456), ...
```

**Auto-Suggest Values**:
```typescript
// As user types in search, suggest matching filter values
searchQuery = "warm white"
→ Suggest: CCT = 2700-3000K
→ Auto-apply: { cct: { min: 2700, max: 3000 } }
```

---

## Testing

### Unit Tests (SQL)

**Test 1: Basic Functionality**
```sql
-- Should return IP ratings for indoor products only
SELECT *
FROM search.get_dynamic_facets(
    p_indoor := true
)
WHERE filter_key = 'ip';

-- Expected: IP20 should dominate (indoor typical)
```

**Test 2: Multiple Filters**
```sql
-- Should return very specific counts
SELECT *
FROM search.get_dynamic_facets(
    p_taxonomy_codes := ARRAY['LUMINAIRE-INDOOR-CEILING'],
    p_indoor := true,
    p_suppliers := ARRAY['Delta Light']
)
WHERE filter_key = 'cct';

-- Expected: Smaller counts than test 1
```

**Test 3: Zero Results**
```sql
-- Should return empty set (no submersible ceiling luminaires)
SELECT *
FROM search.get_dynamic_facets(
    p_taxonomy_codes := ARRAY['LUMINAIRE-CEILING'],
    p_submersible := true
);

-- Expected: 0 rows
```

### Integration Tests (UI)

**Test 1: Count Updates**
1. Load page, note IP65 count
2. Select "Indoor" checkbox
3. Verify IP65 count decreased
4. Select "Outdoor" checkbox
5. Verify IP65 count increased

**Test 2: Zero-Count Hidden**
1. Select very specific filters (e.g., "Indoor + Submersible")
2. Verify filters with 0 products are hidden
3. Verify UI shows "No options available" message

**Test 3: Performance**
1. Open browser DevTools Network tab
2. Select a filter
3. Measure RPC call time for `get_dynamic_facets`
4. Verify <200ms response time

---

## Related Documentation

- **Delta Light Filters**: [./delta-light-filters.md](./delta-light-filters.md) - Technical filters implementation
- **UI Components**: [../architecture/ui-components.md](../architecture/ui-components.md) - FilterPanel component
- **SQL Functions**: [../reference/sql-functions.md](../reference/sql-functions.md) - All RPC functions
- **FOSSAPP Integration**: [./fossapp-integration.md](./fossapp-integration.md) - Production integration guide

---

**Last Updated**: November 19, 2025
**Status**: Production (deployed in search-test-app)
**Performance**: <100ms average query time
**Contact**: Dimitri (Foss SA)
