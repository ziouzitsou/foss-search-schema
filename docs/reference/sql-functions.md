# SQL Functions Reference

**Database**: Supabase PostgreSQL
**Schema**: `search.*` (implementation) + `public.*` (wrappers for Supabase client)
**Total Functions**: 7 RPC functions
**Implementation Files**: `sql/04-create-search-functions.sql`, `sql/08-add-dynamic-filter-search.sql`, `sql/09-add-dynamic-facets.sql`

---

## Overview

The search system exposes 7 PostgreSQL functions via Supabase RPC. All functions have **public schema wrappers** to enable client-side calls with anon/authenticated keys.

### Function List

| Function | Purpose | File | Status |
|----------|---------|------|--------|
| **search_products_with_filters** | Main product search with filters | 08 | ✅ Production |
| **count_products_with_filters** | Count matching products | 08 | ✅ Production |
| **get_dynamic_facets** | Context-aware filter options | 09 | ✅ Production |
| **get_filter_facets_with_context** | Dynamic boolean flag counts | 08 | ✅ Production |
| **get_filter_definitions_with_type** | Filter UI configuration | 04 | ✅ Production |
| **get_taxonomy_tree** | Hierarchical category tree | 04 | ✅ Production |
| **get_search_statistics** | System statistics | 04 | ✅ Production |

---

## 1. search_products_with_filters()

**Purpose**: Main product search function with full filter support

**File**: `sql/08-add-dynamic-filter-search.sql`

### Signature

```sql
CREATE FUNCTION search.search_products_with_filters(
    p_query TEXT DEFAULT NULL,                    -- Search query
    p_filters JSONB DEFAULT '{}'::JSONB,          -- Technical filters (Delta)
    p_taxonomy_codes TEXT[] DEFAULT NULL,          -- Selected categories
    p_suppliers TEXT[] DEFAULT NULL,               -- Selected suppliers
    p_indoor BOOLEAN DEFAULT NULL,                 -- Indoor flag
    p_outdoor BOOLEAN DEFAULT NULL,                -- Outdoor flag
    p_submersible BOOLEAN DEFAULT NULL,            -- Submersible flag
    p_trimless BOOLEAN DEFAULT NULL,               -- Trimless flag
    p_cut_shape_round BOOLEAN DEFAULT NULL,        -- Round cut shape
    p_cut_shape_rectangular BOOLEAN DEFAULT NULL,  -- Rectangular cut shape
    p_sort_by TEXT DEFAULT 'relevance',           -- Sort order
    p_limit INTEGER DEFAULT 24,                    -- Results limit
    p_offset INTEGER DEFAULT 0                     -- Pagination offset
) RETURNS TABLE (
    product_id UUID,
    foss_pid TEXT,
    description_short TEXT,
    description_long TEXT,
    supplier_name TEXT,
    class_name TEXT,
    price NUMERIC,
    image_url TEXT,
    taxonomy_path TEXT[],
    flags JSONB,                                  -- Boolean flags object
    key_features JSONB,                           -- Key technical features
    relevance_score INTEGER                       -- Search relevance
)
```

### Parameters

**Search Parameters**:
- `p_query`: Full-text search across description_short and description_long
- `p_sort_by`: Sort order (`relevance`, `price_asc`, `price_desc`)
- `p_limit` / `p_offset`: Pagination control

**Taxonomy Filters**:
- `p_taxonomy_codes`: Array of taxonomy codes (e.g., `['LUMINAIRE-INDOOR-CEILING']`)
  - Uses `&&` operator (array overlap)
  - Products can have multiple taxonomy paths

**Boolean Flag Filters**:
- `p_indoor`, `p_outdoor`, `p_submersible`, `p_trimless`
- `p_cut_shape_round`, `p_cut_shape_rectangular`
- Three-state: `TRUE` (must have), `FALSE` (must not have), `NULL` (ignore)

**Supplier Filter**:
- `p_suppliers`: Array of supplier names (e.g., `['Delta Light', 'Meyer Lighting']`)

**Technical Filters (`p_filters` JSONB)**:

Format:
```json
{
  "voltage": ["12V", "24V"],              // Multi-select alphanumeric
  "dimmable": true,                       // Boolean
  "class": ["Class I", "Class II"],       // Multi-select alphanumeric
  "ip": ["IP65", "IP67"],                 // Multi-select alphanumeric
  "finishing_colour": ["Black", "White"], // Multi-select alphanumeric
  "cct": {"min": 3000, "max": 4000},      // Range numeric
  "cri": ["90", "95"],                    // Multi-select alphanumeric
  "lumens_output": {"min": 500, "max": 2000} // Range numeric
}
```

### Return Fields

**Product Info**:
- `product_id`: UUID primary key
- `foss_pid`: Human-readable product ID
- `description_short`: Product name
- `description_long`: Detailed description
- `supplier_name`: Manufacturer name
- `class_name`: ETIM class name
- `price`: Start price (numeric)
- `image_url`: Primary product image

**Classification**:
- `taxonomy_path`: Array of taxonomy codes (e.g., `{LUMINAIRE, LUM-CEIL, LUM-CEIL-REC}`)

**Flags Object**:
```json
{
  "indoor": true,
  "outdoor": false,
  "ceiling": true,
  "wall": false,
  "pendant": false,
  "recessed": true,
  "dimmable": true,
  "submersible": false,
  "trimless": false,
  "cut_shape_round": true,
  "cut_shape_rectangular": false
}
```

**Key Features Object**:
```json
{
  "voltage": "12V",
  "class": "Class I",
  "ip": "IP20",
  "finishing_colour": "Black",
  "cct": 3000,
  "cri": "90",
  "lumens_output": 1200
}
```

### Examples

**Example 1: Simple Text Search**
```typescript
const { data } = await supabase.rpc('search_products_with_filters', {
  p_query: 'LED downlight',
  p_limit: 24
})
```

**Example 2: Category Filter**
```typescript
const { data } = await supabase.rpc('search_products_with_filters', {
  p_taxonomy_codes: ['LUMINAIRE-INDOOR-CEILING'],
  p_limit: 24
})
```

**Example 3: Boolean Flags**
```typescript
const { data } = await supabase.rpc('search_products_with_filters', {
  p_indoor: true,
  p_recessed: true,
  p_dimmable: true,
  p_limit: 24
})
```

**Example 4: Technical Filters**
```typescript
const { data } = await supabase.rpc('search_products_with_filters', {
  p_filters: {
    cct: { min: 3000, max: 4000 },
    ip: ['IP65', 'IP67'],
    dimmable: true
  },
  p_limit: 24
})
```

**Example 5: Combined (Production)**
```typescript
const { data } = await supabase.rpc('search_products_with_filters', {
  p_query: 'ceiling',
  p_taxonomy_codes: ['LUMINAIRE-INDOOR-CEILING'],
  p_indoor: true,
  p_suppliers: ['Delta Light'],
  p_filters: {
    cct: { min: 3000, max: 4000 },
    ip: ['IP20']
  },
  p_sort_by: 'price_asc',
  p_limit: 24,
  p_offset: 0
})
```

### Performance

- **Typical**: 100-200ms (with filters)
- **Simple query**: <50ms
- **Complex (many filters)**: <300ms
- **Optimization**: Uses indexes on `product_taxonomy_flags` and `product_filter_index`

---

## 2. count_products_with_filters()

**Purpose**: Count total products matching filters (for pagination "X of Y results")

**File**: `sql/08-add-dynamic-filter-search.sql`

### Signature

```sql
CREATE FUNCTION search.count_products_with_filters(
    p_query TEXT DEFAULT NULL,
    p_filters JSONB DEFAULT '{}'::JSONB,
    p_taxonomy_codes TEXT[] DEFAULT NULL,
    p_suppliers TEXT[] DEFAULT NULL,
    p_indoor BOOLEAN DEFAULT NULL,
    p_outdoor BOOLEAN DEFAULT NULL,
    p_submersible BOOLEAN DEFAULT NULL,
    p_trimless BOOLEAN DEFAULT NULL,
    p_cut_shape_round BOOLEAN DEFAULT NULL,
    p_cut_shape_rectangular BOOLEAN DEFAULT NULL
) RETURNS BIGINT
```

### Parameters

Same as `search_products_with_filters()` **except**:
- No `p_sort_by`, `p_limit`, `p_offset` (count doesn't need these)

### Return Value

Single `BIGINT` representing total matching products.

### Example

```typescript
const { data: count } = await supabase.rpc('count_products_with_filters', {
  p_taxonomy_codes: ['LUMINAIRE-INDOOR-CEILING'],
  p_indoor: true,
  p_filters: {
    cct: { min: 3000, max: 4000 }
  }
})

console.log(`Found ${count} products`) // "Found 234 products"
```

### Performance

- **Typical**: <50ms
- **Complex filters**: <100ms
- **Optimization**: Uses same indexes as search function

### UI Usage

```typescript
// Display: "Showing 24 of 234 products"
const totalCount = await count_products_with_filters(...)
const displayText = `Showing ${products.length} of ${totalCount} products`
```

---

## 3. get_dynamic_facets()

**Purpose**: Get context-aware technical filter options with product counts

**File**: `sql/09-add-dynamic-facets.sql`

### Signature

```sql
CREATE FUNCTION search.get_dynamic_facets(
    p_taxonomy_codes TEXT[] DEFAULT NULL,
    p_filters JSONB DEFAULT '{}'::JSONB,        -- Currently unused
    p_suppliers TEXT[] DEFAULT NULL,
    p_indoor BOOLEAN DEFAULT NULL,
    p_outdoor BOOLEAN DEFAULT NULL,
    p_submersible BOOLEAN DEFAULT NULL,
    p_trimless BOOLEAN DEFAULT NULL,
    p_cut_shape_round BOOLEAN DEFAULT NULL,
    p_cut_shape_rectangular BOOLEAN DEFAULT NULL,
    p_query TEXT DEFAULT NULL
) RETURNS TABLE (
    filter_category TEXT,     -- "electricals", "design", "light_engine"
    filter_key TEXT,          -- "ip", "cct", "voltage"
    filter_value TEXT,        -- "IP65", "3000", "12V"
    product_count BIGINT      -- Number of products with this value
)
```

### Parameters

Same context filters as search function (taxonomy, boolean flags, suppliers, query).

### Return Fields

- `filter_category`: Group (electricals, design, light_engine)
- `filter_key`: Filter identifier (ip, cct, voltage, etc.)
- `filter_value`: Specific value (IP65, 3000K, 12V)
- `product_count`: How many products have this value **in current context**

### How It Works

1. Filters products by current taxonomy + boolean flags + suppliers
2. Counts distinct values from `product_filter_index` for filtered products
3. Returns only values with `product_count > 0` (hides unavailable options)

### Example

```typescript
// User selects "Indoor" → get IP rating options for indoor products only
const { data: facets } = await supabase.rpc('get_dynamic_facets', {
  p_taxonomy_codes: ['LUMINAIRE-INDOOR-CEILING'],
  p_indoor: true
})

/* Result:
[
  { filter_category: 'design', filter_key: 'ip', filter_value: 'IP20', product_count: 4234 },
  { filter_category: 'design', filter_key: 'ip', filter_value: 'IP44', product_count: 123 },
  { filter_category: 'design', filter_key: 'ip', filter_value: 'IP54', product_count: 45 },
  ...
]
*/
```

### UI Usage

```typescript
// Group by filter_key, show as checkboxes with counts
facets.filter(f => f.filter_key === 'ip').map(facet => (
  <label>
    <input type="checkbox" />
    {facet.filter_value} ({facet.product_count})
  </label>
))

/* Renders:
☐ IP20 (4,234)
☐ IP44 (123)
☐ IP54 (45)
☐ IP65 (23) ← Only 23 indoor ceiling products with IP65!
*/
```

### Performance

- **Typical**: <100ms
- **Many filters**: <200ms
- **Why fast**: CTE narrows product set first, then counts

---

## 4. get_filter_facets_with_context()

**Purpose**: Get context-aware boolean flag counts (indoor, outdoor, etc.)

**File**: `sql/08-add-dynamic-filter-search.sql`

### Signature

```sql
CREATE FUNCTION search.get_filter_facets_with_context(
    p_query TEXT DEFAULT NULL,
    p_taxonomy_codes TEXT[] DEFAULT NULL,
    p_suppliers TEXT[] DEFAULT NULL,
    p_indoor BOOLEAN DEFAULT NULL,
    p_outdoor BOOLEAN DEFAULT NULL,
    p_submersible BOOLEAN DEFAULT NULL,
    p_trimless BOOLEAN DEFAULT NULL,
    p_cut_shape_round BOOLEAN DEFAULT NULL,
    p_cut_shape_rectangular BOOLEAN DEFAULT NULL
) RETURNS TABLE (
    flag_name TEXT,           -- "indoor", "outdoor", "submersible", etc.
    true_count BIGINT,        -- Count where flag = TRUE
    false_count BIGINT        -- Count where flag = FALSE
)
```

### Parameters

Same context filters as search function.

### Return Fields

- `flag_name`: Boolean flag identifier
- `true_count`: Products with flag = TRUE (in current context)
- `false_count`: Products with flag = FALSE (in current context)

### Example

```typescript
// User selects "Indoor Ceiling" category
const { data: counts } = await supabase.rpc('get_filter_facets_with_context', {
  p_taxonomy_codes: ['LUMINAIRE-INDOOR-CEILING']
})

/* Result:
[
  { flag_name: 'indoor', true_count: 8245, false_count: 0 },
  { flag_name: 'outdoor', true_count: 368, false_count: 7877 },  ← 368 are BOTH indoor AND outdoor!
  { flag_name: 'submersible', true_count: 12, false_count: 8233 },
  { flag_name: 'recessed', true_count: 3456, false_count: 4789 },
  { flag_name: 'dimmable', true_count: 7234, false_count: 1011 }
]
*/
```

### UI Usage

```typescript
// Display checkbox with dynamic count
<label>
  <input type="checkbox" checked={indoor} onChange={...} />
  Indoor {counts.indoor && `(${counts.indoor.true_count.toLocaleString()})`}
</label>

/* Renders:
☑ Indoor (8,245)   ← Current selection
☐ Outdoor (368)    ← Only 368 products are BOTH indoor AND outdoor
☐ Submersible (12)
*/
```

### Why Both true_count AND false_count?

Allows showing both states:
- "Yes" option: show `true_count`
- "No" option: show `false_count`

**Example**:
```
Dimmable:
☐ Yes (7,234)  ← true_count
☐ No (1,011)   ← false_count
```

### Performance

- **Typical**: <50ms
- **Complex context**: <100ms
- **Why fast**: Single aggregate query on indexed boolean columns

---

## 5. get_filter_definitions_with_type()

**Purpose**: Get filter UI configuration for a taxonomy

**File**: `sql/04-create-search-functions.sql`

### Signature

```sql
CREATE FUNCTION search.get_filter_definitions_with_type(
    p_taxonomy_code TEXT DEFAULT 'LUMINAIRE'
) RETURNS TABLE (
    filter_key TEXT,
    label TEXT,
    filter_type TEXT,          -- "boolean", "multi-select", "range"
    etim_feature_id TEXT,      -- ETIM feature code (e.g., "EF009346")
    etim_feature_type TEXT,    -- "A" (Alphanumeric), "L" (Logical), "R" (Range), "N" (Numeric)
    ui_config JSONB,           -- UI configuration
    display_order INTEGER      -- Sort order
)
```

### Parameters

- `p_taxonomy_code`: Taxonomy to get filters for (currently not used for filtering, returns all)

### Return Fields

**Filter Identification**:
- `filter_key`: Unique identifier (e.g., "cct", "ip", "voltage")
- `label`: Display name (e.g., "CCT (Color Temperature)", "IP Rating")
- `etim_feature_id`: ETIM feature code (e.g., "EF009346")

**Filter Type**:
- `filter_type`: UI component type
  - `"boolean"`: Yes/No toggle (e.g., Dimmable)
  - `"multi-select"`: Checkbox list (e.g., IP Rating, Finishing Colour)
  - `"range"`: Min/max inputs (e.g., CCT 2700-6500K)
- `etim_feature_type`: ETIM data type
  - `"L"`: Logical (boolean)
  - `"A"`: Alphanumeric (categorical)
  - `"N"`: Numeric (single value)
  - `"R"`: Range (min/max)

**UI Configuration** (`ui_config` JSONB):
```json
{
  "filter_category": "light_engine",
  "min": 2700,
  "max": 6500,
  "step": 100,
  "unit": "K",
  "show_count": true,
  "show_icons": false,
  "color_swatches": false,
  "presets": [
    {"label": "Warm White", "min": 2700, "max": 3000},
    {"label": "Neutral White", "min": 3500, "max": 4500}
  ]
}
```

**Display Order**:
- `display_order`: Sort order in UI (lower = shown first)

### Example

```typescript
const { data: definitions } = await supabase.rpc('get_filter_definitions_with_type', {
  p_taxonomy_code: 'LUMINAIRE'
})

/* Result:
[
  {
    filter_key: 'voltage',
    label: 'Voltage',
    filter_type: 'multi-select',
    etim_feature_id: 'EF005127',
    etim_feature_type: 'A',
    ui_config: {
      filter_category: 'electricals',
      show_count: true
    },
    display_order: 10
  },
  {
    filter_key: 'cct',
    label: 'CCT (Color Temperature)',
    filter_type: 'range',
    etim_feature_id: 'EF009346',
    etim_feature_type: 'R',
    ui_config: {
      filter_category: 'light_engine',
      min: 2700,
      max: 6500,
      unit: 'K',
      step: 100
    },
    display_order: 60
  },
  ...
]
*/
```

### UI Usage

```typescript
// Render appropriate component based on filter_type
definitions.forEach(def => {
  switch (def.filter_type) {
    case 'boolean':
      return <BooleanFilter {...def} />
    case 'multi-select':
      return <MultiSelectFilter {...def} />
    case 'range':
      return <RangeFilter {...def} />
  }
})
```

### Performance

- **Typical**: <10ms (small table, ~8 rows)
- **Cached**: FilterPanel loads once per taxonomy change

---

## 6. get_taxonomy_tree()

**Purpose**: Get hierarchical product taxonomy tree

**File**: `sql/04-create-search-functions.sql`

### Signature

```sql
CREATE FUNCTION search.get_taxonomy_tree()
RETURNS TABLE (
    code TEXT,              -- Taxonomy code (e.g., "LUMINAIRE-CEILING")
    parent_code TEXT,       -- Parent code (e.g., "LUMINAIRE")
    level INTEGER,          -- Tree level (1=root, 2=category, 3=type)
    name TEXT,              -- Display name
    icon TEXT,              -- Icon code/emoji
    product_count INTEGER   -- Number of products in this category
)
```

### Parameters

None.

### Return Fields

- `code`: Unique taxonomy code
- `parent_code`: Parent in tree (NULL for root)
- `level`: Tree depth (1, 2, or 3)
- `name`: Human-readable name
- `icon`: Icon for display (can be NULL)
- `product_count`: Products in this category

### Example

```typescript
const { data: tree } = await supabase.rpc('get_taxonomy_tree')

/* Result:
[
  { code: 'ROOT', parent_code: null, level: 0, name: 'All Products', product_count: 14889 },
  { code: 'LUMINAIRE', parent_code: 'ROOT', level: 1, name: 'Luminaires', icon: '💡', product_count: 13336 },
  { code: 'LUMINAIRE-INDOOR', parent_code: 'LUMINAIRE', level: 2, name: 'Indoor', product_count: 10034 },
  { code: 'LUMINAIRE-INDOOR-CEILING', parent_code: 'LUMINAIRE-INDOOR', level: 3, name: 'Ceiling', icon: '⬆️', product_count: 4567 },
  { code: 'LUMINAIRE-INDOOR-WALL', parent_code: 'LUMINAIRE-INDOOR', level: 3, name: 'Wall', icon: '◾', product_count: 2345 },
  ...
]
*/
```

### UI Usage (Building Tree)

```typescript
// Convert flat list to tree structure
function buildTree(nodes: TaxonomyNode[]) {
  const tree = {}

  nodes.forEach(node => {
    if (!node.parent_code) {
      tree[node.code] = { ...node, children: [] }
    }
  })

  nodes.forEach(node => {
    if (node.parent_code && tree[node.parent_code]) {
      tree[node.parent_code].children.push(node)
    }
  })

  return tree
}

// Render as expandable tree
function renderTree(node) {
  return (
    <div>
      <button onClick={() => toggleExpand(node.code)}>
        {node.icon} {node.name} ({node.product_count})
      </button>
      {expanded && node.children.map(child => renderTree(child))}
    </div>
  )
}
```

### Performance

- **Typical**: <20ms (small table, ~30 rows)
- **Cached**: Loaded once on app init

---

## 7. get_search_statistics()

**Purpose**: Get system-wide statistics

**File**: `sql/04-create-search-functions.sql`

### Signature

```sql
CREATE FUNCTION search.get_search_statistics()
RETURNS TABLE (
    stat_name TEXT,
    stat_value TEXT
)
```

### Parameters

None.

### Return Fields

- `stat_name`: Statistic identifier
- `stat_value`: Value as text

### Example

```typescript
const { data: stats } = await supabase.rpc('get_search_statistics')

// Convert to object
const statsObj = Object.fromEntries(
  stats.map(item => [item.stat_name, item.stat_value])
)

/* Result:
{
  total_products: "14889",
  indoor_products: "10034",
  outdoor_products: "2593",
  dimmable_products: "11220",
  filter_entries: "125000",
  taxonomy_nodes: "30"
}
*/
```

### UI Usage

```typescript
<div>
  <h3>📊 System Statistics</h3>
  <div>Total Products: {stats.total_products}</div>
  <div>Indoor: {stats.indoor_products}</div>
  <div>Outdoor: {stats.outdoor_products}</div>
  <div>Dimmable: {stats.dimmable_products}</div>
  <div>Filter Entries: {stats.filter_entries}</div>
</div>
```

### Performance

- **Typical**: <100ms
- **Why slower**: Counts across multiple large tables
- **Recommendation**: Call once on page load, cache result

---

## Public Schema Wrappers

All functions have **public schema wrappers** for Supabase client access:

```sql
-- Example wrapper
CREATE OR REPLACE FUNCTION public.search_products_with_filters(
    p_query TEXT DEFAULT NULL,
    -- ... all parameters
) RETURNS TABLE (...) AS $$
    SELECT * FROM search.search_products_with_filters(
        p_query, p_filters, p_taxonomy_codes, ...
    );
$$ LANGUAGE sql STABLE;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.search_products_with_filters TO anon, authenticated;
```

**Why wrappers?**
- Supabase client can't call `search.*` functions directly (schema access)
- Public wrappers expose functions via RPC with anon/authenticated keys
- Maintains security (functions don't require service role key)

---

## Common Usage Patterns

### Pattern 1: Initial Page Load

```typescript
// Load taxonomy tree + system stats
const [{ data: tree }, { data: stats }] = await Promise.all([
  supabase.rpc('get_taxonomy_tree'),
  supabase.rpc('get_search_statistics')
])
```

### Pattern 2: Category Selection

```typescript
// User selects category
const taxonomyCodes = ['LUMINAIRE-INDOOR-CEILING']

// Load filter definitions + dynamic facets + flag counts
const [{ data: definitions }, { data: facets }, { data: flagCounts }] = await Promise.all([
  supabase.rpc('get_filter_definitions_with_type', { p_taxonomy_code: 'LUMINAIRE' }),
  supabase.rpc('get_dynamic_facets', { p_taxonomy_codes: taxonomyCodes }),
  supabase.rpc('get_filter_facets_with_context', { p_taxonomy_codes: taxonomyCodes })
])
```

### Pattern 3: Search with Filters

```typescript
// User applies filters
const filters = {
  cct: { min: 3000, max: 4000 },
  ip: ['IP65']
}

// Get count + products in parallel
const [{ data: count }, { data: products }] = await Promise.all([
  supabase.rpc('count_products_with_filters', {
    p_taxonomy_codes: taxonomyCodes,
    p_indoor: true,
    p_filters: filters
  }),
  supabase.rpc('search_products_with_filters', {
    p_taxonomy_codes: taxonomyCodes,
    p_indoor: true,
    p_filters: filters,
    p_limit: 24,
    p_offset: 0
  })
])

// Display: "Showing 24 of 234 products"
```

### Pattern 4: Load More (Pagination)

```typescript
const [page, setPage] = useState(0)

const loadMore = async () => {
  const { data } = await supabase.rpc('search_products_with_filters', {
    p_taxonomy_codes: taxonomyCodes,
    p_filters: filters,
    p_limit: 24,
    p_offset: page * 24  // ← Increment offset
  })

  setProducts(prev => [...prev, ...data])
  setPage(page + 1)
}
```

---

## Error Handling

### Common Errors

**1. Invalid JSONB format**:
```typescript
// ❌ WRONG: String instead of array
p_filters: { ip: "IP65" }

// ✅ CORRECT: Array
p_filters: { ip: ["IP65"] }
```

**2. NULL vs empty array**:
```typescript
// ❌ WRONG: Empty array treated differently than NULL
p_taxonomy_codes: []

// ✅ CORRECT: Use NULL to mean "no filter"
p_taxonomy_codes: taxonomies.length > 0 ? taxonomies : null
```

**3. Type mismatch in filters**:
```typescript
// ❌ WRONG: Number in array for alphanumeric filter
p_filters: { cct: [3000, 4000] }  // CCT is alphanumeric!

// ✅ CORRECT: Use object for range
p_filters: { cct: { min: 3000, max: 4000 } }
```

### Error Response Handling

```typescript
try {
  const { data, error } = await supabase.rpc('search_products_with_filters', ...)

  if (error) {
    console.error('RPC error:', error)
    // Show user-friendly message
    setError('Failed to load products. Please try again.')
    return
  }

  setProducts(data)
} catch (err) {
  console.error('Unexpected error:', err)
  setError('An unexpected error occurred.')
}
```

---

## Performance Tips

### 1. Parallel Calls

```typescript
// ✅ GOOD: Parallel (fast)
const [count, products, facets] = await Promise.all([
  supabase.rpc('count_products_with_filters', ...),
  supabase.rpc('search_products_with_filters', ...),
  supabase.rpc('get_dynamic_facets', ...)
])

// ❌ BAD: Sequential (slow)
const count = await supabase.rpc('count_products_with_filters', ...)
const products = await supabase.rpc('search_products_with_filters', ...)
const facets = await supabase.rpc('get_dynamic_facets', ...)
```

### 2. Debounce User Input

```typescript
// Debounce filter changes to avoid excessive calls
const debouncedSearch = useMemo(
  () => debounce(() => handleSearch(), 300),
  []
)

useEffect(() => {
  debouncedSearch()
}, [filters])
```

### 3. Cache Static Data

```typescript
// Load once, cache in state
const [taxonomy, setTaxonomy] = useState(null)

useEffect(() => {
  if (!taxonomy) {
    supabase.rpc('get_taxonomy_tree').then(({ data }) => setTaxonomy(data))
  }
}, [])
```

### 4. Limit Facet Reloads

```typescript
// Only reload facets when context changes, not on every render
useEffect(() => {
  loadFacets()
}, [
  selectedTaxonomies.join(','),  // ← String comparison
  indoor,
  outdoor
  // Don't include every state variable!
])
```

---

## Related Documentation

- **UI Components**: [../architecture/ui-components.md](../architecture/ui-components.md) - React integration
- **Dynamic Facets**: [../guides/dynamic-facets.md](../guides/dynamic-facets.md) - Faceted search guide
- **Delta Light Filters**: [../guides/delta-light-filters.md](../guides/delta-light-filters.md) - Filter configuration
- **SQL Implementation**: [../../sql/README.md](../../sql/README.md) - SQL file execution guide

---

**Last Updated**: November 19, 2025
**Functions**: 7 RPC functions (all production-ready)
**Performance**: <200ms average (all functions combined)
**Client**: Supabase JS (v2.39.0+)
