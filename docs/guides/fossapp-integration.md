# FOSSAPP Search Integration Guide

Complete guide for integrating the search system into FOSSAPP using the existing server action pattern.

**Date**: 2025-11-03
**Compatible with**: FOSSAPP architecture (server actions + service role)

---

## 🎯 Integration Overview

The search system is **100% compatible** with FOSSAPP's existing architecture:

- ✅ Uses server actions (no client-side RPC calls)
- ✅ Uses `supabaseServer` with service role key
- ✅ Follows FOSSAPP's input validation pattern
- ✅ Returns empty arrays on error (no throwing)
- ✅ Matches existing code style and conventions

---

## 📋 Step-by-Step Integration

### Step 1: Copy Server Actions to FOSSAPP

Copy the search server actions to your actions file:

```bash
# Location: /home/dimitris/foss/fossapp/src/lib/actions.ts
# Add the search server actions to this file
```

**What to add**:
- Copy all type definitions from `search-server-actions.ts`
- Copy all server action functions
- The file already imports `supabaseServer` - perfect!

### Step 2: Add Search to Product Listing Page

**File**: `src/app/products/page.tsx` (or your product listing page)

**Pattern A: Using Advanced Search with Filters**

```typescript
'use client'

import { useState } from 'react'
import { searchProductsServerAction, SearchProduct, SearchFilters } from '@/lib/actions'

export default function ProductsPage() {
  const [products, setProducts] = useState<SearchProduct[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [filters, setFilters] = useState<SearchFilters>({
    indoor: undefined,
    outdoor: undefined,
    powerMin: undefined,
    powerMax: undefined,
    ipRatings: [],
    limit: 24
  })

  const handleSearch = async () => {
    setIsLoading(true)
    try {
      const results = await searchProductsServerAction(filters)
      setProducts(results)
    } catch (error) {
      console.error('Search error:', error)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div>
      {/* Filter UI */}
      <div className="filters">
        <input
          type="text"
          placeholder="Search products..."
          onChange={(e) => setFilters({ ...filters, query: e.target.value })}
        />

        <label>
          <input
            type="checkbox"
            checked={filters.indoor || false}
            onChange={(e) => setFilters({ ...filters, indoor: e.target.checked })}
          />
          Indoor
        </label>

        <label>
          <input
            type="checkbox"
            checked={filters.outdoor || false}
            onChange={(e) => setFilters({ ...filters, outdoor: e.target.checked })}
          />
          Outdoor
        </label>

        <input
          type="number"
          placeholder="Power Min (W)"
          onChange={(e) => setFilters({ ...filters, powerMin: Number(e.target.value) || undefined })}
        />

        <input
          type="number"
          placeholder="Power Max (W)"
          onChange={(e) => setFilters({ ...filters, powerMax: Number(e.target.value) || undefined })}
        />

        <button onClick={handleSearch} disabled={isLoading}>
          {isLoading ? 'Searching...' : 'Search'}
        </button>
      </div>

      {/* Results */}
      <div className="products-grid">
        {products.map((product) => (
          <div key={product.product_id} className="product-card">
            <h3>{product.description_short}</h3>
            <p>{product.supplier_name}</p>
            {product.price && <p>€{product.price.toFixed(2)}</p>}

            {/* Flags */}
            <div>
              {product.flags.indoor && <span>🏠 Indoor</span>}
              {product.flags.outdoor && <span>🌳 Outdoor</span>}
            </div>

            {/* Key Features */}
            <div>
              {product.key_features.power && (
                <span>⚡ {product.key_features.power}W</span>
              )}
              {product.key_features.color_temp && (
                <span>🌡️ {product.key_features.color_temp}K</span>
              )}
              {product.key_features.ip_rating && (
                <span>🛡️ {product.key_features.ip_rating}</span>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
```

**Pattern B: Drop-in Replacement for Existing Search**

If you already have `searchProductsAction(query: string)`, use the compat function:

```typescript
// In src/lib/actions.ts - add this line
export { searchProductsCompatAction as searchProductsAction } from './search-actions'

// OR keep both:
// Old: searchProductsAction (searches description_short, foss_pid, etc.)
// New: searchProductsServerAction (full search with filters)
```

### Step 3: Add Statistics Panel (Optional)

```typescript
'use client'

import { useEffect, useState } from 'react'
import { getSearchStatisticsServerAction, SearchStatistics } from '@/lib/actions'

export function SearchStatistics() {
  const [stats, setStats] = useState<SearchStatistics | null>(null)

  useEffect(() => {
    async function loadStats() {
      const data = await getSearchStatisticsServerAction()
      setStats(data)
    }
    loadStats()
  }, [])

  if (!stats) return <div>Loading statistics...</div>

  return (
    <div className="stats-panel">
      <h3>Database Statistics</h3>
      <ul>
        <li>Total Products: {stats.total_products.toLocaleString()}</li>
        <li>Indoor: {stats.indoor_products.toLocaleString()}</li>
        <li>Outdoor: {stats.outdoor_products.toLocaleString()}</li>
        <li>Dimmable: {stats.dimmable_products.toLocaleString()}</li>
      </ul>
    </div>
  )
}
```

---

## 🔐 Security Considerations

### Already Implemented ✅

1. **Input Validation**: All inputs validated and sanitized
   - Text queries: Max 200 chars, trimmed
   - Numbers: Range validated (0-10000)
   - IP ratings: Pattern validated (`/^IP\d{2}$/`)
   - Arrays: Max 20 items

2. **Service Role Security**:
   - Service role key NEVER exposed to client
   - Only used server-side in actions
   - RPC calls made from server, not browser

3. **SQL Injection Protection**:
   - All queries use parameterized RPC calls
   - No string concatenation in queries
   - Supabase handles escaping

### No Changes Needed ✅

Your existing `.env.local` already has:
```bash
SUPABASE_SERVICE_ROLE_KEY=your_key_here
NEXT_PUBLIC_SUPABASE_URL=your_url_here
```

---

## 🧪 Testing Before Integration

### Option 1: Test in Isolation

Use the test app at `/home/dimitris/foss/searchdb/search-test-app/`:

```bash
cd /home/dimitris/foss/searchdb/search-test-app
# Already running at http://localhost:3001
```

### Option 2: Test Server Actions Directly

Create a test API route in FOSSAPP:

```typescript
// src/app/api/search/test/route.ts
import { NextResponse } from 'next/server'
import { searchProductsServerAction } from '@/lib/actions'

export async function GET() {
  const results = await searchProductsServerAction({
    indoor: true,
    powerMin: 10,
    powerMax: 50,
    limit: 10
  })

  return NextResponse.json({
    count: results.length,
    results
  })
}
```

Test: `http://localhost:8080/api/search/test`

---

## 📊 Available Functions

### 1. `searchProductsServerAction(filters)`

**Full-featured search with all filters**

```typescript
const results = await searchProductsServerAction({
  query: 'LED',           // Text search
  indoor: true,           // Boolean flags
  outdoor: false,
  powerMin: 10,          // Numeric ranges
  powerMax: 50,
  colorTempMin: 2700,
  colorTempMax: 3000,
  ipRatings: ['IP65', 'IP67'],  // Multiple values
  sortBy: 'price_asc',   // Sorting
  limit: 24,             // Pagination
  offset: 0
})

// Returns: SearchProduct[]
```

### 2. `searchProductsCompatAction(query)`

**Simple text search - drop-in replacement**

```typescript
const results = await searchProductsCompatAction('LED downlight')

// Returns: SearchProduct[] (max 50 results)
```

### 3. `getSearchStatisticsServerAction()`

**Database statistics**

```typescript
const stats = await getSearchStatisticsServerAction()

// Returns: {
//   total_products: 13395,
//   indoor_products: 12257,
//   outdoor_products: 819,
//   dimmable_products: 0,
//   filter_entries: 56978,
//   taxonomy_nodes: 14,
//   classification_rules: 11,
//   filter_definitions: 5
// }
```

### 4. `getAvailableFacetsServerAction()`

**Get available filter values with counts**

```typescript
const facets = await getAvailableFacetsServerAction()

// Returns: [
//   {
//     filter_key: 'power',
//     filter_type: 'numeric_range',
//     label_en: 'Power Consumption',
//     facet_data: { min: 0.5, max: 300, avg: 43.18, count: 271 }
//   },
//   {
//     filter_key: 'ip_rating',
//     filter_type: 'alphanumeric',
//     label_en: 'IP Rating',
//     facet_data: {
//       values: [
//         { value: 'IP20', count: 5417 },
//         { value: 'IP67', count: 461 }
//       ]
//     }
//   }
// ]
```

### 5. `getTaxonomyTreeServerAction()`

**Taxonomy hierarchy for category navigation**

```typescript
const tree = await getTaxonomyTreeServerAction()

// Returns: [
//   {
//     code: 'EC001679',
//     parent_code: null,
//     level: 1,
//     name_en: 'Lighting Fixtures',
//     product_count: 13395,
//     icon: 'lightbulb'
//   },
//   // ... more nodes
// ]
```

---

## 🎨 UI Components Examples

### Filter Panel Component

```typescript
interface FilterPanelProps {
  filters: SearchFilters
  onFilterChange: (filters: SearchFilters) => void
  onSearch: () => void
}

export function FilterPanel({ filters, onFilterChange, onSearch }: FilterPanelProps) {
  return (
    <div className="filter-panel">
      {/* Text Search */}
      <div className="filter-group">
        <label>Search</label>
        <input
          type="text"
          value={filters.query || ''}
          onChange={(e) => onFilterChange({ ...filters, query: e.target.value })}
          placeholder="Search products..."
        />
      </div>

      {/* Location Filters */}
      <div className="filter-group">
        <label>Location</label>
        <div className="checkbox-group">
          <label>
            <input
              type="checkbox"
              checked={filters.indoor || false}
              onChange={(e) => onFilterChange({ ...filters, indoor: e.target.checked || undefined })}
            />
            Indoor
          </label>
          <label>
            <input
              type="checkbox"
              checked={filters.outdoor || false}
              onChange={(e) => onFilterChange({ ...filters, outdoor: e.target.checked || undefined })}
            />
            Outdoor
          </label>
        </div>
      </div>

      {/* Power Range */}
      <div className="filter-group">
        <label>Power (W)</label>
        <div className="range-inputs">
          <input
            type="number"
            placeholder="Min"
            value={filters.powerMin || ''}
            onChange={(e) => onFilterChange({
              ...filters,
              powerMin: e.target.value ? Number(e.target.value) : undefined
            })}
          />
          <span>-</span>
          <input
            type="number"
            placeholder="Max"
            value={filters.powerMax || ''}
            onChange={(e) => onFilterChange({
              ...filters,
              powerMax: e.target.value ? Number(e.target.value) : undefined
            })}
          />
        </div>
      </div>

      {/* IP Rating */}
      <div className="filter-group">
        <label>IP Rating</label>
        <select
          multiple
          value={filters.ipRatings || []}
          onChange={(e) => {
            const selected = Array.from(e.target.selectedOptions, option => option.value)
            onFilterChange({ ...filters, ipRatings: selected })
          }}
        >
          <option value="IP20">IP20</option>
          <option value="IP44">IP44</option>
          <option value="IP54">IP54</option>
          <option value="IP65">IP65</option>
          <option value="IP67">IP67</option>
        </select>
      </div>

      <button onClick={onSearch} className="search-button">
        Search
      </button>
    </div>
  )
}
```

### Product Card Component

```typescript
interface ProductCardProps {
  product: SearchProduct
}

export function ProductCard({ product }: ProductCardProps) {
  return (
    <div className="product-card">
      {product.image_url && (
        <img src={product.image_url} alt={product.description_short} />
      )}

      <div className="product-info">
        <h3>{product.description_short}</h3>
        <p className="supplier">{product.supplier_name}</p>
        <p className="foss-pid">{product.foss_pid}</p>

        {product.price && (
          <p className="price">€{product.price.toFixed(2)}</p>
        )}

        {/* Flags */}
        <div className="flags">
          {product.flags.indoor && <span className="badge">🏠 Indoor</span>}
          {product.flags.outdoor && <span className="badge">🌳 Outdoor</span>}
          {product.flags.ceiling && <span className="badge">Ceiling</span>}
          {product.flags.wall && <span className="badge">Wall</span>}
          {product.flags.dimmable && <span className="badge">✨ Dimmable</span>}
        </div>

        {/* Technical Specs */}
        <div className="specs">
          {product.key_features.power && (
            <span>⚡ {product.key_features.power}W</span>
          )}
          {product.key_features.color_temp && (
            <span>🌡️ {product.key_features.color_temp}K</span>
          )}
          {product.key_features.luminous_flux && (
            <span>💡 {product.key_features.luminous_flux}lm</span>
          )}
          {product.key_features.ip_rating && (
            <span>🛡️ {product.key_features.ip_rating}</span>
          )}
        </div>
      </div>
    </div>
  )
}
```

---

## 🚀 Migration Strategy

### Phase 1: Add Without Breaking Existing Code

1. Copy server actions to `src/lib/actions.ts`
2. Don't change existing `searchProductsAction`
3. Add new search page or tab for testing
4. Test with real users

### Phase 2: Gradual Replacement

1. Add advanced filters to existing pages
2. Keep simple text search as fallback
3. Monitor performance and user feedback

### Phase 3: Full Integration

1. Replace simple search with advanced search
2. Remove old search code
3. Optimize based on usage patterns

---

## 📈 Performance Considerations

### Materialized Views

The search system uses materialized views for fast performance. They need to be refreshed when products change:

```sql
-- Manual refresh (run after bulk imports)
REFRESH MATERIALIZED VIEW CONCURRENTLY search.product_taxonomy_flags;
REFRESH MATERIALIZED VIEW CONCURRENTLY search.product_filter_index;
REFRESH MATERIALIZED VIEW CONCURRENTLY search.filter_facets;
REFRESH MATERIALIZED VIEW CONCURRENTLY search.taxonomy_product_counts;

-- Or use the provided function
SELECT search.refresh_all_views();
```

### Automatic Refresh (Optional)

Add a cron job or trigger:

```sql
-- Example: Refresh every night at 2 AM
-- (Requires pg_cron extension)
SELECT cron.schedule(
  'refresh-search-views',
  '0 2 * * *',
  'SELECT search.refresh_all_views()'
);
```

---

## 🔧 Troubleshooting

### "Permission denied for schema search"

Already fixed! Permissions granted in `05-grant-permissions.sql`

### "Could not find function"

Make sure public wrappers are created (already done in `05-grant-permissions.sql`)

### Empty results returned

1. Check materialized views are populated:
```sql
SELECT COUNT(*) FROM search.product_filter_index;
```

2. Refresh views if needed:
```sql
SELECT search.refresh_all_views();
```

### Slow performance

1. Check if views need refresh:
```sql
SELECT schemaname, matviewname, last_refresh
FROM pg_matviews
WHERE schemaname = 'search';
```

2. Consider adding more indexes if needed

---

## 📚 Reference

### Complete Type Definitions

See `search-server-actions.ts` for full TypeScript definitions of:
- `SearchFilters` - All available filter options
- `SearchProduct` - Product result structure
- `SearchStatistics` - System statistics
- `FacetData` - Filter facets
- `TaxonomyNode` - Taxonomy tree structure

### SQL Files

All SQL files are in `/home/dimitris/foss/searchdb/`:
1. `01-create-search-schema.sql`
2. `02-populate-example-data.sql`
3. `03-create-materialized-views.sql`
4. `04-create-search-functions.sql`
5. `05-grant-permissions.sql`

### Test App Reference

Running at: http://localhost:3001
Location: `/home/dimitris/foss/searchdb/search-test-app/`

---

## ✅ Integration Checklist

Before deploying to production:

- [ ] Copy server actions to `src/lib/actions.ts`
- [ ] Add types to TypeScript definitions
- [ ] Create search UI component
- [ ] Test with various filter combinations
- [ ] Test error handling (network errors, empty results)
- [ ] Test pagination (offset/limit)
- [ ] Verify permissions work in production
- [ ] Set up materialized view refresh schedule
- [ ] Monitor performance in production
- [ ] Add analytics/tracking if needed

---

## 🎯 Summary

The search system integrates seamlessly with FOSSAPP's architecture:

✅ **Zero client-side exposure** - All RPC calls from server actions
✅ **Existing patterns** - Matches current code style
✅ **Input validation** - Comprehensive sanitization
✅ **Error handling** - Returns empty arrays, no throwing
✅ **TypeScript** - Full type safety
✅ **Tested** - All functionality verified with real data

**Next Step**: Copy `search-server-actions.ts` content into `src/lib/actions.ts` and start building the UI!
