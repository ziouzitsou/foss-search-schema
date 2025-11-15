# Search Schema Complete Implementation Guide

**Project**: Foss SA Luminaires Search System  
**Database**: Supabase (PostgreSQL)  
**Application**: Next.js 14+ with TypeScript  
**Date**: November 2025

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Schema Definition (SQL)](#schema-definition)
4. [Migration Strategy](#migration-strategy)
5. [Next.js Integration](#nextjs-integration)
6. [API Endpoints Design](#api-endpoints-design)
7. [Query Examples](#query-examples)
8. [Maintenance & Operations](#maintenance)

---

## Executive Summary

### Problem Statement
You have 14,889 lighting products with 1.38M technical features. Users need to find products through:
- Natural language queries ("outdoor wall lights")
- Technical specifications (IP65, 20W, warm white)
- Visual browsing (categories, faceted filters)

### Solution: Three-Tier Search Architecture

```
┌─────────────────────────────────────────────┐
│  1. GUIDED FINDER (Wizards)                 │
│     "I need outdoor lighting for a wall"    │
│     → Boolean flags + taxonomy navigation   │
└─────────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────┐
│  2. SMART TEXT SEARCH                       │
│     "waterproof 20W LED downlight"          │
│     → Full-text + ETIM feature matching     │
└─────────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────┐
│  3. TECHNICAL FILTERS (Professional)        │
│     Power: 15-25W, IP Rating: 65+           │
│     → Numeric ranges + alphanumeric filters │
└─────────────────────────────────────────────┘
```

### Key Benefits
- ✅ **Fast**: Boolean flags for instant filtering (no JSON parsing)
- ✅ **Accurate**: ETIM-based classification (standardized)
- ✅ **Flexible**: Works for both novices and pros
- ✅ **Maintainable**: Configuration-driven (no hardcoded rules)
- ✅ **Scalable**: Materialized views for performance

---

## Architecture Overview

### Schema Organization

```
┌─────────────────────────────────────────────┐
│  Database: Supabase                         │
├─────────────────────────────────────────────┤
│                                             │
│  📁 items (existing - source of truth)      │
│     └─ product_info (mat view)              │
│                                             │
│  📁 etim (existing - standards)             │
│     └─ ETIM reference tables                │
│                                             │
│  📁 search (NEW - discovery layer) ✨        │
│     ├─ taxonomy                             │
│     ├─ classification_rules                 │
│     ├─ filter_definitions                   │
│     ├─ product_taxonomy_flags (mat view)    │
│     ├─ product_filter_index (mat view)      │
│     └─ filter_facets (mat view)             │
│                                             │
└─────────────────────────────────────────────┘
```

### Data Flow

```
BMEcat Import → items.* → Materialized View Refresh → search.* → Web App
                   ↓                                      ↑
              ETIM Standards ────────────────────────────┘
```

---

## Schema Definition

### 1. search.taxonomy (Configuration Table)

**Purpose**: Hierarchical product taxonomy for navigation and guided finders.

```sql
CREATE TABLE search.taxonomy (
    id SERIAL PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,                    -- e.g., 'LUM_IND_CEIL_REC'
    parent_code TEXT REFERENCES search.taxonomy(code),
    level INTEGER NOT NULL,                       -- 0=root, 1=category, 2=subcategory
    name_el TEXT NOT NULL,                        -- Greek name
    name_en TEXT NOT NULL,                        -- English name
    description_el TEXT,
    description_en TEXT,
    icon TEXT,                                    -- Icon identifier
    display_order INTEGER DEFAULT 0,
    active BOOLEAN DEFAULT true,
    full_path TEXT[],                             -- Computed: ['LUM', 'IND', 'CEIL', 'REC']
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_taxonomy_code ON search.taxonomy(code);
CREATE INDEX idx_taxonomy_parent ON search.taxonomy(parent_code);
CREATE INDEX idx_taxonomy_active ON search.taxonomy(active) WHERE active = true;

COMMENT ON TABLE search.taxonomy IS 
'Hierarchical product taxonomy for navigation. Maps business-friendly categories 
to technical ETIM classifications via classification_rules.';
```

**Example Data**:
```sql
-- Root
('LUM', NULL, 0, 'Φωτιστικά', 'Luminaires', ...)

-- Level 1
('LUM_IND', 'LUM', 1, 'Εσωτερικού χώρου', 'Indoor', ...)
('LUM_OUT', 'LUM', 1, 'Εξωτερικού χώρου', 'Outdoor', ...)

-- Level 2
('LUM_IND_CEIL', 'LUM_IND', 2, 'Οροφής', 'Ceiling', ...)
('LUM_IND_WALL', 'LUM_IND', 2, 'Τοίχου', 'Wall', ...)
('LUM_IND_PEND', 'LUM_IND', 2, 'Κρεμαστά', 'Pendant', ...)

-- Level 3
('LUM_IND_CEIL_REC', 'LUM_IND_CEIL', 3, 'Χωνευτά', 'Recessed', ...)
('LUM_IND_CEIL_SURF', 'LUM_IND_CEIL', 3, 'Επιφανείας', 'Surface-mounted', ...)
```

---

### 2. search.classification_rules (Configuration Table)

**Purpose**: Defines logic for automatically classifying products into taxonomy and setting boolean flags.

```sql
CREATE TABLE search.classification_rules (
    id SERIAL PRIMARY KEY,
    rule_name TEXT UNIQUE NOT NULL,
    description TEXT,
    taxonomy_code TEXT REFERENCES search.taxonomy(code),
    flag_name TEXT,                               -- e.g., 'indoor', 'recessed', 'dimmable'
    priority INTEGER DEFAULT 100,                 -- Lower = higher priority
    
    -- Rule conditions (ONE of these must be specified)
    etim_group_ids TEXT[],                        -- Match ETIM groups
    etim_class_ids TEXT[],                        -- Match ETIM classes
    etim_feature_conditions JSONB,                -- Feature-based rules
    text_pattern TEXT,                            -- Regex pattern for descriptions
    
    -- Metadata
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_classification_rules_active ON search.classification_rules(active) WHERE active = true;
CREATE INDEX idx_classification_rules_taxonomy ON search.classification_rules(taxonomy_code);

COMMENT ON TABLE search.classification_rules IS 
'Configuration-driven rules for product classification. Applied by 
search.apply_classification_rules() function to populate product_taxonomy_flags.';
```

**Example Rules**:
```sql
-- Indoor/Outdoor detection
{
  "rule_name": "indoor_luminaires",
  "flag_name": "indoor",
  "etim_group_ids": ["EC000037"],  -- Luminaires for indoor use
  "priority": 10
}

-- Recessed detection
{
  "rule_name": "recessed_luminaires",
  "flag_name": "recessed",
  "taxonomy_code": "LUM_IND_CEIL_REC",
  "etim_feature_conditions": {
    "EF000123": {"operator": "equals", "value": "EV001234"}  -- Mounting type = Recessed
  },
  "priority": 20
}

-- Dimmable detection
{
  "rule_name": "dimmable_products",
  "flag_name": "dimmable",
  "etim_feature_conditions": {
    "EF000456": {"operator": "equals", "value": true}  -- Dimmable = true
  },
  "priority": 30
}
```

---

### 3. search.filter_definitions (Configuration Table)

**Purpose**: Defines available filters for faceted search UI.

```sql
CREATE TABLE search.filter_definitions (
    id SERIAL PRIMARY KEY,
    filter_key TEXT UNIQUE NOT NULL,              -- e.g., 'power', 'ip_rating', 'color_temp'
    filter_type TEXT NOT NULL,                    -- 'numeric_range', 'alphanumeric', 'boolean'
    
    -- Display names
    label_el TEXT NOT NULL,
    label_en TEXT NOT NULL,
    
    -- ETIM mapping
    etim_feature_id TEXT NOT NULL,                -- References etim.feature
    etim_unit_id TEXT,                            -- For numeric filters
    
    -- UI configuration
    display_order INTEGER DEFAULT 0,
    ui_component TEXT,                            -- 'slider', 'checkbox', 'dropdown', 'multiselect'
    ui_config JSONB,                              -- Component-specific config
    
    -- Taxonomy restrictions (optional)
    applicable_taxonomy_codes TEXT[],             -- Show only for these categories
    
    -- Metadata
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_filter_definitions_active ON search.filter_definitions(active) WHERE active = true;
CREATE INDEX idx_filter_definitions_feature ON search.filter_definitions(etim_feature_id);

COMMENT ON TABLE search.filter_definitions IS 
'Defines available filters for faceted search. Controls UI rendering and 
maps to ETIM features via product_filter_index materialized view.';
```

**Example Filters**:
```sql
-- Power filter
{
  "filter_key": "power",
  "filter_type": "numeric_range",
  "label_el": "Ισχύς",
  "label_en": "Power",
  "etim_feature_id": "EF000001",
  "etim_unit_id": "EU570001",
  "ui_component": "slider",
  "ui_config": {
    "min": 0,
    "max": 300,
    "step": 5,
    "unit": "W"
  }
}

-- IP Rating filter
{
  "filter_key": "ip_rating",
  "filter_type": "alphanumeric",
  "label_el": "Βαθμός προστασίας IP",
  "label_en": "IP Rating",
  "etim_feature_id": "EF000123",
  "ui_component": "multiselect",
  "ui_config": {
    "options": ["IP20", "IP44", "IP54", "IP65", "IP67"]
  }
}

-- Dimmable filter
{
  "filter_key": "dimmable",
  "filter_type": "boolean",
  "label_el": "Με δυνατότητα dimming",
  "label_en": "Dimmable",
  "etim_feature_id": "EF000456",
  "ui_component": "checkbox"
}
```

---

### 4. search.product_taxonomy_flags (Materialized View)

**Purpose**: Fast boolean flags for each product based on classification rules.

```sql
CREATE MATERIALIZED VIEW search.product_taxonomy_flags AS
WITH product_classifications AS (
    -- Apply all active classification rules
    SELECT DISTINCT
        pi.product_id,
        pi.foss_pid,
        cr.taxonomy_code,
        cr.flag_name
    FROM items.product_info pi
    CROSS JOIN search.classification_rules cr
    WHERE cr.active = true
      AND (
          -- Rule matches ETIM group
          (cr.etim_group_ids IS NOT NULL 
           AND pi.group = ANY(cr.etim_group_ids))
          
          -- Rule matches ETIM class
          OR (cr.etim_class_ids IS NOT NULL 
              AND pi.class = ANY(cr.etim_class_ids))
          
          -- Rule matches feature conditions
          OR (cr.etim_feature_conditions IS NOT NULL 
              AND EXISTS (
                  SELECT 1 
                  FROM jsonb_array_elements(pi.features) f
                  WHERE search.evaluate_feature_condition(f, cr.etim_feature_conditions)
              ))
          
          -- Rule matches text pattern
          OR (cr.text_pattern IS NOT NULL 
              AND (pi.description_short ~* cr.text_pattern 
                   OR pi.description_long ~* cr.text_pattern))
      )
)
SELECT 
    product_id,
    foss_pid,
    
    -- Taxonomy path (array of codes from root to leaf)
    array_agg(DISTINCT taxonomy_code) 
        FILTER (WHERE taxonomy_code IS NOT NULL) AS taxonomy_path,
    
    -- Boolean flags (pivoted)
    bool_or(flag_name = 'indoor') AS indoor,
    bool_or(flag_name = 'outdoor') AS outdoor,
    bool_or(flag_name = 'ceiling') AS ceiling,
    bool_or(flag_name = 'wall') AS wall,
    bool_or(flag_name = 'pendant') AS pendant,
    bool_or(flag_name = 'floor') AS floor,
    bool_or(flag_name = 'recessed') AS recessed,
    bool_or(flag_name = 'surface_mounted') AS surface_mounted,
    bool_or(flag_name = 'suspended') AS suspended,
    bool_or(flag_name = 'track') AS track,
    bool_or(flag_name = 'dimmable') AS dimmable,
    bool_or(flag_name = 'smart_control') AS smart_control,
    bool_or(flag_name = 'emergency') AS emergency,
    bool_or(flag_name = 'decorative') AS decorative
    
FROM product_classifications
GROUP BY product_id, foss_pid;

-- Indexes for fast filtering
CREATE UNIQUE INDEX idx_product_taxonomy_flags_product 
    ON search.product_taxonomy_flags(product_id);
CREATE INDEX idx_product_taxonomy_flags_indoor 
    ON search.product_taxonomy_flags(indoor) WHERE indoor = true;
CREATE INDEX idx_product_taxonomy_flags_outdoor 
    ON search.product_taxonomy_flags(outdoor) WHERE outdoor = true;
CREATE INDEX idx_product_taxonomy_flags_recessed 
    ON search.product_taxonomy_flags(recessed) WHERE recessed = true;
CREATE INDEX idx_product_taxonomy_flags_dimmable 
    ON search.product_taxonomy_flags(dimmable) WHERE dimmable = true;

COMMENT ON MATERIALIZED VIEW search.product_taxonomy_flags IS 
'Fast boolean flags for product classification. Refreshed after catalog imports 
or rule changes. Enables instant filtering without JSON parsing.';
```

---

### 5. search.product_filter_index (Materialized View)

**Purpose**: Flattened index of all filterable features for fast faceted search.

```sql
CREATE MATERIALIZED VIEW search.product_filter_index AS
SELECT DISTINCT
    pi.product_id,
    pi.foss_pid,
    fd.filter_key,
    fd.filter_type,
    
    -- Extract values based on filter type
    CASE 
        WHEN fd.filter_type = 'numeric_range' THEN 
            (f->>'fvalueN')::NUMERIC
        ELSE NULL 
    END AS numeric_value,
    
    CASE 
        WHEN fd.filter_type = 'alphanumeric' THEN 
            f->>'fvalueC_desc'
        ELSE NULL 
    END AS alphanumeric_value,
    
    CASE 
        WHEN fd.filter_type = 'boolean' THEN 
            (f->>'fvalueB')::BOOLEAN
        ELSE NULL 
    END AS boolean_value,
    
    -- Include unit for numeric values
    f->>'unit_abbrev' AS unit

FROM items.product_info pi
CROSS JOIN LATERAL jsonb_array_elements(pi.features) f
INNER JOIN search.filter_definitions fd 
    ON fd.etim_feature_id = f->>'FEATUREID'
    AND fd.active = true
WHERE 
    -- Exclude NULL values
    (fd.filter_type = 'numeric_range' AND f->>'fvalueN' IS NOT NULL)
    OR (fd.filter_type = 'alphanumeric' AND f->>'fvalueC_desc' IS NOT NULL)
    OR (fd.filter_type = 'boolean' AND (f->>'fvalueB')::BOOLEAN = true);

-- Indexes for each filter type
CREATE INDEX idx_product_filter_index_product 
    ON search.product_filter_index(product_id);
CREATE INDEX idx_product_filter_index_key 
    ON search.product_filter_index(filter_key);
CREATE INDEX idx_product_filter_index_numeric 
    ON search.product_filter_index(filter_key, numeric_value) 
    WHERE numeric_value IS NOT NULL;
CREATE INDEX idx_product_filter_index_alphanumeric 
    ON search.product_filter_index(filter_key, alphanumeric_value) 
    WHERE alphanumeric_value IS NOT NULL;
CREATE INDEX idx_product_filter_index_boolean 
    ON search.product_filter_index(filter_key, boolean_value) 
    WHERE boolean_value = true;

COMMENT ON MATERIALIZED VIEW search.product_filter_index IS 
'Flattened index of all filterable features. Enables fast faceted search 
without JSON parsing. One row per product-filter combination.';
```

---

### 6. search.filter_facets (Materialized View)

**Purpose**: Aggregated facet counts for dynamic filter UI.

```sql
CREATE MATERIALIZED VIEW search.filter_facets AS
SELECT 
    filter_key,
    filter_type,
    
    -- For numeric filters: min, max, histogram
    CASE WHEN filter_type = 'numeric_range' THEN
        jsonb_build_object(
            'min', MIN(numeric_value),
            'max', MAX(numeric_value),
            'avg', AVG(numeric_value),
            'count', COUNT(*),
            'histogram', search.build_histogram(array_agg(numeric_value), 10)
        )
    ELSE NULL END AS numeric_stats,
    
    -- For alphanumeric filters: value counts
    CASE WHEN filter_type = 'alphanumeric' THEN
        jsonb_object_agg(
            alphanumeric_value, 
            value_count
        )
    ELSE NULL END AS alphanumeric_counts,
    
    -- For boolean filters: true count
    CASE WHEN filter_type = 'boolean' THEN
        COUNT(*) FILTER (WHERE boolean_value = true)
    ELSE NULL END AS boolean_true_count

FROM (
    SELECT 
        filter_key,
        filter_type,
        numeric_value,
        alphanumeric_value,
        boolean_value,
        COUNT(*) as value_count
    FROM search.product_filter_index
    GROUP BY filter_key, filter_type, numeric_value, alphanumeric_value, boolean_value
) subquery
GROUP BY filter_key, filter_type;

CREATE UNIQUE INDEX idx_filter_facets_key ON search.filter_facets(filter_key);

COMMENT ON MATERIALIZED VIEW search.filter_facets IS 
'Aggregated facet counts and statistics for filter UI. Shows available 
filter options and product counts before user applies filters.';
```

---

### 7. Helper Functions

#### search.evaluate_feature_condition()

```sql
CREATE OR REPLACE FUNCTION search.evaluate_feature_condition(
    feature JSONB,
    condition JSONB
) RETURNS BOOLEAN AS $$
DECLARE
    feature_id TEXT;
    operator TEXT;
    expected_value TEXT;
BEGIN
    -- Extract feature ID from condition keys
    feature_id := (SELECT jsonb_object_keys(condition) LIMIT 1);
    
    -- Check if feature matches
    IF (feature->>'FEATUREID') != feature_id THEN
        RETURN false;
    END IF;
    
    -- Get operator and value
    operator := condition->feature_id->>'operator';
    expected_value := condition->feature_id->>'value';
    
    -- Evaluate based on operator
    CASE operator
        WHEN 'equals' THEN
            RETURN (feature->>'fvalueC' = expected_value 
                    OR (feature->>'fvalueB')::TEXT = expected_value);
        WHEN 'contains' THEN
            RETURN (feature->>'fvalueC_desc' ILIKE '%' || expected_value || '%');
        WHEN 'greater_than' THEN
            RETURN (feature->>'fvalueN')::NUMERIC > expected_value::NUMERIC;
        WHEN 'less_than' THEN
            RETURN (feature->>'fvalueN')::NUMERIC < expected_value::NUMERIC;
        WHEN 'in_range' THEN
            RETURN (feature->>'fvalueN')::NUMERIC BETWEEN 
                (condition->feature_id->>'min')::NUMERIC AND 
                (condition->feature_id->>'max')::NUMERIC;
        ELSE
            RETURN false;
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

#### search.build_histogram()

```sql
CREATE OR REPLACE FUNCTION search.build_histogram(
    values NUMERIC[],
    bucket_count INTEGER DEFAULT 10
) RETURNS JSONB AS $$
DECLARE
    min_val NUMERIC;
    max_val NUMERIC;
    bucket_width NUMERIC;
    histogram JSONB := '[]'::JSONB;
    bucket_start NUMERIC;
    bucket_end NUMERIC;
    bucket_label TEXT;
    count INTEGER;
BEGIN
    -- Get min and max
    min_val := (SELECT MIN(v) FROM unnest(values) v);
    max_val := (SELECT MAX(v) FROM unnest(values) v);
    
    -- Calculate bucket width
    bucket_width := (max_val - min_val) / bucket_count;
    
    -- Build histogram
    FOR i IN 0..(bucket_count - 1) LOOP
        bucket_start := min_val + (i * bucket_width);
        bucket_end := bucket_start + bucket_width;
        bucket_label := bucket_start::TEXT || '-' || bucket_end::TEXT;
        
        SELECT COUNT(*) INTO count
        FROM unnest(values) v
        WHERE v >= bucket_start AND v < bucket_end;
        
        histogram := histogram || jsonb_build_object(
            'range', bucket_label,
            'min', bucket_start,
            'max', bucket_end,
            'count', count
        );
    END LOOP;
    
    RETURN histogram;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

---

## Migration Strategy

### Phase 1: Schema Creation (Week 1)

```sql
-- Step 1: Create schema
CREATE SCHEMA IF NOT EXISTS search;

-- Step 2: Create tables (run each CREATE TABLE statement above)

-- Step 3: Create helper functions

-- Step 4: Verify structure
\dt search.*
```

### Phase 2: Data Population (Week 1-2)

```sql
-- Step 1: Populate taxonomy from existing categories
INSERT INTO search.taxonomy (code, parent_code, level, name_el, name_en, ...)
SELECT ...
FROM items.categories
WHERE ...;

-- Step 2: Create classification rules
-- (Manual configuration based on your domain knowledge)

-- Step 3: Create filter definitions
INSERT INTO search.filter_definitions (filter_key, etim_feature_id, ...)
VALUES 
    ('power', 'EF000001', ...),
    ('ip_rating', 'EF000123', ...),
    ...;
```

### Phase 3: Materialized Views (Week 2)

```sql
-- Create all materialized views
-- (Run CREATE MATERIALIZED VIEW statements above)

-- Initial refresh
REFRESH MATERIALIZED VIEW CONCURRENTLY search.product_taxonomy_flags;
REFRESH MATERIALIZED VIEW CONCURRENTLY search.product_filter_index;
REFRESH MATERIALIZED VIEW CONCURRENTLY search.filter_facets;
```

### Phase 4: Testing & Validation (Week 2-3)

```sql
-- Test queries
SELECT * FROM search.product_taxonomy_flags LIMIT 10;
SELECT * FROM search.product_filter_index WHERE filter_key = 'power' LIMIT 10;
SELECT * FROM search.filter_facets;

-- Validate counts
SELECT 
    COUNT(*) as total_products,
    COUNT(*) FILTER (WHERE indoor = true) as indoor_count,
    COUNT(*) FILTER (WHERE outdoor = true) as outdoor_count
FROM search.product_taxonomy_flags;
```

### Phase 5: Application Integration (Week 3-4)

See Next.js Integration section below.

---

## Next.js Integration

### Project Structure

```
your-nextjs-app/
├── app/
│   ├── api/
│   │   ├── search/
│   │   │   ├── route.ts              # Main search endpoint
│   │   │   ├── facets/route.ts       # Get filter facets
│   │   │   └── suggest/route.ts      # Autocomplete
│   │   └── products/
│   │       └── [id]/route.ts         # Product detail
│   ├── search/
│   │   └── page.tsx                  # Search results page
│   └── products/
│       └── [id]/page.tsx             # Product detail page
├── lib/
│   ├── supabase.ts                   # Supabase client
│   ├── search/
│   │   ├── types.ts                  # TypeScript types
│   │   ├── queries.ts                # SQL query builders
│   │   └── utils.ts                  # Helper functions
│   └── filters/
│       ├── FilterManager.ts          # Filter state management
│       └── FilterComponents.tsx      # UI components
└── components/
    ├── SearchBar.tsx
    ├── FilterPanel.tsx
    ├── ProductCard.tsx
    └── ProductGrid.tsx
```

### TypeScript Types

```typescript
// lib/search/types.ts

export interface SearchFilters {
  // Text search
  query?: string;
  
  // Taxonomy flags
  indoor?: boolean;
  outdoor?: boolean;
  ceiling?: boolean;
  wall?: boolean;
  recessed?: boolean;
  dimmable?: boolean;
  
  // Taxonomy path
  taxonomy_path?: string[];
  
  // Numeric filters
  power?: { min?: number; max?: number };
  luminous_flux?: { min?: number; max?: number };
  
  // Alphanumeric filters
  ip_rating?: string[];
  color_temperature?: string[];
  beam_angle?: string[];
  
  // Pagination
  page?: number;
  per_page?: number;
}

export interface SearchResult {
  product_id: string;
  foss_pid: string;
  description_short: string;
  description_long?: string;
  supplier_name: string;
  class_name: string;
  price?: number;
  image_url?: string;
  taxonomy_path: string[];
  flags: {
    indoor?: boolean;
    outdoor?: boolean;
    dimmable?: boolean;
    // ... other flags
  };
}

export interface SearchResponse {
  results: SearchResult[];
  total_count: number;
  page: number;
  per_page: number;
  facets: FilterFacets;
}

export interface FilterFacets {
  [filterKey: string]: {
    type: 'numeric_range' | 'alphanumeric' | 'boolean';
    numeric_stats?: {
      min: number;
      max: number;
      avg: number;
      count: number;
    };
    alphanumeric_counts?: { [value: string]: number };
    boolean_true_count?: number;
  };
}
```

### Supabase Client Setup

```typescript
// lib/supabase.ts

import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Type-safe query builder
export async function queryProducts(filters: SearchFilters) {
  let query = supabase
    .from('product_info')
    .select('*, product_taxonomy_flags(*)', { count: 'exact' });
  
  // Apply filters
  if (filters.query) {
    query = query.textSearch('description_short', filters.query);
  }
  
  if (filters.indoor !== undefined) {
    query = query.eq('product_taxonomy_flags.indoor', filters.indoor);
  }
  
  // ... more filter conditions
  
  return query;
}
```

### API Route: Main Search

```typescript
// app/api/search/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { supabase } from '@/lib/supabase';
import { SearchFilters, SearchResponse } from '@/lib/search/types';

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  
  // Parse filters from query params
  const filters: SearchFilters = {
    query: searchParams.get('q') || undefined,
    indoor: searchParams.get('indoor') === 'true',
    outdoor: searchParams.get('outdoor') === 'true',
    recessed: searchParams.get('recessed') === 'true',
    page: parseInt(searchParams.get('page') || '1'),
    per_page: parseInt(searchParams.get('per_page') || '24'),
  };
  
  // Build query
  const { from, to } = getPagination(filters.page!, filters.per_page!);
  
  let query = supabase
    .rpc('search_products', {
      p_query: filters.query,
      p_indoor: filters.indoor,
      p_outdoor: filters.outdoor,
      p_recessed: filters.recessed,
      p_limit: filters.per_page,
      p_offset: from
    });
  
  const { data, error, count } = await query;
  
  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
  
  // Get facets
  const facetsQuery = await supabase
    .from('filter_facets')
    .select('*');
  
  const response: SearchResponse = {
    results: data || [],
    total_count: count || 0,
    page: filters.page!,
    per_page: filters.per_page!,
    facets: facetsQuery.data || {}
  };
  
  return NextResponse.json(response);
}

function getPagination(page: number, perPage: number) {
  const from = (page - 1) * perPage;
  const to = from + perPage - 1;
  return { from, to };
}
```

### Search Function (PostgreSQL)

```sql
-- Create a search function for better performance
CREATE OR REPLACE FUNCTION search_products(
    p_query TEXT DEFAULT NULL,
    p_indoor BOOLEAN DEFAULT NULL,
    p_outdoor BOOLEAN DEFAULT NULL,
    p_recessed BOOLEAN DEFAULT NULL,
    p_power_min NUMERIC DEFAULT NULL,
    p_power_max NUMERIC DEFAULT NULL,
    p_limit INTEGER DEFAULT 24,
    p_offset INTEGER DEFAULT 0
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
    flags JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pi.product_id,
        pi.foss_pid,
        pi.description_short,
        pi.description_long,
        pi.supplier_name,
        pi.class_name,
        (pi.prices->0->>'start_price')::NUMERIC as price,
        (pi.multimedia->0->>'mime_source') as image_url,
        ptf.taxonomy_path,
        jsonb_build_object(
            'indoor', ptf.indoor,
            'outdoor', ptf.outdoor,
            'recessed', ptf.recessed,
            'dimmable', ptf.dimmable
        ) as flags
    FROM items.product_info pi
    JOIN search.product_taxonomy_flags ptf ON pi.product_id = ptf.product_id
    WHERE 
        -- Text search
        (p_query IS NULL OR 
         pi.description_short ILIKE '%' || p_query || '%' OR
         pi.description_long ILIKE '%' || p_query || '%')
        
        -- Boolean flags
        AND (p_indoor IS NULL OR ptf.indoor = p_indoor)
        AND (p_outdoor IS NULL OR ptf.outdoor = p_outdoor)
        AND (p_recessed IS NULL OR ptf.recessed = p_recessed)
        
        -- Numeric filters
        AND (p_power_min IS NULL OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'power'
              AND pfi.numeric_value >= p_power_min
        ))
        AND (p_power_max IS NULL OR EXISTS (
            SELECT 1 FROM search.product_filter_index pfi
            WHERE pfi.product_id = pi.product_id
              AND pfi.filter_key = 'power'
              AND pfi.numeric_value <= p_power_max
        ))
    
    ORDER BY 
        -- Relevance scoring (text match > exact match)
        CASE 
            WHEN p_query IS NOT NULL AND pi.description_short ILIKE p_query THEN 1
            WHEN p_query IS NOT NULL AND pi.description_short ILIKE '%' || p_query || '%' THEN 2
            ELSE 3
        END,
        pi.foss_pid
    
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql STABLE;
```

### React Component: Search Page

```typescript
// app/search/page.tsx

'use client';

import { useState, useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import SearchBar from '@/components/SearchBar';
import FilterPanel from '@/components/FilterPanel';
import ProductGrid from '@/components/ProductGrid';
import { SearchFilters, SearchResponse } from '@/lib/search/types';

export default function SearchPage() {
  const searchParams = useSearchParams();
  const [results, setResults] = useState<SearchResponse | null>(null);
  const [loading, setLoading] = useState(true);
  
  const [filters, setFilters] = useState<SearchFilters>({
    query: searchParams.get('q') || '',
    indoor: searchParams.get('indoor') === 'true',
    outdoor: searchParams.get('outdoor') === 'true',
    page: 1,
    per_page: 24
  });
  
  useEffect(() => {
    fetchResults();
  }, [filters]);
  
  async function fetchResults() {
    setLoading(true);
    
    // Build query string
    const params = new URLSearchParams();
    if (filters.query) params.set('q', filters.query);
    if (filters.indoor) params.set('indoor', 'true');
    if (filters.outdoor) params.set('outdoor', 'true');
    params.set('page', filters.page!.toString());
    
    const response = await fetch(`/api/search?${params}`);
    const data: SearchResponse = await response.json();
    
    setResults(data);
    setLoading(false);
  }
  
  return (
    <div className="container mx-auto px-4 py-8">
      <SearchBar 
        initialQuery={filters.query} 
        onSearch={(q) => setFilters({ ...filters, query: q, page: 1 })}
      />
      
      <div className="grid grid-cols-12 gap-6 mt-8">
        <aside className="col-span-3">
          <FilterPanel 
            filters={filters}
            facets={results?.facets}
            onChange={(newFilters) => setFilters({ ...filters, ...newFilters, page: 1 })}
          />
        </aside>
        
        <main className="col-span-9">
          {loading ? (
            <div>Loading...</div>
          ) : (
            <>
              <div className="mb-4 text-gray-600">
                {results?.total_count} products found
              </div>
              
              <ProductGrid products={results?.results || []} />
              
              {/* Pagination */}
              <div className="mt-8 flex justify-center">
                {/* Pagination component */}
              </div>
            </>
          )}
        </main>
      </div>
    </div>
  );
}
```

---

## Query Examples

### Example 1: Simple Boolean Filter

```sql
-- Find all indoor recessed ceiling luminaires
SELECT 
    pi.foss_pid,
    pi.description_short,
    pi.supplier_name,
    (pi.prices->0->>'start_price')::NUMERIC as price
FROM items.product_info pi
JOIN search.product_taxonomy_flags ptf ON pi.product_id = ptf.product_id
WHERE ptf.indoor = true
  AND ptf.ceiling = true
  AND ptf.recessed = true
LIMIT 50;
```

### Example 2: Text + Boolean Filters

```sql
-- Find dimmable outdoor wall lights
SELECT 
    pi.foss_pid,
    pi.description_short,
    (pi.multimedia->0->>'mime_source') as image_url
FROM items.product_info pi
JOIN search.product_taxonomy_flags ptf ON pi.product_id = ptf.product_id
WHERE (pi.description_short ILIKE '%LED%' OR pi.description_long ILIKE '%LED%')
  AND ptf.outdoor = true
  AND ptf.wall = true
  AND ptf.dimmable = true;
```

### Example 3: Numeric Range Filter

```sql
-- Find products with power between 15-25W
SELECT 
    pi.foss_pid,
    pi.description_short,
    pfi.numeric_value as power_w
FROM items.product_info pi
JOIN search.product_filter_index pfi ON pi.product_id = pfi.product_id
WHERE pfi.filter_key = 'power'
  AND pfi.numeric_value BETWEEN 15 AND 25
ORDER BY pfi.numeric_value;
```

### Example 4: Alphanumeric Filter

```sql
-- Find products with IP65 or IP67 rating
SELECT DISTINCT
    pi.foss_pid,
    pi.description_short,
    pfi.alphanumeric_value as ip_rating
FROM items.product_info pi
JOIN search.product_filter_index pfi ON pi.product_id = pfi.product_id
WHERE pfi.filter_key = 'ip_rating'
  AND pfi.alphanumeric_value IN ('IP65', 'IP67');
```

### Example 5: Combined Multi-Filter Search

```sql
-- Professional query: Indoor, recessed, 20W, dimmable, warm white
SELECT 
    pi.foss_pid,
    pi.description_short,
    pi.supplier_name,
    (pi.prices->0->>'start_price')::NUMERIC as price,
    power.numeric_value as power_w,
    color.alphanumeric_value as color_temp
FROM items.product_info pi
JOIN search.product_taxonomy_flags ptf ON pi.product_id = ptf.product_id
LEFT JOIN search.product_filter_index power 
    ON power.product_id = pi.product_id 
    AND power.filter_key = 'power'
LEFT JOIN search.product_filter_index color 
    ON color.product_id = pi.product_id 
    AND color.filter_key = 'color_temperature'
WHERE ptf.indoor = true
  AND ptf.recessed = true
  AND ptf.dimmable = true
  AND power.numeric_value BETWEEN 18 AND 22
  AND color.alphanumeric_value ILIKE '%warm%'
LIMIT 50;
```

### Example 6: Facet Counts (for UI)

```sql
-- Get available filter options with counts
SELECT 
    fd.filter_key,
    fd.label_en,
    fd.filter_type,
    ff.numeric_stats,
    ff.alphanumeric_counts
FROM search.filter_definitions fd
LEFT JOIN search.filter_facets ff ON ff.filter_key = fd.filter_key
WHERE fd.active = true
ORDER BY fd.display_order;
```

---

## Maintenance & Operations

### Daily Operations

```sql
-- After catalog import, refresh materialized views
REFRESH MATERIALIZED VIEW CONCURRENTLY search.product_taxonomy_flags;
REFRESH MATERIALIZED VIEW CONCURRENTLY search.product_filter_index;
REFRESH MATERIALIZED VIEW CONCURRENTLY search.filter_facets;
```

### Monitoring Queries

```sql
-- Check materialized view freshness
SELECT 
    schemaname,
    matviewname,
    last_refresh_time
FROM pg_matviews
WHERE schemaname = 'search';

-- Count products by taxonomy
SELECT 
    bool_or(indoor) as has_indoor,
    bool_or(outdoor) as has_outdoor,
    COUNT(*) as product_count
FROM search.product_taxonomy_flags
GROUP BY ROLLUP(indoor, outdoor);

-- Check filter coverage
SELECT 
    fd.filter_key,
    COUNT(DISTINCT pfi.product_id) as products_with_filter
FROM search.filter_definitions fd
LEFT JOIN search.product_filter_index pfi ON pfi.filter_key = fd.filter_key
WHERE fd.active = true
GROUP BY fd.filter_key
ORDER BY products_with_filter DESC;
```

### Performance Tuning

```sql
-- Add GIN index for full-text search (optional)
CREATE INDEX idx_product_info_fulltext 
    ON items.product_info 
    USING gin(to_tsvector('greek', description_short || ' ' || description_long));

-- Analyze tables for query planner
ANALYZE search.product_taxonomy_flags;
ANALYZE search.product_filter_index;
ANALYZE search.filter_facets;
```

---

## Next Steps

### Week 1: Foundation
1. ✅ Review this documentation
2. ✅ Create `search` schema
3. ✅ Create configuration tables
4. ✅ Populate initial taxonomy

### Week 2: Data Pipeline
1. ✅ Create classification rules
2. ✅ Create filter definitions
3. ✅ Build materialized views
4. ✅ Test with sample queries

### Week 3: Application Layer
1. ✅ Set up Next.js API routes
2. ✅ Build search components
3. ✅ Implement filter UI
4. ✅ Add pagination

### Week 4: Polish & Deploy
1. ✅ Performance optimization
2. ✅ Mobile responsiveness
3. ✅ Greek/English i18n
4. ✅ Docker deployment

---

## Success Metrics

After implementation, you should achieve:

- **Search Speed**: < 200ms for most queries
- **Filter Response**: Instant (boolean flags)
- **Facet Loading**: < 100ms (from materialized view)
- **Accuracy**: 95%+ relevant results
- **Coverage**: 100% of products classified

---

## Support & Resources

- **ETIM Documentation**: https://www.etim-international.com/
- **Supabase Docs**: https://supabase.com/docs
- **Next.js 14 Docs**: https://nextjs.org/docs
- **PostgreSQL Performance**: https://www.postgresql.org/docs/current/performance-tips.html

---

**End of Documentation**

This is your complete implementation guide. You now have:
✅ Schema design
✅ SQL definitions
✅ Migration strategy
✅ Next.js integration
✅ Query examples
✅ Maintenance procedures

Ready to build! 🚀
