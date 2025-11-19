# Filter Types Reference

**Purpose**: Complete reference for filter types, implementation patterns, and UI components
**Target Audience**: Developers implementing search filters
**Last Updated**: November 19, 2025

---

## Table of Contents

1. [Overview](#overview)
2. [Boolean Filters](#boolean-filters)
3. [Multi-Select Filters](#multi-select-filters)
4. [Range Filters](#range-filters)
5. [ETIM Type Mapping](#etim-type-mapping)
6. [UI Components](#ui-components)
7. [Database Schema](#database-schema)
8. [Implementation Patterns](#implementation-patterns)

---

## Overview

The Foss SA search system supports **three fundamental filter types**:

| Type | Use Case | ETIM Types | Examples |
|------|----------|------------|----------|
| **Boolean** | Yes/No/Either choices | L (Logical) | Dimmable, Indoor, Outdoor |
| **Multi-Select** | Choose one or more values | A (Alphanumeric) | IP Rating, Colors, Brands |
| **Range** | Numeric min/max values | N (Numeric), R (Range) | Power (W), CCT (K), Lumens (lm) |

All filter types support:
- ✅ Dynamic facets (counts update with context)
- ✅ Real-time search (debounced)
- ✅ Clear individual filter
- ✅ Clear all filters
- ✅ Responsive UI

---

## Boolean Filters

### What They Are

Boolean filters represent **true/false/either** choices. The third state (null/either) allows users to include products regardless of the flag value.

### ETIM Mapping

**ETIM Type**: L (Logical)

Examples from `etim.feature`:
- `EF000137` - Dimmable (L)
- `EF002101` - Emergency function (L)
- `EF000185` - Sensor included (L)

### UI Pattern: 3-State Toggle

**States**:
1. **Not selected** (null) - Show all products (default)
2. **Yes** (true) - Only products with flag = true
3. **No** (false) - Only products with flag = false

**Visual Design**:
```
┌──────────────────────────────────┐
│ Dimmable                         │
│ ○ Either  ○ Yes  ● No            │
└──────────────────────────────────┘
```

### Database Schema

**Filter Definition**:
```sql
INSERT INTO search.filter_definitions
(filter_key, label, category, etim_feature_id, value_type, sort_order, active)
VALUES
('dimmable', 'Dimmable', 'electricals', 'EF000137', 'boolean', 20, true);
```

**Filter Index** (product-level data):
```sql
-- Example rows in search.product_filter_index
product_id                           | filter_key | boolean_value
-------------------------------------|------------|---------------
123e4567-e89b-12d3-a456-426614174000 | dimmable   | true
123e4567-e89b-12d3-a456-426614174001 | dimmable   | false
123e4567-e89b-12d3-a456-426614174002 | dimmable   | null
```

### Search Query Pattern

**SQL** (in search function):
```sql
WHERE (p_dimmable IS NULL OR pfi.boolean_value = p_dimmable)
```

**TypeScript** (RPC call):
```typescript
const { data } = await supabase.rpc('search_products_with_filters', {
  p_dimmable: dimmableState,  // null | true | false
  // ... other params
})
```

### React Component

**Component**: `components/filters/BooleanFilter.tsx`

```typescript
interface BooleanFilterProps {
  label: string
  value: boolean | null
  onChange: (value: boolean | null) => void
  trueLabel?: string
  falseLabel?: string
  eitherLabel?: string
}

export default function BooleanFilter({
  label,
  value,
  onChange,
  trueLabel = 'Yes',
  falseLabel = 'No',
  eitherLabel = 'Either'
}: BooleanFilterProps) {
  return (
    <div className="space-y-2">
      <label className="text-sm font-medium">{label}</label>
      <div className="flex gap-2">
        <button
          onClick={() => onChange(null)}
          className={value === null ? 'selected' : ''}
        >
          {eitherLabel}
        </button>
        <button
          onClick={() => onChange(true)}
          className={value === true ? 'selected' : ''}
        >
          {trueLabel}
        </button>
        <button
          onClick={() => onChange(false)}
          className={value === false ? 'selected' : ''}
        >
          {falseLabel}
        </button>
      </div>
    </div>
  )
}
```

**Usage**:
```typescript
<BooleanFilter
  label="Dimmable"
  value={dimmable}
  onChange={setDimmable}
/>
```

### Examples

**Filter: Dimmable**
- ETIM: EF000137 (Logical)
- States: Either | Yes | No
- Products: 13,288 with dimmable data

**Filter: Emergency Function**
- ETIM: EF002101 (Logical)
- States: Either | Yes | No
- Use case: Emergency lighting products

**Filter: Sensor Included**
- ETIM: EF000185 (Logical)
- States: Either | Yes | No
- Use case: Motion sensor luminaires

---

## Multi-Select Filters

### What They Are

Multi-select filters allow users to **choose one or more values** from a list. Products matching ANY selected value are included (OR logic).

### ETIM Mapping

**ETIM Type**: A (Alphanumeric)

Examples from `etim.feature`:
- `EF002370` - IP rating (A) - Values: IP20, IP44, IP54, IP65, IP67
- `EF026472` - Finishing colour (A) - Values: White, Black, Silver, etc.
- `EF002066` - Colour temperature (A) - Values: 2700K, 3000K, 4000K, etc.

### UI Pattern: Checkbox List

**Visual Design**:
```
┌──────────────────────────────────┐
│ IP Rating                        │
│ ☑ IP20 (5,001)                   │
│ ☐ IP44 (484)                     │
│ ☐ IP54 (198)                     │
│ ☑ IP65 (1,277)                   │
│ ☐ IP67 (89)                      │
└──────────────────────────────────┘
```

**With Color Swatches** (for color filters):
```
┌──────────────────────────────────┐
│ Finishing Colour                 │
│ ☑ ⬜ White (3,245)               │
│ ☐ ⬛ Black (1,892)               │
│ ☐ ◻️  Silver (723)               │
│ ☐ 🟫 Bronze (456)                │
└──────────────────────────────────┘
```

### Database Schema

**Filter Definition**:
```sql
INSERT INTO search.filter_definitions
(filter_key, label, category, etim_feature_id, value_type, sort_order, active)
VALUES
('ip', 'IP Rating', 'design', 'EF002370', 'multi_select', 40, true);
```

**Filter Index** (product-level data):
```sql
-- Example rows in search.product_filter_index
product_id                           | filter_key | alphanumeric_value
-------------------------------------|------------|--------------------
123e4567-e89b-12d3-a456-426614174000 | ip         | IP65
123e4567-e89b-12d3-a456-426614174001 | ip         | IP20
123e4567-e89b-12d3-a456-426614174002 | ip         | IP44
```

**Dynamic Facets** (available options with counts):
```sql
-- From search.get_dynamic_facets()
filter_key | filter_value | product_count
-----------|--------------|---------------
ip         | IP20         | 5001
ip         | IP44         | 484
ip         | IP54         | 198
ip         | IP65         | 1277
ip         | IP67         | 89
```

### Search Query Pattern

**SQL** (in search function):
```sql
WHERE (
  p_filters IS NULL
  OR p_filters->>filter_key IS NULL
  OR pfi.alphanumeric_value = ANY(
    SELECT jsonb_array_elements_text(p_filters->filter_key)
  )
)
```

**TypeScript** (RPC call):
```typescript
const { data } = await supabase.rpc('search_products_with_filters', {
  p_filters: {
    ip: ['IP65', 'IP67'],           // OR logic: IP65 OR IP67
    finishing_colour: ['White', 'Black']  // AND with other filters
  },
  // ... other params
})
```

### React Component

**Component**: `components/filters/MultiSelectFilter.tsx`

```typescript
interface Option {
  value: string
  label: string
  count?: number
  colorHex?: string  // For color swatches
}

interface MultiSelectFilterProps {
  label: string
  options: Option[]
  selected: string[]
  onChange: (selected: string[]) => void
  showCounts?: boolean
  showColorSwatches?: boolean
}

export default function MultiSelectFilter({
  label,
  options,
  selected,
  onChange,
  showCounts = true,
  showColorSwatches = false
}: MultiSelectFilterProps) {
  const toggleOption = (value: string) => {
    if (selected.includes(value)) {
      onChange(selected.filter(v => v !== value))
    } else {
      onChange([...selected, value])
    }
  }

  return (
    <div className="space-y-2">
      <label className="text-sm font-medium">{label}</label>
      <div className="space-y-1">
        {options.map(option => (
          <label key={option.value} className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={selected.includes(option.value)}
              onChange={() => toggleOption(option.value)}
            />
            {showColorSwatches && option.colorHex && (
              <span
                className="w-4 h-4 rounded border"
                style={{ backgroundColor: option.colorHex }}
              />
            )}
            <span>{option.label}</span>
            {showCounts && option.count !== undefined && (
              <span className="text-gray-500">({option.count})</span>
            )}
          </label>
        ))}
      </div>
    </div>
  )
}
```

**Usage**:
```typescript
<MultiSelectFilter
  label="IP Rating"
  options={[
    { value: 'IP20', label: 'IP20', count: 5001 },
    { value: 'IP44', label: 'IP44', count: 484 },
    { value: 'IP65', label: 'IP65', count: 1277 }
  ]}
  selected={selectedIPRatings}
  onChange={setSelectedIPRatings}
  showCounts={true}
/>
```

### Examples

**Filter: IP Rating**
- ETIM: EF002370 (Alphanumeric)
- Values: IP20 (5,001), IP44 (484), IP54 (198), IP65 (1,277), IP67 (89)
- UI: Checkbox list with badges
- Logic: OR (products with ANY selected IP rating)

**Filter: Finishing Colour**
- ETIM: EF026472 (Alphanumeric)
- Values: White, Black, Silver, Bronze, Chrome, etc.
- UI: Checkbox list with color swatches
- Logic: OR (products with ANY selected color)

**Filter: LED Chip Brand**
- ETIM: EF027891 (Alphanumeric)
- Values: Cree, Lumileds, Nichia, Osram, Samsung
- UI: Checkbox list
- Logic: OR (products with ANY selected brand)

---

## Range Filters

### What They Are

Range filters allow users to specify **minimum and maximum numeric values**. Products within the range (inclusive) are included.

### ETIM Mapping

**ETIM Types**: N (Numeric), R (Range)

Examples from `etim.feature`:
- `EF026454` - Power (N) - Unit: W (watt)
- `EF009346` - Colour temperature (N) - Unit: K (kelvin)
- `EF001309` - Luminous flux (N) - Unit: lm (lumen)
- `EF002067` - Beam angle (N) - Unit: ° (degree)

### UI Pattern: Min/Max Inputs with Presets

**Visual Design**:
```
┌──────────────────────────────────┐
│ Power (W)                        │
│ Range: 0.5W - 300W               │
│                                  │
│ Min: [5    ] W                   │
│ Max: [50   ] W                   │
│                                  │
│ Presets:                         │
│ [0-10W] [10-25W] [25-50W] [50+]  │
└──────────────────────────────────┘
```

**For CCT** (Color Temperature):
```
┌──────────────────────────────────┐
│ CCT - Color Temperature          │
│ Range: 1800K - 6500K             │
│                                  │
│ Min: [2700] K                    │
│ Max: [3000] K                    │
│                                  │
│ Presets:                         │
│ [Warm 2700K] [Neutral 4000K]     │
│ [Cool 6500K] [Custom]            │
└──────────────────────────────────┘
```

### Database Schema

**Filter Definition**:
```sql
INSERT INTO search.filter_definitions
(filter_key, label, category, etim_feature_id, value_type, unit, sort_order, active)
VALUES
('power', 'Power', 'light_engine', 'EF026454', 'range', 'W', 50, true);
```

**Filter Index** (product-level data):
```sql
-- Example rows in search.product_filter_index
product_id                           | filter_key | numeric_value | unit
-------------------------------------|------------|---------------|------
123e4567-e89b-12d3-a456-426614174000 | power      | 12.5          | W
123e4567-e89b-12d3-a456-426614174001 | power      | 18.0          | W
123e4567-e89b-12d3-a456-426614174002 | power      | 25.3          | W
```

**Dynamic Facets** (min/max range):
```sql
-- From search.get_dynamic_facets()
filter_key | min_value | max_value | product_count
-----------|-----------|-----------|---------------
power      | 0.5       | 300.0     | 12453
cct        | 1800      | 6500      | 13510
lumens     | 40        | 41015     | 11234
```

### Search Query Pattern

**SQL** (in search function):
```sql
WHERE (
  (p_power_min IS NULL OR pfi.numeric_value >= p_power_min)
  AND
  (p_power_max IS NULL OR pfi.numeric_value <= p_power_max)
)
```

**TypeScript** (RPC call):
```typescript
const { data } = await supabase.rpc('search_products_with_filters', {
  p_filters: {
    power: { min: 5, max: 50 },
    cct: { min: 2700, max: 3000 },
    lumens: { min: 500, max: 2000 }
  },
  // ... other params
})
```

### React Component

**Component**: `components/filters/RangeFilter.tsx`

```typescript
interface Preset {
  label: string
  min: number
  max: number
}

interface RangeFilterProps {
  label: string
  unit?: string
  min: number | null
  max: number | null
  onChange: (min: number | null, max: number | null) => void
  absoluteMin?: number
  absoluteMax?: number
  presets?: Preset[]
}

export default function RangeFilter({
  label,
  unit = '',
  min,
  max,
  onChange,
  absoluteMin,
  absoluteMax,
  presets = []
}: RangeFilterProps) {
  const applyPreset = (preset: Preset) => {
    onChange(preset.min, preset.max)
  }

  return (
    <div className="space-y-3">
      <label className="text-sm font-medium">{label}</label>

      {absoluteMin !== undefined && absoluteMax !== undefined && (
        <div className="text-xs text-gray-500">
          Range: {absoluteMin}{unit} - {absoluteMax}{unit}
        </div>
      )}

      <div className="grid grid-cols-2 gap-2">
        <div>
          <label className="text-xs">Min</label>
          <input
            type="number"
            value={min ?? ''}
            onChange={(e) => onChange(
              e.target.value ? Number(e.target.value) : null,
              max
            )}
            placeholder={absoluteMin?.toString()}
            className="w-full px-2 py-1 border rounded"
          />
        </div>
        <div>
          <label className="text-xs">Max</label>
          <input
            type="number"
            value={max ?? ''}
            onChange={(e) => onChange(
              min,
              e.target.value ? Number(e.target.value) : null
            )}
            placeholder={absoluteMax?.toString()}
            className="w-full px-2 py-1 border rounded"
          />
        </div>
      </div>

      {presets.length > 0 && (
        <div className="flex flex-wrap gap-1">
          <span className="text-xs text-gray-500">Presets:</span>
          {presets.map(preset => (
            <button
              key={preset.label}
              onClick={() => applyPreset(preset)}
              className="text-xs px-2 py-1 border rounded hover:bg-gray-100"
            >
              {preset.label}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
```

**Usage**:
```typescript
<RangeFilter
  label="Power"
  unit="W"
  min={powerMin}
  max={powerMax}
  onChange={(min, max) => {
    setPowerMin(min)
    setPowerMax(max)
  }}
  absoluteMin={0.5}
  absoluteMax={300}
  presets={[
    { label: '0-10W', min: 0, max: 10 },
    { label: '10-25W', min: 10, max: 25 },
    { label: '25-50W', min: 25, max: 50 },
    { label: '50+', min: 50, max: 300 }
  ]}
/>
```

### Examples

**Filter: Power**
- ETIM: EF026454 (Numeric)
- Unit: W (watt)
- Range: 0.5W - 300W
- Products: 12,453
- Presets: 0-10W, 10-25W, 25-50W, 50+

**Filter: CCT (Color Temperature)**
- ETIM: EF009346 (Numeric)
- Unit: K (kelvin)
- Range: 1800K - 6500K
- Products: 13,510
- Presets: Warm (2700K), Neutral (4000K), Cool (6500K)

**Filter: Luminous Flux**
- ETIM: EF001309 (Numeric)
- Unit: lm (lumen)
- Range: 40lm - 41,015lm
- Products: 11,234
- Presets: 0-500lm, 500-1000lm, 1000-3000lm, 3000+lm

**Filter: Beam Angle**
- ETIM: EF002067 (Numeric)
- Unit: ° (degree)
- Range: 10° - 120°
- Products: 8,721
- Presets: Narrow (10-24°), Medium (25-60°), Wide (60+°)

---

## ETIM Type Mapping

### ETIM Feature Types

ETIM classifies technical features into 4 types:

| ETIM Type | Full Name | Filter Type | Description |
|-----------|-----------|-------------|-------------|
| **A** | Alphanumeric | Multi-Select | Text values, selections |
| **L** | Logical | Boolean | True/False flags |
| **N** | Numeric | Range | Numeric values |
| **R** | Range | Range | Min/max ranges |

### Mapping Rules

**Automatic Type Detection**:

1. **Check ETIM type** in `etim.feature`:
   - Type = 'L' → Boolean filter
   - Type = 'A' → Multi-select filter
   - Type = 'N' or 'R' → Range filter

2. **Override with `value_type`** in `search.filter_definitions`:
   ```sql
   SELECT filter_key, label, value_type, etim_feature_id
   FROM search.filter_definitions
   WHERE active = true;
   ```

3. **Store in `product_filter_index`**:
   - Boolean → `boolean_value` column
   - Multi-select → `alphanumeric_value` column
   - Range → `numeric_value` column + `unit` column

### ETIM to Filter Type Examples

```sql
-- Query to see ETIM type distribution
SELECT
    f."TYPE" as etim_type,
    CASE
        WHEN f."TYPE" = 'L' THEN 'Boolean'
        WHEN f."TYPE" = 'A' THEN 'Multi-Select'
        WHEN f."TYPE" IN ('N', 'R') THEN 'Range'
    END as filter_type,
    COUNT(*) as feature_count
FROM etim.feature f
GROUP BY f."TYPE"
ORDER BY feature_count DESC;
```

**Expected Results**:
```
etim_type | filter_type   | feature_count
----------|---------------|---------------
A         | Multi-Select  | 3,456
N         | Range         | 2,189
L         | Boolean       | 892
R         | Range         | 234
```

---

## UI Components

### Component Library Structure

```
components/filters/
├── types.ts              # TypeScript interfaces
├── BooleanFilter.tsx     # 3-state toggle
├── MultiSelectFilter.tsx # Checkbox list
└── RangeFilter.tsx       # Min/max inputs
```

### Shared TypeScript Interfaces

**File**: `components/filters/types.ts`

```typescript
// Base filter interface
export interface BaseFilter {
  filter_key: string
  label: string
  category: 'electricals' | 'design' | 'light_engine'
  value_type: 'boolean' | 'multi_select' | 'range'
  sort_order: number
}

// Filter state (what's currently selected)
export type FilterState = {
  [filterKey: string]: boolean | string[] | { min: number; max: number } | null
}

// Dynamic facet data (from get_dynamic_facets)
export interface FilterFacet {
  filter_key: string
  filter_value?: string        // For multi-select
  product_count: number
  min_value?: number           // For range
  max_value?: number           // For range
}

// Option for multi-select
export interface FilterOption {
  value: string
  label: string
  count?: number
  colorHex?: string
  icon?: React.ReactNode
}

// Preset for range
export interface RangePreset {
  label: string
  min: number
  max: number
}
```

### Filter Container Component

**Component**: `components/FilterPanel.tsx`

```typescript
interface FilterPanelProps {
  onFilterChange: (filters: FilterState) => void
  taxonomyCode?: string
  selectedTaxonomies?: string[]
  // ... context for dynamic facets
}

export default function FilterPanel({
  onFilterChange,
  taxonomyCode,
  selectedTaxonomies,
  // ... other context
}: FilterPanelProps) {
  const [filterFacets, setFilterFacets] = useState<FilterFacet[]>([])
  const [activeFilters, setActiveFilters] = useState<FilterState>({})

  // Load dynamic facets based on context
  useEffect(() => {
    loadFilters()
  }, [taxonomyCode, selectedTaxonomies, /* ... other context */])

  const loadFilters = async () => {
    const { data } = await supabase.rpc('get_dynamic_facets', {
      p_taxonomy_codes: selectedTaxonomies,
      // ... other context params
    })
    setFilterFacets(data || [])
  }

  const handleFilterChange = (filterKey: string, value: any) => {
    const newFilters = {
      ...activeFilters,
      [filterKey]: value
    }
    setActiveFilters(newFilters)
    onFilterChange(newFilters)
  }

  return (
    <div className="space-y-6">
      {/* Electricals Section */}
      <FilterSection title="Electricals">
        <BooleanFilter
          label="Dimmable"
          value={activeFilters.dimmable as boolean | null}
          onChange={(value) => handleFilterChange('dimmable', value)}
        />
        <MultiSelectFilter
          label="Voltage"
          options={getOptionsForFilter('voltage', filterFacets)}
          selected={activeFilters.voltage as string[] || []}
          onChange={(value) => handleFilterChange('voltage', value)}
        />
      </FilterSection>

      {/* Design Section */}
      <FilterSection title="Design">
        <MultiSelectFilter
          label="IP Rating"
          options={getOptionsForFilter('ip', filterFacets)}
          selected={activeFilters.ip as string[] || []}
          onChange={(value) => handleFilterChange('ip', value)}
          showCounts={true}
        />
      </FilterSection>

      {/* Light Engine Section */}
      <FilterSection title="Light Engine">
        <RangeFilter
          label="Power"
          unit="W"
          min={activeFilters.power?.min ?? null}
          max={activeFilters.power?.max ?? null}
          onChange={(min, max) => handleFilterChange('power', { min, max })}
          presets={POWER_PRESETS}
        />
      </FilterSection>
    </div>
  )
}
```

---

## Database Schema

### Complete Schema for All Filter Types

**Configuration Table** (defines available filters):
```sql
CREATE TABLE search.filter_definitions (
    filter_id SERIAL PRIMARY KEY,
    filter_key TEXT NOT NULL UNIQUE,
    label TEXT NOT NULL,
    label_el TEXT,
    category TEXT NOT NULL,  -- electricals, design, light_engine
    etim_feature_id TEXT,
    value_type TEXT NOT NULL,  -- boolean, multi_select, range
    unit TEXT,                 -- W, K, lm, etc. (for range filters)
    sort_order INTEGER DEFAULT 100,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Index Table** (product-level filter values):
```sql
CREATE TABLE search.product_filter_index (
    product_id UUID NOT NULL REFERENCES items.product_info(product_id),
    filter_key TEXT NOT NULL,
    alphanumeric_value TEXT,     -- For multi-select (IP20, White, etc.)
    numeric_value NUMERIC(10,2), -- For range (12.5W, 3000K, etc.)
    boolean_value BOOLEAN,       -- For boolean (true, false)
    unit TEXT,                   -- W, K, lm, etc.
    created_at TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY (product_id, filter_key, COALESCE(alphanumeric_value, '')),

    -- Indexes for fast filtering
    CREATE INDEX idx_pfi_filter_key_alpha
        ON search.product_filter_index(filter_key, alphanumeric_value);
    CREATE INDEX idx_pfi_filter_key_numeric
        ON search.product_filter_index(filter_key, numeric_value);
    CREATE INDEX idx_pfi_filter_key_boolean
        ON search.product_filter_index(filter_key, boolean_value);
);
```

### Populating Filter Index

**Materialized View** (auto-populated):
```sql
CREATE MATERIALIZED VIEW search.product_filter_index AS
SELECT
    pi.product_id,
    fd.filter_key,

    -- Alphanumeric values (for multi-select)
    CASE
        WHEN fd.value_type = 'multi_select' AND feat."TYPE" = 'A'
        THEN feat_val->>'ALPHANUMERIC'
        ELSE NULL
    END as alphanumeric_value,

    -- Numeric values (for range)
    CASE
        WHEN fd.value_type = 'range' AND feat."TYPE" IN ('N', 'R')
        THEN (feat_val->>'NUMERIC')::numeric
        ELSE NULL
    END as numeric_value,

    -- Boolean values (for boolean)
    CASE
        WHEN fd.value_type = 'boolean' AND feat."TYPE" = 'L'
        THEN (feat_val->>'LOGICAL')::boolean
        ELSE NULL
    END as boolean_value,

    feat_unit."UNITCODE" as unit

FROM items.product_info pi
CROSS JOIN search.filter_definitions fd
JOIN jsonb_array_elements(pi.features) feat
    ON feat->>'FEATUREID' = fd.etim_feature_id
LEFT JOIN etim.unit feat_unit
    ON feat_unit."UNITCODE" = feat->>'UNITCODE'

WHERE fd.active = true;

-- Refresh after catalog import
REFRESH MATERIALIZED VIEW search.product_filter_index;
```

---

## Implementation Patterns

### Pattern 1: Add a New Boolean Filter

**Example**: Add "Sensor Included" filter

**Step 1**: Find ETIM feature
```sql
SELECT "FEATUREID", "FEATUREDESC", "TYPE"
FROM etim.feature
WHERE "FEATUREDESC" ILIKE '%sensor%'
    AND "TYPE" = 'L';  -- Logical (boolean)
```

**Step 2**: Add filter definition
```sql
INSERT INTO search.filter_definitions
(filter_key, label, category, etim_feature_id, value_type, sort_order, active)
VALUES
('sensor_included', 'Sensor Included', 'electricals', 'EF000185', 'boolean', 15, true);
```

**Step 3**: Refresh filter index
```sql
REFRESH MATERIALIZED VIEW search.product_filter_index;
```

**Step 4**: Add to UI
```typescript
<BooleanFilter
  label="Sensor Included"
  value={sensorIncluded}
  onChange={setSensorIncluded}
/>
```

**Step 5**: Update search function call
```typescript
const { data } = await supabase.rpc('search_products_with_filters', {
  // ... existing params
  p_sensor_included: sensorIncluded,
})
```

### Pattern 2: Add a New Multi-Select Filter

**Example**: Add "Dimming Method" filter

**Step 1**: Find ETIM feature
```sql
SELECT "FEATUREID", "FEATUREDESC", "TYPE"
FROM etim.feature
WHERE "FEATUREDESC" ILIKE '%dimm%method%'
    AND "TYPE" = 'A';  -- Alphanumeric
```

**Step 2**: Check available values
```sql
SELECT DISTINCT
    f->>'ALPHANUMERIC' as dimming_method,
    COUNT(*) as product_count
FROM items.product_info pi,
     jsonb_array_elements(pi.features) f
WHERE f->>'FEATUREID' = 'EF027456'  -- Your found ETIM ID
GROUP BY f->>'ALPHANUMERIC'
ORDER BY product_count DESC;
```

**Step 3**: Add filter definition
```sql
INSERT INTO search.filter_definitions
(filter_key, label, category, etim_feature_id, value_type, sort_order, active)
VALUES
('dimming_method', 'Dimming Method', 'electricals', 'EF027456', 'multi_select', 30, true);
```

**Step 4**: Refresh filter index
```sql
REFRESH MATERIALIZED VIEW search.product_filter_index;
```

**Step 5**: Add to UI
```typescript
<MultiSelectFilter
  label="Dimming Method"
  options={getDimmingMethodOptions(filterFacets)}
  selected={selectedDimmingMethods}
  onChange={setSelectedDimmingMethods}
  showCounts={true}
/>
```

**Step 6**: Update search function call
```typescript
const { data } = await supabase.rpc('search_products_with_filters', {
  // ... existing params
  p_filters: {
    ...activeFilters,
    dimming_method: selectedDimmingMethods
  },
})
```

### Pattern 3: Add a New Range Filter

**Example**: Add "Efficacy (lm/W)" filter

**Step 1**: Find ETIM feature
```sql
SELECT "FEATUREID", "FEATUREDESC", "TYPE", "UNITCODE"
FROM etim.feature f
LEFT JOIN etim.unit u ON u."UNITCODE" = f."UNITCODE"
WHERE "FEATUREDESC" ILIKE '%efficacy%'
    AND "TYPE" = 'N';  -- Numeric
```

**Step 2**: Check value distribution
```sql
SELECT
    MIN((f->>'NUMERIC')::numeric) as min_efficacy,
    MAX((f->>'NUMERIC')::numeric) as max_efficacy,
    AVG((f->>'NUMERIC')::numeric) as avg_efficacy,
    COUNT(*) as product_count
FROM items.product_info pi,
     jsonb_array_elements(pi.features) f
WHERE f->>'FEATUREID' = 'EF009512';  -- Your found ETIM ID
```

**Step 3**: Add filter definition
```sql
INSERT INTO search.filter_definitions
(filter_key, label, category, etim_feature_id, value_type, unit, sort_order, active)
VALUES
('efficacy', 'Efficacy', 'light_engine', 'EF009512', 'range', 'lm/W', 55, true);
```

**Step 4**: Refresh filter index
```sql
REFRESH MATERIALIZED VIEW search.product_filter_index;
```

**Step 5**: Add to UI
```typescript
<RangeFilter
  label="Efficacy"
  unit="lm/W"
  min={efficacyMin}
  max={efficacyMax}
  onChange={(min, max) => {
    setEfficacyMin(min)
    setEfficacyMax(max)
  }}
  absoluteMin={10}
  absoluteMax={200}
  presets={[
    { label: 'Low (<50)', min: 0, max: 50 },
    { label: 'Medium (50-100)', min: 50, max: 100 },
    { label: 'High (100-150)', min: 100, max: 150 },
    { label: 'Very High (>150)', min: 150, max: 200 }
  ]}
/>
```

**Step 6**: Update search function call
```typescript
const { data } = await supabase.rpc('search_products_with_filters', {
  // ... existing params
  p_filters: {
    ...activeFilters,
    efficacy: { min: efficacyMin, max: efficacyMax }
  },
})
```

---

## Best Practices

### 1. Always Use Dynamic Facets

**DON'T**:
```typescript
// Hardcoded options - not context-aware
const IP_OPTIONS = ['IP20', 'IP44', 'IP54', 'IP65', 'IP67']
```

**DO**:
```typescript
// Load options dynamically based on current filters
useEffect(() => {
  const loadFacets = async () => {
    const { data } = await supabase.rpc('get_dynamic_facets', {
      p_taxonomy_codes: selectedTaxonomies,
      p_indoor: indoor,
      p_outdoor: outdoor,
      // ... all context
    })
    setFilterFacets(data)
  }
  loadFacets()
}, [selectedTaxonomies, indoor, outdoor, ...])
```

### 2. Show Product Counts

**DON'T**:
```typescript
<label>
  <input type="checkbox" />
  IP65
</label>
```

**DO**:
```typescript
<label>
  <input type="checkbox" />
  IP65 ({ipFacets.find(f => f.filter_value === 'IP65')?.product_count || 0})
</label>
```

### 3. Debounce Range Filters

**DON'T**:
```typescript
// Triggers search on every keystroke
<input onChange={(e) => setPowerMin(Number(e.target.value))} />
```

**DO**:
```typescript
// Debounce to avoid excessive searches
const [powerMinInput, setPowerMinInput] = useState('')
const [powerMin, setPowerMin] = useState<number | null>(null)

useEffect(() => {
  const timer = setTimeout(() => {
    setPowerMin(powerMinInput ? Number(powerMinInput) : null)
  }, 300)
  return () => clearTimeout(timer)
}, [powerMinInput])

<input
  value={powerMinInput}
  onChange={(e) => setPowerMinInput(e.target.value)}
/>
```

### 4. Clear Individual Filters

**DON'T**:
Only have "Clear All" button

**DO**:
```typescript
<div className="flex items-center justify-between">
  <label>Power (W)</label>
  {(powerMin !== null || powerMax !== null) && (
    <button
      onClick={() => {
        setPowerMin(null)
        setPowerMax(null)
      }}
      className="text-xs text-blue-600"
    >
      Clear
    </button>
  )}
</div>
```

### 5. Validate Range Inputs

**DON'T**:
```typescript
// Allow invalid ranges (min > max)
<input onChange={(e) => setMin(Number(e.target.value))} />
<input onChange={(e) => setMax(Number(e.target.value))} />
```

**DO**:
```typescript
const handleMinChange = (value: number) => {
  if (max !== null && value > max) {
    // Swap if min > max
    setMin(max)
    setMax(value)
  } else {
    setMin(value)
  }
}

const handleMaxChange = (value: number) => {
  if (min !== null && value < min) {
    // Swap if max < min
    setMax(min)
    setMin(value)
  } else {
    setMax(value)
  }
}
```

---

## Testing Checklist

### Boolean Filters
- [ ] Default state is "Either" (null)
- [ ] Can select "Yes" (true)
- [ ] Can select "No" (false)
- [ ] Can clear back to "Either"
- [ ] Search updates immediately
- [ ] Product count updates
- [ ] Works in combination with other filters

### Multi-Select Filters
- [ ] Options loaded from dynamic facets
- [ ] Product counts shown next to options
- [ ] Can select multiple options (OR logic)
- [ ] Can deselect options
- [ ] Search updates immediately
- [ ] Counts update when other filters change
- [ ] Color swatches display correctly (for color filters)

### Range Filters
- [ ] Min/max inputs accept numeric values
- [ ] Validation prevents min > max
- [ ] Presets work correctly
- [ ] Can clear min/max individually
- [ ] Search debounced (300ms)
- [ ] Absolute min/max displayed
- [ ] Unit displayed correctly
- [ ] Works with decimal values (e.g., 12.5W)

### Dynamic Facets
- [ ] Counts update when category selected
- [ ] Counts update when boolean filters changed
- [ ] Counts update when supplier selected
- [ ] Counts update when search query entered
- [ ] Zero-count options hidden
- [ ] Performance <100ms

---

## Related Documentation

- **UI Components**: [../architecture/ui-components.md](../architecture/ui-components.md)
- **SQL Functions**: [sql-functions.md](sql-functions.md)
- **Delta Light Filters**: [../guides/delta-light-filters.md](../guides/delta-light-filters.md)
- **Dynamic Facets**: [../guides/dynamic-facets.md](../guides/dynamic-facets.md)

---

**Last Updated**: November 19, 2025
**Maintained by**: Development Team
**Review Schedule**: Quarterly

---

## Quick Reference

```typescript
// Boolean filter
<BooleanFilter value={dimmable} onChange={setDimmable} />

// Multi-select filter
<MultiSelectFilter selected={ipRatings} onChange={setIPRatings} options={...} />

// Range filter
<RangeFilter min={powerMin} max={powerMax} onChange={(min, max) => {...}} />

// Dynamic facets
const { data } = await supabase.rpc('get_dynamic_facets', { p_taxonomy_codes, ... })

// Search with filters
const { data } = await supabase.rpc('search_products_with_filters', {
  p_dimmable: true,                    // Boolean
  p_filters: {
    ip: ['IP65', 'IP67'],              // Multi-select
    power: { min: 5, max: 50 }         // Range
  }
})
```
