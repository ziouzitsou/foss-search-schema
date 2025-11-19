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
}

export default function FilterPanel({ onFilterChange, taxonomyCode = 'LUMINAIRE', selectedTaxonomies = [] }: FilterPanelProps) {
  const [filterDefinitions, setFilterDefinitions] = useState<FilterDefinition[]>([])
  const [filterFacets, setFilterFacets] = useState<FilterFacet[]>([])
  const [filterState, setFilterState] = useState<FilterState>({})
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(
    new Set(['electricals', 'design', 'light_engine'])
  )
  const [loading, setLoading] = useState(true)

  // Load filter definitions and facets
  useEffect(() => {
    loadFilters()
  }, [taxonomyCode, selectedTaxonomies])

  const loadFilters = async () => {
    try {
      setLoading(true)

      // Get filter definitions with ETIM feature type
      const { data: definitions, error: defError } = await supabase
        .rpc('get_filter_definitions_with_type', {
          p_taxonomy_code: taxonomyCode
        })

      if (defError) throw defError

      // Get DYNAMIC filter facets based on selected taxonomies
      const { data: facets, error: facetsError } = await supabase
        .rpc('get_dynamic_facets', {
          p_taxonomy_codes: selectedTaxonomies.length > 0 ? selectedTaxonomies : null
        })

      if (facetsError) throw facetsError

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
    light_engine: 'Light Engine'
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
      <div className="bg-white p-4 rounded-lg shadow-sm">
        <div className="animate-pulse">Loading filters...</div>
      </div>
    )
  }

  return (
    <div className="bg-white p-4 rounded-lg shadow-sm">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-bold text-lg">
          Filters {getActiveFilterCount() > 0 && `(${getActiveFilterCount()})`}
        </h3>
        {getActiveFilterCount() > 0 && (
          <button
            onClick={clearAllFilters}
            className="text-sm text-blue-600 hover:text-blue-800 flex items-center gap-1"
          >
            <X size={14} />
            Clear All
          </button>
        )}
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
        <div className="text-sm text-gray-500 text-center py-4">
          No filters available for this category
        </div>
      )}
    </div>
  )
}
