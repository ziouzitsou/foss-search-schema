# UI Components Architecture

**Application**: search-test-app (Next.js 15.5.6)
**Framework**: React 18.3.1 with TypeScript
**Styling**: Tailwind CSS 4.1.17
**Location**: `/home/dimitris/foss/searchdb/search-test-app/components/`
**Total Lines**: 1,567 (production-quality components)

---

## Overview

The search-test-app implements a **three-column faceted search interface** inspired by Delta Light's professional catalog. The UI is built with reusable, type-safe React components that handle real-time filtering with dynamic facet updates.

### Architecture Pattern

```
Page (app/page.tsx)
├── ProductTabs (root category switcher)
├── 3-Column Layout
│   ├── LEFT: FacetedCategoryNavigation (hierarchical taxonomy)
│   ├── MIDDLE: FilterPanel (technical filters)
│   └── RIGHT: Location/Options (boolean flags)
├── ActiveFilters (filter chips)
└── ProductGrid (results)
```

### Key Design Principles

1. **Type Safety**: All components use TypeScript with strict interfaces
2. **Real-time Updates**: Auto-search triggers on filter changes (300ms debounce)
3. **Dynamic Facets**: Filter options update based on current context
4. **Reusability**: Generic filter components work with any ETIM feature type
5. **Accessibility**: ARIA labels, keyboard navigation, semantic HTML

---

## Component Hierarchy

### Primary Components

| Component | Lines | Purpose | Key Features |
|-----------|-------|---------|--------------|
| **page.tsx** | 592 | Main search interface | State management, RPC calls, layout |
| **FacetedCategoryNavigation** | 342 | Hierarchical taxonomy tree | Expandable sections, multi-select |
| **FilterPanel** | 319 | Technical filter container | Dynamic loading, category grouping |
| **ActiveFilters** | 207 | Filter chip display | Remove individual, clear all |
| **ProductTabs** | 107 | Root category tabs | LUMINAIRE, ACCESSORIES, DRIVERS |

### Filter Components (Reusable)

| Component | Type | ETIM | Use Cases |
|-----------|------|------|-----------|
| **BooleanFilter** | L (Logical) | Boolean | Dimmable (Yes/No) |
| **MultiSelectFilter** | A (Alphanumeric) | Categorical | IP Rating, Finishing Colour, Protection Class |
| **RangeFilter** | R (Range) | Numeric | CCT (2700-6500K), Lumens (0-50000), Power |
| **FilterCategory** | Container | - | Collapsible category sections |

---

## Main Interface (page.tsx)

**Path**: `app/page.tsx` (592 lines)

### State Management

```typescript
// Filter state (14 state variables)
const [query, setQuery] = useState('')
const [suppliers, setSuppliers] = useState<string[]>([])
const [indoor, setIndoor] = useState<boolean | null>(null)
const [outdoor, setOutdoor] = useState<boolean | null>(null)
const [submersible, setSubmersible] = useState<boolean | null>(null)
const [trimless, setTrimless] = useState<boolean | null>(null)
const [cutShapeRound, setCutShapeRound] = useState<boolean | null>(null)
const [cutShapeRectangular, setCutShapeRectangular] = useState<boolean | null>(null)
const [powerMin, setPowerMin] = useState('')
const [powerMax, setPowerMax] = useState('')
const [ipRatings, setIpRatings] = useState<string[]>([])

// UI state
const [products, setProducts] = useState<Product[]>([])
const [loading, setLoading] = useState(false)
const [totalCount, setTotalCount] = useState<number | null>(null)
const [selectedTaxonomies, setSelectedTaxonomies] = useState<string[]>([])
const [activeTab, setActiveTab] = useState('') // LUMINAIRE, ACCESSORIES, etc.
const [activeFilters, setActiveFilters] = useState<any>({})
const [flagCounts, setFlagCounts] = useState<Record<string, {...}>>({})
```

### Auto-Search Pattern

```typescript
// Auto-trigger search when ANY filter changes (no search button!)
useEffect(() => {
  handleSearch()
}, [
  selectedTaxonomies,
  activeTab,
  suppliers,
  indoor,
  outdoor,
  submersible,
  trimless,
  cutShapeRound,
  cutShapeRectangular,
  JSON.stringify(activeFilters) // Deep comparison for nested object
])
```

### Dynamic Facet Loading

```typescript
// Load dynamic flag counts based on current filters
useEffect(() => {
  const loadFlagCounts = async () => {
    const { data } = await supabase.rpc('get_filter_facets_with_context', {
      p_query: query || null,
      p_taxonomy_codes: selectedTaxonomies,
      p_suppliers: suppliers.length > 0 ? suppliers : null,
      p_indoor: indoor,
      p_outdoor: outdoor,
      // ... all filter parameters
    })

    // Convert array to object for easy lookup
    const countsMap = {}
    data?.forEach((item: any) => {
      countsMap[item.flag_name] = {
        true_count: item.true_count,
        false_count: item.false_count
      }
    })
    setFlagCounts(countsMap)
  }

  loadFlagCounts()
}, [selectedTaxonomies, indoor, outdoor, ...]) // Reload on filter changes
```

### Search Function

```typescript
const handleSearch = async (resetLimit = true) => {
  setLoading(true)
  const combinedTaxonomies = getCombinedTaxonomies()

  // Get total count
  const { data: count } = await supabase.rpc('count_products_with_filters', {
    p_query: query || null,
    p_filters: activeFilters,
    p_taxonomy_codes: combinedTaxonomies,
    p_indoor: indoor,
    p_outdoor: outdoor,
    // ... all filters
  })
  setTotalCount(count)

  // Get products
  const { data: products } = await supabase.rpc('search_products_with_filters', {
    p_query: query || null,
    p_filters: activeFilters,
    p_taxonomy_codes: combinedTaxonomies,
    p_limit: 24 + 1, // Request one extra to check if there are more
    p_offset: 0,
    // ... all filters
  })

  setProducts(products.slice(0, 24))
  setHasMore(products.length > 24)
  setLoading(false)
}
```

---

## FacetedCategoryNavigation Component

**Path**: `components/FacetedCategoryNavigation.tsx` (342 lines)

### Purpose

Displays hierarchical product taxonomy as an expandable tree with multi-select checkboxes.

### Props Interface

```typescript
interface FacetedCategoryNavigationProps {
  onSelectTaxonomies: (codes: string[]) => void  // Callback with selected codes
  autoSearch?: boolean         // Trigger search automatically (default: true)
  debounceMs?: number         // Debounce time in ms (default: 300)
  rootCode?: string           // Filter taxonomy by root code (e.g., 'LUMINAIRE')
}
```

### Key Features

1. **Hierarchical Tree**: 3-level structure (Root → Category → Type)
2. **Product Counts**: Shows count per category
3. **Multi-Select**: Checkbox-based selection
4. **Debounced Search**: 300ms delay to prevent excessive queries
5. **Expandable Sections**: Collapse/expand by level
6. **Icon Support**: Maps taxonomy codes to emojis

### State Management

```typescript
const [nodes, setNodes] = useState<TaxonomyNode[]>([])
const [expandedSections, setExpandedSections] = useState<Set<string>>(
  new Set(['level-1']) // Only Level 1 expanded by default
)
const [selectedCodes, setSelectedCodes] = useState<Set<string>>(new Set())
```

### Data Loading

```typescript
const loadTaxonomy = async () => {
  const { data } = await supabase.rpc('get_taxonomy_tree')

  const taxonomyNodes: TaxonomyNode[] = data.map((item: any) => ({
    code: item.code,
    parent_code: item.parent_code,
    level: item.level,
    name: item.name,
    icon: item.icon,
    product_count: item.product_count || 0
  }))

  setNodes(taxonomyNodes)
}
```

### Debounced Selection

```typescript
// Debounce selection changes to avoid excessive searches
useEffect(() => {
  if (!autoSearch) return

  if (debounceTimerRef.current) {
    clearTimeout(debounceTimerRef.current)
  }

  debounceTimerRef.current = setTimeout(() => {
    onSelectTaxonomies(Array.from(selectedCodes))
  }, debounceMs)

  return () => {
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current)
    }
  }
}, [selectedCodes])
```

### Icon Mapping

```typescript
const iconMap: Record<string, string> = {
  'LUMINAIRE': '💡',
  'LAMPS': '🔦',
  'ACCESSORIES': '🔌',
  'DRIVERS': '⚡',
  'LUMINAIRE-INDOOR-CEILING': '⬆️',
  'LUMINAIRE-INDOOR-WALL': '◾',
  'LUMINAIRE-INDOOR-FLOOR': '⬇️',
  // ... more mappings
}
```

---

## FilterPanel Component

**Path**: `components/FilterPanel.tsx` (319 lines)

### Purpose

Container for technical filters grouped by Delta Light categories (Electricals, Design, Light Engine).

### Props Interface

```typescript
interface FilterPanelProps {
  onFilterChange: (filters: FilterState) => void
  taxonomyCode?: string           // Filter scope (default: 'LUMINAIRE')
  selectedTaxonomies?: string[]   // Current category selection
  indoor?: boolean | null         // Context filters for dynamic facets
  outdoor?: boolean | null
  submersible?: boolean | null
  trimless?: boolean | null
  cutShapeRound?: boolean | null
  cutShapeRectangular?: boolean | null
  query?: string | null
  suppliers?: string[]
}
```

### Key Features

1. **Dynamic Loading**: Fetches filter definitions and facets based on context
2. **Category Grouping**: Electricals, Design, Light Engine
3. **Collapsible Categories**: Expand/collapse sections
4. **Clear Filters**: Individual and "Clear All" buttons
5. **Active Count Badge**: Shows number of active filters
6. **Context-Aware**: Facet counts update with selections

### State Management

```typescript
const [filterDefinitions, setFilterDefinitions] = useState<FilterDefinition[]>([])
const [filterFacets, setFilterFacets] = useState<FilterFacet[]>([])
const [filterState, setFilterState] = useState<FilterState>({})
const [expandedCategories, setExpandedCategories] = useState<Set<string>>(
  new Set(['electricals', 'design', 'light_engine']) // All expanded by default
)
```

### Loading Filters

```typescript
const loadFilters = async () => {
  // Get filter definitions with ETIM feature type
  const { data: definitions } = await supabase
    .rpc('get_filter_definitions_with_type', {
      p_taxonomy_code: taxonomyCode
    })

  // Get DYNAMIC filter facets based on ALL current selections
  const { data: facets } = await supabase
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

  setFilterDefinitions(definitions || [])
  setFilterFacets(facets || [])
}
```

### Reloading on Context Changes

```typescript
// Reload filters when taxonomy, taxonomies, OR context flags change
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
```

### Grouping Filters by Category

```typescript
const groupedFilters = filterDefinitions.reduce((acc, filter) => {
  const category = filter.ui_config?.filter_category || 'other'
  if (!acc[category]) acc[category] = []
  acc[category].push(filter)
  return acc
}, {} as Record<string, FilterDefinition[]>)

const categoryLabels: Record<string, string> = {
  electricals: 'Electricals',
  design: 'Design',
  light_engine: 'Light Engine'
}
```

### Rendering Filters

```typescript
{Object.entries(groupedFilters).map(([category, filters]) => (
  <FilterCategory
    key={category}
    label={categoryLabels[category]}
    isExpanded={expandedCategories.has(category)}
    onToggle={() => toggleCategory(category)}
  >
    {filters.map(filter => {
      const facets = getFacetsForFilter(filter.filter_key)

      // Render appropriate component based on type
      switch (filter.filter_type) {
        case 'boolean':
          return <BooleanFilter {...props} />
        case 'multi-select':
          return <MultiSelectFilter {...props} />
        case 'range':
          return <RangeFilter {...props} />
        default:
          return null
      }
    })}
  </FilterCategory>
))}
```

### Preset Configuration

```typescript
const getCCTPresets = (): Preset[] => [
  { label: 'Warm White', min: 2700, max: 3000, description: 'Cozy, warm lighting' },
  { label: 'Neutral White', min: 3500, max: 4500, description: 'Balanced daylight' },
  { label: 'Cool White', min: 5000, max: 6500, description: 'Bright, energizing' }
]

const getLumensPresets = (): Preset[] => [
  { label: 'Low', min: 0, max: 500, description: 'Ambient lighting' },
  { label: 'Medium', min: 500, max: 2000, description: 'Task lighting' },
  { label: 'High', min: 2000, max: 50000, description: 'High output' }
]
```

---

## Filter Components (Reusable)

### BooleanFilter

**Path**: `components/filters/BooleanFilter.tsx`
**ETIM Type**: L (Logical)

**Purpose**: Yes/No filters with radio-button-like behavior

**Features**:
- Sorted display (Yes first, then No)
- Toggle behavior (click again to clear)
- Dynamic product counts
- Clear button

**Example Usage**:
```typescript
<BooleanFilter
  filterKey="dimmable"
  label="Dimmable"
  etimFeatureType="L"
  value={filterState.dimmable ?? null}
  onChange={(value) => updateFilterState('dimmable', value)}
  facets={facets}
  showCount={true}
  onClear={() => clearFilter('dimmable')}
/>
```

**UI Behavior**:
- ☑ Yes (11,220) ← Selected
- ☐ No (1,833)

### MultiSelectFilter

**Path**: `components/filters/MultiSelectFilter.tsx`
**ETIM Type**: A (Alphanumeric)

**Purpose**: Checkbox list for categorical filters

**Features**:
- Optional search input (if >10 options)
- Color swatches for Finishing Colour filter
- Icons for IP Rating filter
- Dynamic counts per option
- Sorted by count (descending)

**Options**:
```typescript
interface MultiSelectOptions {
  searchable?: boolean      // Show search input
  maxHeight?: string        // Max height for scrolling
  showCount?: boolean       // Show product counts
  showIcons?: boolean       // Show IP rating icons
  colorSwatches?: boolean   // Show color swatches
}
```

**Example Usage**:
```typescript
<MultiSelectFilter
  filterKey="ip"
  label="IP Rating"
  etimFeatureType="A"
  values={filterState.ip || []}
  onChange={(values) => updateFilterState('ip', values)}
  facets={facets}
  options={{
    showCount: true,
    showIcons: true,  // 💧💧 for IP65, 💧 for IP54, etc.
    maxHeight: '16rem'
  }}
  onClear={() => clearFilter('ip')}
/>
```

**Color Swatch Mapping**:
```typescript
const colorMap = {
  'Black': '#000000',
  'White': '#FFFFFF',
  'Gold': '#FFD700',
  'Silver': '#C0C0C0',
  'Bronze': '#CD7F32',
  // ... more colors
}
```

**IP Rating Icons**:
```typescript
const getIPIcon = (ipRating: string) => {
  if (ipRating.startsWith('IP6')) return '💧💧' // High protection
  if (ipRating.startsWith('IP5')) return '💧'   // Medium
  if (ipRating.startsWith('IP4')) return '💦'   // Splash
  if (ipRating.startsWith('IP2')) return '☂️'   // Basic
  return '🏠' // Indoor
}
```

### RangeFilter

**Path**: `components/filters/RangeFilter.tsx`
**ETIM Type**: R (Range)

**Purpose**: Min/max numeric range inputs

**Features**:
- Dual inputs (min/max)
- Preset buttons (Warm White, Cool White, etc.)
- Range info from facets (shows actual min/max in data)
- Unit display (K, W, lm)
- Step control

**Example Usage**:
```typescript
<RangeFilter
  filterKey="cct"
  label="CCT (Color Temperature)"
  etimFeatureType="R"
  value={filterState.cct || {}}
  onChange={(value) => updateFilterState('cct', value)}
  unit="K"
  minBound={2700}
  maxBound={6500}
  step={100}
  presets={getCCTPresets()}
  facets={facets}
  onClear={() => clearFilter('cct')}
/>
```

**Preset Interface**:
```typescript
interface Preset {
  label: string           // "Warm White"
  min: number            // 2700
  max: number            // 3000
  description?: string   // "Cozy, warm lighting"
}
```

### FilterCategory

**Path**: `components/filters/FilterCategory.tsx`
**Purpose**: Collapsible category container

**Example Usage**:
```typescript
<FilterCategory
  label="Electricals"
  isExpanded={expandedCategories.has('electricals')}
  onToggle={() => toggleCategory('electricals')}
>
  <BooleanFilter ... />
  <MultiSelectFilter ... />
  <RangeFilter ... />
</FilterCategory>
```

---

## ActiveFilters Component

**Path**: `components/ActiveFilters.tsx` (207 lines)

### Purpose

Displays selected taxonomy codes as removable chips with product count.

### Props Interface

```typescript
interface ActiveFiltersProps {
  selectedTaxonomyCodes: string[]
  onRemoveTaxonomy: (code: string) => void
  onClearAll: () => void
}
```

### Features

- Chip display with X button
- Total product count
- "Clear All" button
- Fetches taxonomy names from database

### UI Example

```
Selected: Indoor → Ceiling → Recessed (234 products)  [Clear All]
[🏠 Indoor ✕] [⬆️ Ceiling ✕] [⬇️ Recessed ✕]
```

---

## ProductTabs Component

**Path**: `components/ProductTabs.tsx` (107 lines)

### Purpose

Root-level category switcher (LUMINAIRE, ACCESSORIES, DRIVERS, LAMPS).

### Features

- Tab-based navigation
- Wraps children with tab context
- Resets filters on tab change

### Usage

```typescript
<ProductTabs onTabChange={handleTabChange}>
  <FacetedCategoryNavigation rootCode={activeTab} />
  <FilterPanel taxonomyCode={activeTab} />
  {/* Product results */}
</ProductTabs>
```

---

## Type System

**Path**: `components/filters/types.ts` (102 lines)

### Core Types

```typescript
export type FilterType = 'boolean' | 'multi-select' | 'numeric' | 'range'

export interface FilterDefinition {
  filter_key: string
  label: string
  filter_type: FilterType
  etim_feature_type?: string  // A, L, N, or R
  ui_config: {
    filter_category: string
    min?: number
    max?: number
    step?: number
    unit?: string
    show_count?: boolean
    show_icons?: boolean
    color_swatches?: boolean
    presets?: Preset[]
  }
  display_order: number
}

export interface FilterFacet {
  filter_key: string
  filter_label: string
  filter_category: string
  filter_value: string
  product_count: number
  min_numeric_value?: number
  max_numeric_value?: number
}

export interface Preset {
  label: string
  min: number
  max: number
  description?: string
}
```

---

## Styling Approach

### Tailwind CSS Classes

**Card Styling**:
```typescript
className="bg-gradient-to-br from-slate-50 to-white rounded-xl shadow-lg border border-slate-200"
```

**Interactive Elements**:
```typescript
className="hover:bg-gray-50 transition-colors cursor-pointer"
```

**Active States**:
```typescript
className={isSelected ? 'font-medium text-blue-600' : 'text-gray-700'}
```

### Responsive Design

- **Mobile**: Single column, collapsible sections
- **Tablet**: Two columns (categories + filters)
- **Desktop**: Three columns (categories + filters + options)

### Accessibility

- ARIA labels on all interactive elements
- Keyboard navigation support
- Focus indicators
- Semantic HTML structure

---

## Performance Considerations

### Optimization Techniques

1. **Debouncing**:
   - Search: 300ms delay
   - Prevents excessive RPC calls

2. **Memoization**:
   - `useCallback` for event handlers
   - `useMemo` for derived state (future enhancement)

3. **Pagination**:
   - Load 24 products at a time
   - "Load More" button for next page

4. **Selective Rendering**:
   - Collapsed categories don't render filters
   - Reduces DOM complexity

### State Updates

```typescript
// Efficient state updates (merge vs replace)
const updateFilterState = (filterKey: string, value: any) => {
  const newState = { ...filterState }

  if (value === undefined || value === null ||
      (Array.isArray(value) && value.length === 0)) {
    delete newState[filterKey]  // Remove empty filters
  } else {
    newState[filterKey] = value
  }

  setFilterState(newState)
  onFilterChange(newState)
}
```

---

## Integration Pattern

### Parent → Child Data Flow

```
page.tsx (parent)
  ↓ props: onSelectTaxonomies, autoSearch
FacetedCategoryNavigation (child)
  ↓ callback: onSelectTaxonomies(['LUMINAIRE-CEILING'])
page.tsx (parent)
  ↓ state update: setSelectedTaxonomies
  ↓ useEffect triggers: handleSearch()
  ↓ RPC call: search_products_with_filters()
  ↓ state update: setProducts(data)
ProductGrid (child)
  ↓ props: products
[UI renders]
```

### Filter State Lifecycle

```
1. User clicks filter checkbox
2. Component calls onChange callback
3. Parent updates filterState
4. useEffect detects filterState change
5. Triggers handleSearch()
6. RPC calls: count + search
7. Updates products + totalCount
8. Triggers loadFlagCounts()
9. RPC call: get_filter_facets_with_context
10. Updates flag counts
11. UI re-renders with new data
```

---

## Testing Approach

### Manual Testing Checklist

**FacetedCategoryNavigation**:
- [ ] Tree expands/collapses correctly
- [ ] Checkboxes select/deselect
- [ ] Product counts display
- [ ] Debounce works (300ms delay)

**FilterPanel**:
- [ ] Filters load based on taxonomy
- [ ] Categories expand/collapse
- [ ] Clear individual filter works
- [ ] Clear all filters works
- [ ] Badge shows correct count

**Filter Components**:
- [ ] BooleanFilter: Yes/No toggle
- [ ] MultiSelectFilter: Checkboxes work
- [ ] RangeFilter: Min/max inputs validate
- [ ] Presets apply correctly

**Dynamic Behavior**:
- [ ] Facet counts update on filter changes
- [ ] Zero-count options hidden (if applicable)
- [ ] Auto-search triggers correctly

---

## Future Enhancements

### Planned Features

1. **Dual-Range Slider**:
   - Replace min/max inputs with visual slider
   - Library: rc-slider or similar

2. **Filter History**:
   - Save recent filter combinations
   - Quick restore previous searches

3. **Mobile Optimization**:
   - Drawer-based filter panel
   - Swipe gestures
   - Bottom sheet for categories

4. **Keyboard Shortcuts**:
   - `/` to focus search
   - `Esc` to clear filters
   - Arrow keys for navigation

5. **Export Functionality**:
   - Export filtered results to CSV/Excel
   - Share filter URL

### Component Splitting

**Large components to split**:
- `page.tsx` (592 lines) → Extract search logic to custom hook
- `FacetedCategoryNavigation` (342 lines) → Extract tree rendering
- `FilterPanel` (319 lines) → Extract category logic

**Proposed structure**:
```typescript
// Custom hook for search logic
function useProductSearch() {
  // All search-related state and functions
  return { products, loading, handleSearch, ... }
}

// In page.tsx
const { products, loading, handleSearch } = useProductSearch()
```

---

## Related Documentation

- **Filter Types Guide**: [../reference/filter-types.md](../reference/filter-types.md)
- **Delta Light Filters**: [../guides/delta-light-filters.md](../guides/delta-light-filters.md)
- **Dynamic Facets**: [../guides/dynamic-facets.md](../guides/dynamic-facets.md)
- **SQL Functions**: [../reference/sql-functions.md](../reference/sql-functions.md)

---

**Last Updated**: November 19, 2025
**Component Count**: 8 major components
**Total Lines**: 1,567
**Framework**: Next.js 15.5.6 + React 18.3.1
