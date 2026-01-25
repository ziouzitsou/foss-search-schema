'use client'

import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'
import { X } from 'lucide-react'
import {
  BooleanFilter,
  MultiSelectFilter,
  RangeFilter,
  FilterCategory,
  FilterDefinition,
  FilterFacet,
  Preset
} from './filters'

type FilterState = {
  [key: string]: any // multi-select: string[], range: {min, max}, boolean: boolean
}

export type FilterPanelProps = {
  onFilterChange: (filters: FilterState) => void
  taxonomyCode?: string
  selectedTaxonomies?: string[]
  query?: string | null
  suppliers?: string[]
}

export default function FilterPanel({
  onFilterChange,
  taxonomyCode,  // No default - passed dynamically from parent
  selectedTaxonomies = [],
  query = null,
  suppliers = []
}: FilterPanelProps) {
  const [filterDefinitions, setFilterDefinitions] = useState<FilterDefinition[]>([])
  const [filterFacets, setFilterFacets] = useState<FilterFacet[]>([])
  const [filterState, setFilterState] = useState<FilterState>({})
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(
    new Set(['electricals', 'design', 'light_engine', 'location', 'options', 'other'])
  )
  const [loading, setLoading] = useState(true)

  // Load filter definitions and facets
  // Reload when taxonomy, selected taxonomies, query, suppliers, OR location/options filters change
  // This ensures technical filter counts update based on user selections
  useEffect(() => {
    console.log('🔄 FilterPanel: Taxonomy changed to:', taxonomyCode)
    loadFilters()
  }, [
    taxonomyCode,
    selectedTaxonomies.join(','),
    query,
    suppliers.join(','),
    filterState.indoor,
    filterState.outdoor,
    filterState.submersible,
    filterState.trimless,
    filterState.cut_shape_round,
    filterState.cut_shape_rectangular
  ])

  const loadFilters = async () => {
    try {
      setLoading(true)

      // Get filter definitions with ETIM feature type
      const { data: definitions, error: defError } = await supabase
        .rpc('get_filter_definitions_with_type', {
          p_taxonomy_code: taxonomyCode
        })

      if (defError) throw defError

      console.log(`✅ Loaded ${definitions?.length || 0} filter definitions for taxonomy: ${taxonomyCode}`, definitions)

      // Extract location/options flags from current filter state
      const indoor = filterState.indoor ?? null
      const outdoor = filterState.outdoor ?? null
      const submersible = filterState.submersible ?? null
      const trimless = filterState.trimless ?? null
      const cutShapeRound = filterState.cut_shape_round ?? null
      const cutShapeRectangular = filterState.cut_shape_rectangular ?? null

      // Get DYNAMIC filter facets based on selected taxonomies AND all current filter selections
      const { data: facets, error: facetsError } = await supabase
        .rpc('get_dynamic_facets', {
          p_taxonomy_codes: selectedTaxonomies.length > 0 ? selectedTaxonomies : null,
          p_filters: null, // Technical filters handled separately by design
          p_suppliers: suppliers.length > 0 ? suppliers : null,
          p_indoor: indoor,
          p_outdoor: outdoor,
          p_submersible: submersible,
          p_trimless: trimless,
          p_cut_shape_round: cutShapeRound,
          p_cut_shape_rectangular: cutShapeRectangular,
          p_query: query
        })

      if (facetsError) throw facetsError

      console.log('✅ Dynamic technical filter facets loaded with context:', {
        taxonomyCodes: selectedTaxonomies,
        indoor, outdoor, submersible, trimless, cutShapeRound, cutShapeRectangular
      })

      setFilterDefinitions(definitions || [])
      setFilterFacets(facets || [])
    } catch (error) {
      console.error('Error loading filters:', error)
    } finally {
      setLoading(false)
    }
  }

  const toggleCategory = (category: string) => {
    setExpandedCategories(prev => {
      const newSet = new Set(prev)
      if (newSet.has(category)) {
        newSet.delete(category)
      } else {
        newSet.add(category)
      }
      return newSet
    })
  }

  const updateFilterState = (filterKey: string, value: any) => {
    const newState = { ...filterState }

    if (value === undefined || value === null ||
        (Array.isArray(value) && value.length === 0) ||
        (typeof value === 'object' && !Array.isArray(value) && Object.keys(value).length === 0)) {
      delete newState[filterKey]
    } else {
      newState[filterKey] = value
    }

    console.log('🔧 FilterPanel updateFilterState:', { filterKey, value, newState })
    setFilterState(newState)
    onFilterChange(newState)
  }

  const clearFilter = (filterKey: string) => {
    const newState = { ...filterState }
    delete newState[filterKey]
    setFilterState(newState)
    onFilterChange(newState)
  }

  const clearAllFilters = () => {
    setFilterState({})
    onFilterChange({})
  }

  const getActiveFilterCount = () => {
    return Object.keys(filterState).length
  }

  const getFacetsForFilter = (filterKey: string): FilterFacet[] => {
    return filterFacets.filter(f => f.filter_key === filterKey)
  }

  // Group filters by category
  const groupedFilters = filterDefinitions.reduce((acc, filter) => {
    const category = filter.ui_config?.filter_category || 'other'
    if (!acc[category]) acc[category] = []
    acc[category].push(filter)
    return acc
  }, {} as Record<string, FilterDefinition[]>)

  const categoryLabels: Record<string, string> = {
    electricals: 'Electricals',
    design: 'Design',
    light_engine: 'Light Engine',
    location: 'Location',
    options: 'Options'
  }

  // Define presets for specific filters
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

  if (loading) {
    return (
      <div className="bg-gradient-to-br from-slate-50 to-white p-6 rounded-xl shadow-lg border border-slate-200">
        <div className="animate-pulse flex items-center gap-2 text-slate-600">
          <div className="w-4 h-4 bg-blue-500 rounded-full animate-bounce"></div>
          Loading filters...
        </div>
      </div>
    )
  }

  return (
    <div className="bg-gradient-to-br from-slate-50 to-white rounded-xl shadow-lg border border-slate-200">
      {/* Header */}
      <div className="px-6 py-4 border-b border-slate-200 bg-white rounded-t-xl">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-1 h-6 bg-blue-500 rounded-full"></div>
            <h3 className="font-bold text-xl text-slate-800">
              Technical Filters
            </h3>
            {getActiveFilterCount() > 0 && (
              <span className="bg-blue-500 text-white text-xs font-bold px-2 py-1 rounded-full">
                {getActiveFilterCount()}
              </span>
            )}
          </div>
          {getActiveFilterCount() > 0 && (
            <button
              onClick={clearAllFilters}
              className="text-sm text-red-600 hover:text-red-700 hover:bg-red-50 px-3 py-1.5 rounded-lg flex items-center gap-1.5 transition-colors font-medium"
            >
              <X size={16} />
              Clear All
            </button>
          )}
        </div>
      </div>

      {/* Filter Categories */}
      {Object.entries(groupedFilters).map(([category, filters]) => (
        <FilterCategory
          key={category}
          label={categoryLabels[category] || category}
          isExpanded={expandedCategories.has(category)}
          onToggle={() => toggleCategory(category)}
        >
          {filters.map(filter => {
            const facets = getFacetsForFilter(filter.filter_key)

            // Render appropriate filter component based on type
            switch (filter.filter_type) {
              case 'boolean':
                return (
                  <BooleanFilter
                    key={filter.filter_key}
                    filterKey={filter.filter_key}
                    label={filter.label}
                    etimFeatureType={filter.etim_feature_type}
                    value={filterState[filter.filter_key] ?? null}
                    onChange={(value) => updateFilterState(filter.filter_key, value)}
                    facets={facets}
                    showCount={true} // Always show counts
                    onClear={() => clearFilter(filter.filter_key)}
                  />
                )

              case 'multi-select':
              case 'categorical':
                return (
                  <MultiSelectFilter
                    key={filter.filter_key}
                    filterKey={filter.filter_key}
                    label={filter.label}
                    etimFeatureType={filter.etim_feature_type}
                    values={filterState[filter.filter_key] || []}
                    onChange={(values) => updateFilterState(filter.filter_key, values)}
                    facets={facets}
                    options={{
                      searchable: false, // Disabled for cleaner UI
                      maxHeight: '16rem', // Increased height for better visibility
                      showCount: true, // Always show counts
                      showIcons: filter.filter_key === 'ip',
                      colorSwatches: filter.filter_key === 'finishing_colour'
                    }}
                    onClear={() => clearFilter(filter.filter_key)}
                  />
                )

              case 'range':
                return (
                  <RangeFilter
                    key={filter.filter_key}
                    filterKey={filter.filter_key}
                    label={filter.label}
                    etimFeatureType={filter.etim_feature_type}
                    value={filterState[filter.filter_key] || {}}
                    onChange={(value) => updateFilterState(filter.filter_key, value)}
                    unit={filter.ui_config?.unit}
                    minBound={filter.ui_config?.min}
                    maxBound={filter.ui_config?.max}
                    step={filter.ui_config?.step || 1}
                    presets={
                      filter.filter_key === 'cct' ? getCCTPresets() :
                      filter.filter_key === 'lumens_output' ? getLumensPresets() :
                      []
                    }
                    facets={facets}
                    onClear={() => clearFilter(filter.filter_key)}
                  />
                )

              default:
                return null
            }
          })}
        </FilterCategory>
      ))}

      {filterDefinitions.length === 0 && (
        <div className="px-6 py-8 text-center">
          <div className="text-slate-400 text-sm">
            <div className="mb-2">🔍</div>
            No filters available for this category
          </div>
        </div>
      )}
    </div>
  )
}
