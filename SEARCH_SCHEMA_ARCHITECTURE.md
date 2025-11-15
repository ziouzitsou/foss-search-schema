# Search Schema Architecture Documentation

**Purpose**: Complete reference for integrating the search system into FOSSAPP
**Last Updated**: 2025-01-15
**Database**: Supabase PostgreSQL (Foss SA Luminaires)
**Products Indexed**: 14,889 lighting products

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Schema Structure](#schema-structure)
3. [Function Reference](#function-reference)
4. [Integration Guide](#integration-guide)
5. [Maintenance Operations](#maintenance-operations)
6. [Performance Expectations](#performance-expectations)
7. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### Design Philosophy

The search system follows a **two-tier architecture** to maintain clean separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIENT APPLICATION                      │
│                    (FOSSAPP Next.js)                        │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ├─── supabase.rpc('search_products', {...})
                              ├─── supabase.rpc('count_search_products', {...})
                              ├─── supabase.rpc('get_taxonomy_tree')
                              ├─── supabase.rpc('get_search_statistics')
                              └─── supabase.rpc('get_available_facets')
                              │
┌─────────────────────────────▼───────────────────────────────┐
│                   PUBLIC SCHEMA (Wrappers)                  │
│  ┌──────────────────────────────────────────────────┐       │
│  │ Thin wrapper functions                           │       │
│  │ - SECURITY DEFINER (bypass RLS)                  │       │
│  │ - Minimal logic (just call search.* functions)   │       │
│  │ - Parameter translation only                     │       │
│  └────────────────────┬─────────────────────────────┘       │
└─────────────────────────┼───────────────────────────────────┘
                          │
                          │ Calls search.* functions
                          │
┌─────────────────────────▼───────────────────────────────────┐
│              SEARCH SCHEMA (Business Logic)                 │
│  ┌──────────────────────────────────────────────────┐       │
│  │ Configuration Tables:                            │       │
│  │ - taxonomy (hierarchical categories)             │       │
│  │ - classification_rules (ETIM → human mapping)    │       │
│  │ - filter_definitions (available filters)         │       │
│  └──────────────────────────────────────────────────┘       │
│                                                              │
│  ┌──────────────────────────────────────────────────┐       │
│  │ Materialized Views:                              │       │
│  │ - product_taxonomy_flags (boolean flags)         │       │
│  │ - product_filter_index (flattened features)      │       │
│  │ - filter_facets (aggregated filter stats)        │       │
│  └──────────────────────────────────────────────────┘       │
│                                                              │
│  ┌──────────────────────────────────────────────────┐       │
│  │ Functions (All business logic):                  │       │
│  │ - search_products() - Main search               │       │
│  │ - count_search_products() - Count results       │       │
│  │ - get_taxonomy_tree() - Category tree           │       │
│  │ - get_search_statistics() - System stats        │       │
│  │ - get_available_facets() - Filter metadata      │       │
│  └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ Reads from
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                   ITEMS SCHEMA (Source Data)                │
│  - product_info (14,889 products)                           │
│  - product_features_mv (1.38M ETIM features)                │
│  - catalog, prices, multimedia, etc.                        │
└─────────────────────────────────────────────────────────────┘
```

### Key Principles

1. **Isolation**: Search logic isolated in `search` schema - never modifies `items` schema
2. **Performance**: Materialized views for sub-200ms query times
3. **Maintainability**: All business logic in `search` schema functions with inline comments
4. **Flexibility**: Configuration-driven taxonomy and filters (no hardcoded logic)
5. **Security**: Public wrappers use SECURITY DEFINER to bypass RLS for authenticated users

---

## Schema Structure

### Configuration Tables

#### `search.taxonomy`
Hierarchical product categories (human-friendly structure).

```sql
-- Example data
code                      | parent_code | level | name              | product_count
--------------------------|-------------|-------|-------------------|---------------
ROOT                      | NULL        | 0     | Products          | 0
LUMINAIRE                 | ROOT        | 1     | Luminaires        | 13,336
LUMINAIRE-INDOOR-CEILING  | LUMINAIRE   | 2     | Ceiling           | 7,361
LUMINAIRE-INDOOR-WALL     | LUMINAIRE   | 2     | Wall              | 7,446
```

**Purpose**: Maps ETIM technical taxonomy to user-friendly categories.

**Columns**:
- `code`: Unique identifier (e.g., "LUMINAIRE-INDOOR-CEILING")
- `parent_code`: Parent category for hierarchical navigation
- `level`: Depth in hierarchy (0=root, 1=main, 2=subcategory)
- `name`: Human-readable label for UI
- `display_order`: Sort order within level
- `icon`: Optional icon identifier
- `active`: Enable/disable category

---

#### `search.classification_rules`
Rules that map ETIM codes to taxonomy categories.

```sql
-- Example: Ceiling luminaires
rule_name         | taxonomy_code           | etim_class_ids       | priority | active
------------------|-------------------------|----------------------|----------|-------
ceiling_luminaires| LUMINAIRE-INDOOR-CEILING| {EC001744,EC002892} | 30       | true
```

**Purpose**: Bridge between ETIM technical classification and human categories.

**Columns**:
- `rule_name`: Descriptive name for the rule
- `taxonomy_code`: Target taxonomy category
- `flag_name`: Boolean flag to set (e.g., "ceiling", "indoor")
- `etim_group_ids`: Array of ETIM group codes (e.g., ["EG000027"])
- `etim_class_ids`: Array of ETIM class codes (e.g., ["EC001744"])
- `text_pattern`: Regex pattern for description matching
- `priority`: Lower = higher priority (applied first)
- `active`: Enable/disable rule

**Classification Methods**:
1. **ETIM-based**: Match by group/class IDs (reliable, structural)
2. **Text-based**: Match by description patterns (functional characteristics)

---

#### `search.filter_definitions`
Configuration for available filters in UI.

```sql
-- Example: Power filter
filter_key | filter_type   | label        | etim_feature_id | ui_component
-----------|---------------|--------------|-----------------|-------------
power      | numeric_range | Power (W)    | EF009471        | range_slider
ip_rating  | alphanumeric  | IP Rating    | EF000102        | checkbox_list
```

**Purpose**: Define which ETIM features become searchable filters.

**Columns**:
- `filter_key`: Unique identifier (used in API calls)
- `filter_type`: "numeric_range" | "alphanumeric" | "boolean"
- `label`: Human-readable label for UI
- `etim_feature_id`: ETIM feature code to extract
- `etim_unit_id`: Unit for numeric values (optional)
- `display_order`: Sort order in UI
- `ui_component`: Suggested UI component
- `ui_config`: JSONB config for UI (min/max, step, etc.)
- `applicable_taxonomy_codes`: Which categories show this filter
- `active`: Enable/disable filter

---

### Materialized Views

#### `search.product_taxonomy_flags`
**Size**: 4.0 MB (14,889 rows)
**Refresh Time**: ~2-3 seconds

Boolean flags for instant filtering (no JSON parsing).

```sql
SELECT
    product_id,
    taxonomy_path,              -- Array of taxonomy codes
    indoor,                     -- Boolean flags
    outdoor,
    submersible,
    trimless,
    cut_shape_round,
    cut_shape_rectangular,
    ceiling,
    wall,
    floor,
    recessed,
    surface_mounted,
    suspended,
    decorative_pendant,
    track_system
FROM search.product_taxonomy_flags
LIMIT 3;

-- Example result:
product_id                            | taxonomy_path                                  | indoor | outdoor | ceiling | trimless
--------------------------------------|------------------------------------------------|--------|---------|---------|----------
a1b2c3d4-... | {LUMINAIRE,LUMINAIRE-INDOOR-CEILING}           | true   | false   | true    | true
e5f6g7h8-... | {LUMINAIRE,LUMINAIRE-OUTDOOR-WALL}             | false  | true    | false   | false
```

**Performance**: Instant (<10ms) - indexed boolean columns, no JSON parsing.

---

#### `search.product_filter_index`
**Size**: 56 KB
**Refresh Time**: ~3-5 seconds

Flattened index of product features for filtering.

```sql
SELECT
    product_id,
    filter_key,
    filter_type,
    numeric_value,
    alphanumeric_value,
    boolean_value,
    unit_symbol
FROM search.product_filter_index
WHERE filter_key = 'power'
LIMIT 3;

-- Example result:
product_id   | filter_key | filter_type   | numeric_value | alphanumeric_value | unit_symbol
-------------|------------|---------------|---------------|--------------------|--------------
a1b2c3d4-... | power      | numeric_range | 10.5          | NULL               | W
e5f6g7h8-... | power      | numeric_range | 25.0          | NULL               | W
i9j0k1l2-... | ip_rating  | alphanumeric  | NULL          | IP65               | NULL
```

**Performance**: Fast (<50ms) for range queries with proper indexes.

---

#### `search.filter_facets`
**Size**: 16 KB
**Refresh Time**: ~1 second

Aggregated statistics for filter UI (min/max, counts, histograms).

```sql
SELECT * FROM search.filter_facets WHERE filter_key = 'power';

-- Example result:
filter_key | filter_type   | numeric_stats                                    | total_products
-----------|---------------|--------------------------------------------------|----------------
power      | numeric_range | {"min": 3.5, "max": 250, "avg": 18.2, ...}      | 12,450
```

**Purpose**: Pre-computed statistics for filter UI (no real-time aggregation needed).

---

## Function Reference

All functions in `search` schema have extensive inline comments. Public wrappers are minimal.

### Core Search Functions

#### `search.search_products()`

**Purpose**: Main search function with full filtering and pagination.

**Signature** (latest version with cut shape flags):
```sql
search.search_products(
    p_query                text DEFAULT NULL,           -- Text search query
    p_indoor               boolean DEFAULT NULL,        -- Location filters
    p_outdoor              boolean DEFAULT NULL,
    p_submersible          boolean DEFAULT NULL,
    p_trimless             boolean DEFAULT NULL,        -- Design filters
    p_cut_shape_round      boolean DEFAULT NULL,
    p_cut_shape_rectangular boolean DEFAULT NULL,
    p_ceiling              boolean DEFAULT NULL,        -- Mounting filters
    p_wall                 boolean DEFAULT NULL,
    p_pendant              boolean DEFAULT NULL,
    p_recessed             boolean DEFAULT NULL,
    p_dimmable             boolean DEFAULT NULL,        -- Feature filters
    p_power_min            numeric DEFAULT NULL,        -- Numeric range filters
    p_power_max            numeric DEFAULT NULL,
    p_color_temp_min       numeric DEFAULT NULL,
    p_color_temp_max       numeric DEFAULT NULL,
    p_ip_ratings           text[] DEFAULT NULL,         -- Alphanumeric filters
    p_suppliers            text[] DEFAULT NULL,         -- Supplier filter
    p_taxonomy_codes       text[] DEFAULT NULL,         -- Category filter (array!)
    p_sort_by              text DEFAULT 'relevance',    -- Sort: relevance/price_asc/price_desc
    p_limit                integer DEFAULT 24,          -- Pagination
    p_offset               integer DEFAULT 0
) RETURNS TABLE (...)
```

**Returns**:
```sql
product_id       uuid
foss_pid         text
description_short text
description_long  text
supplier_name     text
class_name        text
price             numeric
image_url         text
taxonomy_path     text[]     -- Categories this product belongs to
flags             jsonb      -- Boolean flags: {indoor, outdoor, ceiling, ...}
key_features      jsonb      -- Extracted features: {power, color_temp, ip_rating}
relevance_score   integer    -- Relevance ranking (lower = better)
```

**Client Usage** (Supabase JS):
```typescript
const { data, error } = await supabase.rpc('search_products', {
  p_query: 'LED ceiling',
  p_taxonomy_codes: ['LUMINAIRE-INDOOR-CEILING'],
  p_indoor: true,
  p_trimless: true,
  p_power_min: 10,
  p_power_max: 50,
  p_limit: 24,
  p_offset: 0
});
```

**Performance**: <200ms for typical queries (with warm cache: <100ms).

---

#### `search.count_search_products()`

**Purpose**: Count matching products (for pagination UI).

**Signature** (matches search_products parameters):
```sql
search.count_search_products(
    -- Same parameters as search_products (except p_sort_by, p_limit, p_offset)
    ...
) RETURNS bigint
```

**Client Usage**:
```typescript
const { data: count, error } = await supabase.rpc('count_search_products', {
  p_query: 'LED ceiling',
  p_indoor: true,
  p_trimless: true
});

// Returns: 3657 (bigint)
```

**Performance**: <100ms (same filters as search, but COUNT only).

---

### Helper Functions

#### `search.get_taxonomy_tree()`

**Purpose**: Returns complete taxonomy hierarchy with product counts.

**Signature**:
```sql
search.get_taxonomy_tree()
RETURNS TABLE (
    code          text,      -- Taxonomy code (e.g., "LUMINAIRE-INDOOR-CEILING")
    parent_code   text,      -- Parent code (NULL for root)
    level         integer,   -- Hierarchy depth (0, 1, 2, ...)
    name          text,      -- Human-readable name
    product_count bigint,    -- Number of products in this category
    icon          text       -- Icon identifier (optional)
)
```

**Client Usage**:
```typescript
const { data: tree, error } = await supabase.rpc('get_taxonomy_tree');

// Returns:
// [
//   { code: "ROOT", parent_code: null, level: 0, name: "Products", product_count: 0 },
//   { code: "LUMINAIRE", parent_code: "ROOT", level: 1, name: "Luminaires", product_count: 13336 },
//   { code: "LUMINAIRE-INDOOR-CEILING", parent_code: "LUMINAIRE", level: 2, name: "Ceiling", product_count: 7361 },
//   ...
// ]
```

**Performance**: <50ms (reads from taxonomy table + aggregates from product_taxonomy_flags).

**UI Use Case**: Build hierarchical category navigation.

---

#### `search.get_search_statistics()`

**Purpose**: System-wide statistics for dashboard/monitoring.

**Signature**:
```sql
search.get_search_statistics()
RETURNS TABLE (
    stat_name  text,      -- Statistic name
    stat_value bigint     -- Statistic value
)
```

**Client Usage**:
```typescript
const { data: stats, error } = await supabase.rpc('get_search_statistics');

// Returns:
// [
//   { stat_name: "total_products", stat_value: 14889 },
//   { stat_name: "indoor_products", stat_value: 10402 },
//   { stat_name: "outdoor_products", stat_value: 2593 },
//   { stat_name: "dimmable_products", stat_value: 11287 },
//   { stat_name: "filter_entries", stat_value: 125000 },
//   { stat_name: "taxonomy_nodes", stat_value: 48 }
// ]
```

**Performance**: <100ms (aggregates from materialized views).

**UI Use Case**: Dashboard stats panel, health monitoring.

---

#### `search.get_available_facets()`

**Purpose**: Returns filter metadata with current statistics (for filter UI).

**Signature**:
```sql
search.get_available_facets()
RETURNS TABLE (
    filter_key  text,      -- Filter identifier (e.g., "power", "ip_rating")
    filter_type text,      -- "numeric_range" | "alphanumeric" | "boolean"
    label       text,      -- Human-readable label
    facet_data  jsonb      -- Type-specific statistics
)
```

**Client Usage**:
```typescript
const { data: facets, error } = await supabase.rpc('get_available_facets');

// Returns:
// [
//   {
//     filter_key: "power",
//     filter_type: "numeric_range",
//     label: "Power (W)",
//     facet_data: {
//       min: 3.5,
//       max: 250,
//       avg: 18.2,
//       count: 12450,
//       histogram: [
//         { range: "3.5-28.2", min: 3.5, max: 28.2, count: 3200 },
//         { range: "28.2-52.9", min: 28.2, max: 52.9, count: 4100 },
//         ...
//       ]
//     }
//   },
//   {
//     filter_key: "ip_rating",
//     filter_type: "alphanumeric",
//     label: "IP Rating",
//     facet_data: {
//       "IP20": 5600,
//       "IP44": 3200,
//       "IP65": 2100,
//       "IP67": 450
//     }
//   }
// ]
```

**Performance**: <50ms (reads from filter_definitions + filter_facets materialized view).

**UI Use Case**: Build dynamic filter UI with current value distributions.

---

### Utility Functions

#### `search.build_histogram()`

**Purpose**: Creates histogram buckets from numeric array (used by filter_facets view).

**Signature**:
```sql
search.build_histogram(
    value_array   numeric[],
    bucket_count  integer DEFAULT 10
) RETURNS jsonb
```

**Example**:
```sql
SELECT search.build_histogram(ARRAY[10, 15, 20, 25, 30, 35, 40, 45, 50], 5);

-- Returns:
-- [
--   { "range": "10-18", "min": 10, "max": 18, "count": 2 },
--   { "range": "18-26", "min": 18, "max": 26, "count": 2 },
--   { "range": "26-34", "min": 26, "max": 34, "count": 2 },
--   { "range": "34-42", "min": 34, "max": 42, "count": 2 },
--   { "range": "42-50", "min": 42, "max": 50, "count": 1 }
-- ]
```

**Use Case**: Generate histogram data for filter UI (e.g., power distribution chart).

---

#### `search.evaluate_feature_condition()`

**Purpose**: Evaluate ETIM feature conditions for classification rules.

**Signature**:
```sql
search.evaluate_feature_condition(
    feature   jsonb,
    condition jsonb
) RETURNS boolean
```

**Use Case**: Internal function used by classification system (not typically called directly).

---

## Integration Guide

### Step 1: Verify Database Connection

```typescript
// lib/supabase.ts
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

### Step 2: Create Type Definitions

```typescript
// types/search.ts

export interface SearchFilters {
  query?: string
  taxonomyCodes?: string[]
  suppliers?: string[]
  indoor?: boolean
  outdoor?: boolean
  submersible?: boolean
  trimless?: boolean
  cutShapeRound?: boolean
  cutShapeRectangular?: boolean
  ceiling?: boolean
  wall?: boolean
  pendant?: boolean
  recessed?: boolean
  dimmable?: boolean
  powerMin?: number
  powerMax?: number
  colorTempMin?: number
  colorTempMax?: number
  ipRatings?: string[]
  sortBy?: 'relevance' | 'price_asc' | 'price_desc'
  limit?: number
  offset?: number
}

export interface SearchProduct {
  product_id: string
  foss_pid: string
  description_short: string
  description_long: string
  supplier_name: string
  class_name: string
  price: number
  image_url: string
  taxonomy_path: string[]
  flags: {
    indoor: boolean
    outdoor: boolean
    submersible: boolean
    trimless: boolean
    cut_shape_round: boolean
    cut_shape_rectangular: boolean
    ceiling: boolean
    wall: boolean
    floor: boolean
    recessed: boolean
    surface_mounted: boolean
    suspended: boolean
  }
  key_features: {
    power: number | null
    color_temp: number | null
    ip_rating: string | null
  }
  relevance_score: number
}

export interface TaxonomyNode {
  code: string
  parent_code: string | null
  level: number
  name: string
  product_count: number
  icon: string | null
}

export interface SearchStatistic {
  stat_name: string
  stat_value: number
}

export interface FilterFacet {
  filter_key: string
  filter_type: 'numeric_range' | 'alphanumeric' | 'boolean'
  label: string
  facet_data: any // Type varies by filter_type
}
```

### Step 3: Create Search Service

```typescript
// services/searchService.ts
import { supabase } from '@/lib/supabase'
import type { SearchFilters, SearchProduct, TaxonomyNode, SearchStatistic, FilterFacet } from '@/types/search'

export class SearchService {
  /**
   * Search products with filters
   */
  static async searchProducts(filters: SearchFilters): Promise<SearchProduct[]> {
    const { data, error } = await supabase.rpc('search_products', {
      p_query: filters.query || null,
      p_taxonomy_codes: filters.taxonomyCodes || null,
      p_suppliers: filters.suppliers || null,
      p_indoor: filters.indoor ?? null,
      p_outdoor: filters.outdoor ?? null,
      p_submersible: filters.submersible ?? null,
      p_trimless: filters.trimless ?? null,
      p_cut_shape_round: filters.cutShapeRound ?? null,
      p_cut_shape_rectangular: filters.cutShapeRectangular ?? null,
      p_ceiling: filters.ceiling ?? null,
      p_wall: filters.wall ?? null,
      p_pendant: filters.pendant ?? null,
      p_recessed: filters.recessed ?? null,
      p_dimmable: filters.dimmable ?? null,
      p_power_min: filters.powerMin ?? null,
      p_power_max: filters.powerMax ?? null,
      p_color_temp_min: filters.colorTempMin ?? null,
      p_color_temp_max: filters.colorTempMax ?? null,
      p_ip_ratings: filters.ipRatings || null,
      p_sort_by: filters.sortBy || 'relevance',
      p_limit: filters.limit || 24,
      p_offset: filters.offset || 0
    })

    if (error) throw error
    return data as SearchProduct[]
  }

  /**
   * Count matching products
   */
  static async countProducts(filters: Omit<SearchFilters, 'sortBy' | 'limit' | 'offset'>): Promise<number> {
    const { data, error } = await supabase.rpc('count_search_products', {
      p_query: filters.query || null,
      p_taxonomy_codes: filters.taxonomyCodes || null,
      p_suppliers: filters.suppliers || null,
      p_indoor: filters.indoor ?? null,
      p_outdoor: filters.outdoor ?? null,
      p_submersible: filters.submersible ?? null,
      p_trimless: filters.trimless ?? null,
      p_cut_shape_round: filters.cutShapeRound ?? null,
      p_cut_shape_rectangular: filters.cutShapeRectangular ?? null,
      p_ceiling: filters.ceiling ?? null,
      p_wall: filters.wall ?? null,
      p_pendant: filters.pendant ?? null,
      p_recessed: filters.recessed ?? null,
      p_dimmable: filters.dimmable ?? null,
      p_power_min: filters.powerMin ?? null,
      p_power_max: filters.powerMax ?? null,
      p_color_temp_min: filters.colorTempMin ?? null,
      p_color_temp_max: filters.colorTempMax ?? null,
      p_ip_ratings: filters.ipRatings || null
    })

    if (error) throw error
    return data as number
  }

  /**
   * Get taxonomy tree for navigation
   */
  static async getTaxonomyTree(): Promise<TaxonomyNode[]> {
    const { data, error } = await supabase.rpc('get_taxonomy_tree')
    if (error) throw error
    return data as TaxonomyNode[]
  }

  /**
   * Get system statistics
   */
  static async getStatistics(): Promise<SearchStatistic[]> {
    const { data, error } = await supabase.rpc('get_search_statistics')
    if (error) throw error
    return data as SearchStatistic[]
  }

  /**
   * Get available filter facets
   */
  static async getAvailableFacets(): Promise<FilterFacet[]> {
    const { data, error } = await supabase.rpc('get_available_facets')
    if (error) throw error
    return data as FilterFacet[]
  }
}
```

### Step 4: Create Search Page Component

```typescript
// app/search/page.tsx
'use client'

import { useState, useEffect } from 'react'
import { SearchService } from '@/services/searchService'
import type { SearchProduct, TaxonomyNode } from '@/types/search'

export default function SearchPage() {
  const [products, setProducts] = useState<SearchProduct[]>([])
  const [totalCount, setTotalCount] = useState(0)
  const [taxonomy, setTaxonomy] = useState<TaxonomyNode[]>([])
  const [filters, setFilters] = useState({
    query: '',
    taxonomyCodes: [] as string[],
    indoor: undefined,
    outdoor: undefined,
    limit: 24,
    offset: 0
  })

  // Load taxonomy on mount
  useEffect(() => {
    SearchService.getTaxonomyTree().then(setTaxonomy)
  }, [])

  // Search when filters change
  useEffect(() => {
    const search = async () => {
      const [products, count] = await Promise.all([
        SearchService.searchProducts(filters),
        SearchService.countProducts(filters)
      ])
      setProducts(products)
      setTotalCount(count)
    }
    search()
  }, [filters])

  return (
    <div className="search-page">
      {/* Search bar */}
      <input
        type="text"
        value={filters.query}
        onChange={(e) => setFilters({ ...filters, query: e.target.value })}
        placeholder="Search products..."
      />

      {/* Category filters */}
      <div className="taxonomy-filters">
        {taxonomy.filter(t => t.level === 1).map(category => (
          <button
            key={category.code}
            onClick={() => setFilters({
              ...filters,
              taxonomyCodes: [category.code]
            })}
          >
            {category.name} ({category.product_count})
          </button>
        ))}
      </div>

      {/* Boolean filters */}
      <div className="boolean-filters">
        <label>
          <input
            type="checkbox"
            checked={filters.indoor ?? false}
            onChange={(e) => setFilters({
              ...filters,
              indoor: e.target.checked || undefined
            })}
          />
          Indoor
        </label>
        <label>
          <input
            type="checkbox"
            checked={filters.outdoor ?? false}
            onChange={(e) => setFilters({
              ...filters,
              outdoor: e.target.checked || undefined
            })}
          />
          Outdoor
        </label>
      </div>

      {/* Results */}
      <div className="results">
        <h2>Results ({totalCount})</h2>
        <div className="product-grid">
          {products.map(product => (
            <div key={product.product_id} className="product-card">
              <h3>{product.description_short}</h3>
              <p>{product.supplier_name}</p>
              <p>€{product.price}</p>
              <div className="flags">
                {product.flags.indoor && <span>🏠 Indoor</span>}
                {product.flags.outdoor && <span>🌳 Outdoor</span>}
                {product.flags.trimless && <span>✂️ Trimless</span>}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
```

---

## Maintenance Operations

### Daily: Refresh Materialized Views (After Catalog Import)

After importing new BMEcat catalogs, refresh all materialized views in sequence:

```sql
-- 1. Existing views (already in your workflow, ~14 seconds total)
REFRESH MATERIALIZED VIEW items.product_info;                    -- 5.2s
REFRESH MATERIALIZED VIEW CONCURRENTLY items.product_features_mv; -- 7.6s
REFRESH MATERIALIZED VIEW CONCURRENTLY items.product_categories_mv;
REFRESH MATERIALIZED VIEW items.gcfv_mapping;
REFRESH MATERIALIZED VIEW items.product_feature_group_mapping;

-- 2. Search schema views (~6-9 seconds)
REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;         -- 2-3s
REFRESH MATERIALIZED VIEW search.product_filter_index;           -- 3-5s
REFRESH MATERIALIZED VIEW search.filter_facets;                  -- 1s

-- 3. Update statistics (recommended for query planner)
ANALYZE search.product_taxonomy_flags;
ANALYZE search.product_filter_index;
ANALYZE search.filter_facets;
```

**Total refresh time**: ~20-23 seconds (was ~14 seconds before search schema).

**Automation** (create migration):
```sql
CREATE OR REPLACE FUNCTION search.refresh_all_views()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE NOTICE 'Refreshing search schema materialized views...';

    REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;
    RAISE NOTICE '  ✓ product_taxonomy_flags refreshed';

    REFRESH MATERIALIZED VIEW search.product_filter_index;
    RAISE NOTICE '  ✓ product_filter_index refreshed';

    REFRESH MATERIALIZED VIEW search.filter_facets;
    RAISE NOTICE '  ✓ filter_facets refreshed';

    ANALYZE search.product_taxonomy_flags;
    ANALYZE search.product_filter_index;
    ANALYZE search.filter_facets;

    RAISE NOTICE 'Search schema views refreshed and analyzed successfully!';
END;
$$;

-- Usage:
SELECT search.refresh_all_views();
```

---

### Weekly: Review Classification Rules

Check if products are correctly classified:

```sql
-- Products without any taxonomy classification
SELECT
    pi.foss_pid,
    pi.description_short,
    pi."group",
    pi.class
FROM items.product_info pi
LEFT JOIN search.product_taxonomy_flags ptf ON pi.product_id = ptf.product_id
WHERE ptf.taxonomy_path IS NULL OR ptf.taxonomy_path = '{}';

-- Products in unexpected categories (manual review)
SELECT
    pi.foss_pid,
    pi.description_short,
    ptf.taxonomy_path
FROM items.product_info pi
JOIN search.product_taxonomy_flags ptf ON pi.product_id = ptf.product_id
WHERE ptf.taxonomy_path && ARRAY['UNEXPECTED_CATEGORY'];
```

---

### Monthly: Verify Filter Definitions

Ensure filter definitions match actual ETIM features in database:

```sql
-- Check if configured ETIM feature IDs actually exist
SELECT
    fd.filter_key,
    fd.etim_feature_id,
    f."FEATUREDESC" as feature_name,
    CASE
        WHEN f."FEATUREID" IS NULL THEN '❌ MISSING'
        ELSE '✓ OK'
    END as status
FROM search.filter_definitions fd
LEFT JOIN etim.feature f ON fd.etim_feature_id = f."FEATUREID"
WHERE fd.active = true
ORDER BY status DESC, fd.filter_key;
```

---

## Performance Expectations

Based on verified testing with 14,889 products:

| Operation | Expected Time | Notes |
|-----------|---------------|-------|
| **search_products()** | <200ms | First query (cold cache) |
| **search_products()** | <100ms | Subsequent queries (warm cache) |
| **count_search_products()** | <100ms | Same filters as search |
| **get_taxonomy_tree()** | <50ms | Reads from small table + aggregates |
| **get_search_statistics()** | <100ms | Aggregates from mat views |
| **get_available_facets()** | <50ms | Reads from mat views |
| **Materialized view refresh** | 6-9 seconds | All 3 search views |
| **Full refresh sequence** | 20-23 seconds | Including items.* views |

### Optimization Tips

1. **Use taxonomy filters early**: Narrow by category first, then apply other filters
2. **Avoid wildcard searches**: "LED%" faster than "%LED%"
3. **Cache taxonomy tree**: Changes rarely, safe to cache client-side
4. **Pagination**: Always use limit/offset, never load all results
5. **Refresh schedule**: Refresh mat views immediately after catalog imports

---

## Troubleshooting

### Problem: No products returned

**Symptoms**: `search_products()` returns empty array, but products exist.

**Causes & Solutions**:

1. **Materialized views not refreshed**
   ```sql
   -- Check if views are empty
   SELECT COUNT(*) FROM search.product_taxonomy_flags; -- Should be 14,889

   -- If zero, refresh views
   SELECT search.refresh_all_views();
   ```

2. **Classification rules don't match ETIM groups**
   ```sql
   -- Check actual ETIM groups in database
   SELECT DISTINCT "group", "group_name", COUNT(*)
   FROM items.product_info
   GROUP BY "group", "group_name"
   ORDER BY COUNT(*) DESC;

   -- Update classification_rules table with correct group IDs
   ```

3. **Taxonomy codes mismatch**
   ```sql
   -- Verify taxonomy codes exist
   SELECT code, name FROM search.taxonomy WHERE active = true;

   -- Check if products have taxonomy assignments
   SELECT taxonomy_path, COUNT(*)
   FROM search.product_taxonomy_flags
   GROUP BY taxonomy_path
   ORDER BY COUNT(*) DESC;
   ```

---

### Problem: Filters not working

**Symptoms**: Applying filters (power, IP rating, etc.) doesn't filter results.

**Causes & Solutions**:

1. **Filter definitions not configured**
   ```sql
   -- Check if filters are defined
   SELECT * FROM search.filter_definitions WHERE active = true;

   -- If empty, add filter definitions (see filter_definitions table schema)
   ```

2. **Wrong ETIM feature IDs**
   ```sql
   -- Find correct ETIM feature IDs
   SELECT "FEATUREID", "FEATUREDESC"
   FROM etim.feature
   WHERE "FEATUREDESC" ILIKE '%power%' OR "FEATUREDESC" ILIKE '%watt%';

   -- Update filter_definitions with correct IDs
   UPDATE search.filter_definitions
   SET etim_feature_id = 'EF009471'  -- Correct ID
   WHERE filter_key = 'power';

   -- Refresh filter_facets
   REFRESH MATERIALIZED VIEW search.filter_facets;
   ```

3. **product_filter_index empty**
   ```sql
   -- Check if filter index has data
   SELECT filter_key, COUNT(*)
   FROM search.product_filter_index
   GROUP BY filter_key;

   -- If empty, refresh view
   REFRESH MATERIALIZED VIEW search.product_filter_index;
   ```

---

### Problem: Slow queries

**Symptoms**: Queries taking >500ms.

**Causes & Solutions**:

1. **Missing indexes**
   ```sql
   -- Check if indexes exist on product_taxonomy_flags
   SELECT indexname, indexdef
   FROM pg_indexes
   WHERE schemaname = 'search'
     AND tablename = 'product_taxonomy_flags';

   -- Should see indexes on: product_id, indoor, outdoor, ceiling, etc.
   ```

2. **Materialized views not analyzed**
   ```sql
   -- Update query planner statistics
   ANALYZE search.product_taxonomy_flags;
   ANALYZE search.product_filter_index;
   ANALYZE search.filter_facets;
   ```

3. **Too many filters applied**
   - Use taxonomy filters first (most selective)
   - Avoid applying ALL filters at once
   - Consider implementing filter UI that applies filters incrementally

---

### Problem: Function not found

**Symptoms**: Error "function search.get_available_facets() does not exist"

**Solution**:
```sql
-- Check if function exists
SELECT routine_name, routine_schema
FROM information_schema.routines
WHERE routine_schema = 'search'
  AND routine_name = 'get_available_facets';

-- If missing, re-apply migration that creates the function
-- (See migration: create_get_available_facets_function)
```

---

### Problem: Public wrapper fails

**Symptoms**: Error when calling `supabase.rpc('search_products', {...})`

**Causes & Solutions**:

1. **Wrapper doesn't exist**
   ```sql
   -- Check if public wrapper exists
   SELECT routine_name
   FROM information_schema.routines
   WHERE routine_schema = 'public'
     AND routine_name = 'search_products';

   -- If missing, create wrapper (see Integration Guide)
   ```

2. **Permission issue (RLS)**
   - Public wrappers should use `SECURITY DEFINER`
   - Check if user is authenticated
   - Verify RLS policies on items.product_info

3. **Parameter mismatch**
   - Ensure client parameters match function signature
   - Check parameter names (must use `p_` prefix in RPC call)

---

## Migration History

All migrations applied (2025-01-15):

1. ✅ `create_get_available_facets_function` - Created missing `search.get_available_facets()`
2. ✅ `drop_deprecated_search_functions` - Removed old single-taxonomy functions from search schema
3. ✅ `drop_deprecated_public_count_products` - Removed old `public.count_products()` wrapper

**Clean slate**: All deprecated functions removed, only current versions remain.

---

## Summary

**What you have**:
- ✅ Clean, documented search architecture
- ✅ All functions in `search` schema with inline comments
- ✅ Minimal public wrappers (SECURITY DEFINER)
- ✅ 14,889 products indexed and searchable
- ✅ Sub-200ms query performance
- ✅ Configuration-driven (no hardcoded logic)

**What FOSSAPP needs to do**:
1. Copy TypeScript types from Integration Guide
2. Create `SearchService` class
3. Build search UI components (search bar, filters, results)
4. Add `SELECT search.refresh_all_views();` to catalog import workflow

**Reference this document** for all integration questions!

---

**Questions? Issues?**
- All function signatures documented above
- All functions have extensive inline comments (use `\df+ search.*` in psql)
- Test queries available in search-test-app repository

**Last tested**: 2025-01-15 with search-test-app (http://localhost:3001)
