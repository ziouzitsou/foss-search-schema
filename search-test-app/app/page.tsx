'use client'

import { useState, useEffect, useCallback } from 'react'
import { supabase } from '@/lib/supabase'
import { BarChart3, Lightbulb } from 'lucide-react'
import FacetedCategoryNavigation from '@/components/FacetedCategoryNavigation'
import ActiveFilters from '@/components/ActiveFilters'
import ProductTabs from '@/components/ProductTabs'
import FilterPanel from '@/components/FilterPanel'
import ProductCard from '@/components/ProductCard'
import ProductCardSkeleton from '@/components/ProductCardSkeleton'
import EmptyState from '@/components/EmptyState'
import SystemStatsModal from '@/components/SystemStatsModal'
import CustomCheckbox from '@/components/CustomCheckbox'
import { Home, TreePine, Droplet, Scissors, Circle, Square } from 'lucide-react'

type Product = {
  product_id: string
  foss_pid: string
  description_short: string
  description_long: string | null
  supplier_name: string
  class_name: string
  price: number | null
  image_url: string | null
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

export default function SearchPage() {
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
  const [products, setProducts] = useState<Product[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [stats, setStats] = useState<any>(null)
  const [showStatsModal, setShowStatsModal] = useState(false)
  const [limit, setLimit] = useState(24)
  const [hasMore, setHasMore] = useState(false)
  const [totalCount, setTotalCount] = useState<number | null>(null)
  const [selectedTaxonomies, setSelectedTaxonomies] = useState<string[]>([])
  const [activeTab, setActiveTab] = useState('') // Now holds taxonomy code (e.g., 'LUMINAIRE')
  const [activeFilters, setActiveFilters] = useState<any>({})
  const [flagCounts, setFlagCounts] = useState<Record<string, { true_count: number, false_count: number }>>({})

  const handleTaxonomiesChange = useCallback((codes: string[]) => {
    setSelectedTaxonomies(codes)
    // Search will be triggered by useEffect below
  }, [])

  const handleRemoveTaxonomy = useCallback((code: string) => {
    setSelectedTaxonomies(prev => prev.filter(c => c !== code))
  }, [])

  const handleClearAllTaxonomies = useCallback(() => {
    setSelectedTaxonomies([])
  }, [])

  const handleTabChange = useCallback((value: string) => {
    setActiveTab(value)
    // Reset user-selected taxonomies when switching tabs
    setSelectedTaxonomies([])
    // Clear current products immediately for fresh start
    setProducts([])
    setTotalCount(null)
    // Search will be triggered by useEffect
  }, [])

  // Get combined taxonomy codes (tab filter + user selections)
  const getCombinedTaxonomies = useCallback(() => {
    // If user has made specific selections, use only those (they're already filtered by tab)
    if (selectedTaxonomies.length > 0) {
      return selectedTaxonomies
    }

    // Otherwise, use tab-level filter (activeTab is now the taxonomy code directly, e.g., 'LUMINAIRE')
    return activeTab ? [activeTab] : null
  }, [activeTab, selectedTaxonomies])

  // Auto-trigger search when any filter changes (instant, no debounce)
  useEffect(() => {
    console.log('🔍 Search triggered by filter change:', {
      selectedTaxonomies, activeTab, suppliers, indoor, outdoor, submersible,
      trimless, cutShapeRound, cutShapeRectangular, activeFilters
    })
    handleSearch()
  }, [selectedTaxonomies, activeTab, suppliers, indoor, outdoor, submersible, trimless, cutShapeRound, cutShapeRectangular, JSON.stringify(activeFilters)]) // eslint-disable-line react-hooks/exhaustive-deps

  // Load dynamic flag counts based on current filters
  // This updates whenever filters change, showing only available options
  useEffect(() => {
    const loadFlagCounts = async () => {
      const combinedTaxonomies = getCombinedTaxonomies()
      if (!combinedTaxonomies) {
        setFlagCounts({})
        return
      }

      try {
        // Call the dynamic facets function with current filter selections
        const { data, error } = await supabase.rpc('get_filter_facets_with_context', {
          p_query: query || null,
          p_taxonomy_codes: combinedTaxonomies,
          p_suppliers: suppliers.length > 0 ? suppliers : null,
          p_indoor: indoor,
          p_outdoor: outdoor,
          p_submersible: submersible,
          p_trimless: trimless,
          p_cut_shape_round: cutShapeRound,
          p_cut_shape_rectangular: cutShapeRectangular
        })

        if (error) throw error

        // Convert array to object for easy lookup
        const countsMap: Record<string, { true_count: number, false_count: number }> = {}
        data?.forEach((item: any) => {
          countsMap[item.flag_name] = {
            true_count: item.true_count,
            false_count: item.false_count
          }
        })
        setFlagCounts(countsMap)
        console.log('✅ Dynamic facet counts loaded:', countsMap)
      } catch (error) {
        console.error('Error loading dynamic facet counts:', error)
      }
    }

    loadFlagCounts()
  }, [selectedTaxonomies, activeTab, suppliers, indoor, outdoor, submersible, trimless, cutShapeRound, cutShapeRectangular, query]) // eslint-disable-line react-hooks/exhaustive-deps

  const handleFilterChange = useCallback((filters: any) => {
    console.log('📥 page.tsx handleFilterChange received:', filters)
    setActiveFilters(filters)
  }, [])

  const getTotalCount = async () => {
    try {
      const combinedTaxonomies = getCombinedTaxonomies()
      console.log('📊 Calling count RPC with params:', {
        p_query: query || null,
        p_filters: activeFilters,
        p_taxonomy_codes: combinedTaxonomies,
        p_suppliers: suppliers.length > 0 ? suppliers : null,
        p_indoor: indoor,
        p_outdoor: outdoor,
        p_submersible: submersible,
        p_trimless: trimless,
        p_cut_shape_round: cutShapeRound,
        p_cut_shape_rectangular: cutShapeRectangular
      })
      const { data, error } = await supabase.rpc('count_products_with_filters', {
        p_query: query || null,
        p_filters: activeFilters,
        p_taxonomy_codes: combinedTaxonomies,
        p_suppliers: suppliers.length > 0 ? suppliers : null,
        p_indoor: indoor,
        p_outdoor: outdoor,
        p_submersible: submersible,
        p_trimless: trimless,
        p_cut_shape_round: cutShapeRound,
        p_cut_shape_rectangular: cutShapeRectangular
      })

      console.log('📊 Count RPC result:', { count: data, hasError: !!error, error })
      if (error) throw error
      setTotalCount(data as number)
    } catch (err: any) {
      console.error('Count error:', err)
      setTotalCount(null)
    }
  }

  const handleSearch = async (resetLimit = true) => {
    console.log('🔎 handleSearch called with filters:', {
      indoor, outdoor, submersible, trimless, cutShapeRound, cutShapeRectangular,
      resetLimit
    })
    setLoading(true)
    setError(null)

    const searchLimit = resetLimit ? 24 : limit
    const combinedTaxonomies = getCombinedTaxonomies()

    try {
      // Get total count first
      await getTotalCount()

      // Uses public.search_products_with_filters() with Delta-style filters
      console.log('🔎 Calling search RPC with params:', {
        p_query: query || null,
        p_filters: activeFilters,
        p_taxonomy_codes: combinedTaxonomies,
        p_suppliers: suppliers.length > 0 ? suppliers : null,
        p_indoor: indoor,
        p_outdoor: outdoor,
        p_submersible: submersible,
        p_trimless: trimless,
        p_cut_shape_round: cutShapeRound,
        p_cut_shape_rectangular: cutShapeRectangular,
        p_limit: searchLimit + 1
      })
      const { data, error: searchError } = await supabase.rpc('search_products_with_filters', {
        p_query: query || null,
        p_filters: activeFilters,
        p_taxonomy_codes: combinedTaxonomies,
        p_suppliers: suppliers.length > 0 ? suppliers : null,
        p_indoor: indoor,
        p_outdoor: outdoor,
        p_submersible: submersible,
        p_trimless: trimless,
        p_cut_shape_round: cutShapeRound,
        p_cut_shape_rectangular: cutShapeRectangular,
        p_limit: searchLimit + 1, // Request one extra to check if there are more
        p_offset: 0
      })

      console.log('🔎 Search RPC result:', {
        resultCount: data?.length,
        hasError: !!searchError,
        error: searchError
      })

      if (searchError) throw searchError

      const results = data || []
      setHasMore(results.length > searchLimit)
      setProducts(results.slice(0, searchLimit))
      if (resetLimit) setLimit(24)
    } catch (err: any) {
      setError(err.message)
      console.error('Search error:', err)
    } finally {
      setLoading(false)
    }
  }

  const loadMore = () => {
    setLimit(prev => prev + 24)
    handleSearch(false)
  }

  const loadStats = async () => {
    try {
      // Uses public.get_search_statistics() wrapper → search.get_search_statistics()
      const { data, error } = await supabase.rpc('get_search_statistics')
      if (error) throw error
      const statsObj = Object.fromEntries(
        data.map((item: any) => [item.stat_name, item.stat_value])
      )
      setStats(statsObj)
      setShowStatsModal(true)
    } catch (err) {
      console.error('Stats error:', err)
    }
  }

  const toggleSupplier = (supplier: string) => {
    setSuppliers(prev =>
      prev.includes(supplier)
        ? prev.filter(s => s !== supplier)
        : [...prev, supplier]
    )
  }

  const toggleIpRating = (rating: string) => {
    setIpRatings(prev =>
      prev.includes(rating)
        ? prev.filter(r => r !== rating)
        : [...prev, rating]
    )
  }

  const hasAnyFilters = selectedTaxonomies.length > 0 || suppliers.length > 0 || indoor !== null || outdoor !== null || submersible !== null || trimless !== null || cutShapeRound !== null || cutShapeRectangular !== null || Object.keys(activeFilters).length > 0

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 via-white to-blue-50">
      {/* Header */}
      <header className="bg-white border-b border-slate-200 shadow-sm sticky top-0 z-40">
        <div className="max-w-[1600px] mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            {/* Logo and Title */}
            <div className="flex items-center gap-4">
              <div className="bg-gradient-to-br from-blue-600 to-indigo-600 p-3 rounded-xl shadow-lg">
                <Lightbulb className="w-8 h-8 text-white" />
              </div>
              <div>
                <h1 className="text-2xl font-bold bg-gradient-to-r from-slate-800 to-slate-600 bg-clip-text text-transparent">
                  Foss SA
                </h1>
                <p className="text-sm text-slate-500">Lighting Product Search</p>
              </div>
            </div>

            {/* Stats Button */}
            <button
              onClick={loadStats}
              className="flex items-center gap-2 px-4 py-2.5 bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-lg font-semibold shadow-md hover:shadow-lg hover:from-blue-700 hover:to-indigo-700 transition-all"
            >
              <BarChart3 size={18} />
              <span className="hidden sm:inline">System Stats</span>
            </button>
          </div>
        </div>
      </header>

      {/* Stats Modal */}
      {stats && showStatsModal && (
        <SystemStatsModal stats={stats} onClose={() => setShowStatsModal(false)} />
      )}

      {/* Main Content */}
      <div className="max-w-[1800px] mx-auto px-6 py-8">
        <ProductTabs onTabChange={handleTabChange}>
          {/* Three-Column Layout: Categories | Technical Filters | Location & Options */}
          <div style={{ display: 'flex', gap: '24px', marginBottom: '24px' }}>
            {/* Column 1: Categories */}
            <div style={{ flex: 1, minWidth: 0 }}>
              <FacetedCategoryNavigation
                onSelectTaxonomies={handleTaxonomiesChange}
                autoSearch={true}
                debounceMs={300}
                rootCode={activeTab}
              />
            </div>

            {/* Column 2: Technical Filters */}
            <div style={{ flex: 1, minWidth: 0 }}>
              {activeTab === 'LUMINAIRE' && selectedTaxonomies.length > 0 ? (
                <FilterPanel
                  onFilterChange={handleFilterChange}
                  taxonomyCode={activeTab}
                  selectedTaxonomies={selectedTaxonomies}
                  indoor={indoor}
                  outdoor={outdoor}
                  submersible={submersible}
                  trimless={trimless}
                  cutShapeRound={cutShapeRound}
                  cutShapeRectangular={cutShapeRectangular}
                  query={query || null}
                  suppliers={suppliers}
                />
              ) : (
                <div className="bg-gradient-to-br from-slate-50 to-white rounded-xl shadow-lg border border-slate-200 p-8 text-center">
                  <div className="text-slate-400 text-sm">
                    <div className="mb-2">🔍</div>
                    Select a category to see technical filters
                  </div>
                </div>
              )}
            </div>

            {/* Column 3: Location & Options */}
            <div style={{ flex: 1, minWidth: 0 }}>
              {/* Location Section */}
              <div className="bg-gradient-to-br from-slate-50 to-white rounded-xl shadow-lg border border-slate-200 p-6" style={{ marginBottom: '24px' }}>
                <div className="flex items-center gap-2 mb-4">
                  <div className="w-1 h-6 bg-green-500 rounded-full"></div>
                  <h3 className="font-bold text-lg text-slate-800">Location</h3>
                </div>
                <div className="space-y-3">
                  <CustomCheckbox
                    checked={indoor === true}
                    onChange={(checked) => setIndoor(checked ? true : null)}
                    label="Indoor"
                    count={flagCounts.indoor?.true_count}
                    icon={Home}
                  />
                  <CustomCheckbox
                    checked={outdoor === true}
                    onChange={(checked) => setOutdoor(checked ? true : null)}
                    label="Outdoor"
                    count={flagCounts.outdoor?.true_count}
                    icon={TreePine}
                  />
                  <CustomCheckbox
                    checked={submersible === true}
                    onChange={(checked) => setSubmersible(checked ? true : null)}
                    label="Submersible"
                    count={flagCounts.submersible?.true_count}
                    icon={Droplet}
                  />
                </div>
              </div>

              {/* Options Section */}
              <div className="bg-gradient-to-br from-slate-50 to-white rounded-xl shadow-lg border border-slate-200 p-6">
                <div className="flex items-center gap-2 mb-4">
                  <div className="w-1 h-6 bg-purple-500 rounded-full"></div>
                  <h3 className="font-bold text-lg text-slate-800">Options</h3>
                </div>
                <div className="space-y-3">
                  <CustomCheckbox
                    checked={trimless === true}
                    onChange={(checked) => setTrimless(checked ? true : null)}
                    label="Trimless"
                    count={flagCounts.trimless?.true_count}
                    icon={Scissors}
                  />
                  <CustomCheckbox
                    checked={cutShapeRound === true}
                    onChange={(checked) => setCutShapeRound(checked ? true : null)}
                    label="Round Cut"
                    count={flagCounts.cut_shape_round?.true_count}
                    icon={Circle}
                  />
                  <CustomCheckbox
                    checked={cutShapeRectangular === true}
                    onChange={(checked) => setCutShapeRectangular(checked ? true : null)}
                    label="Rectangular Cut"
                    count={flagCounts.cut_shape_rectangular?.true_count}
                    icon={Square}
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Supplier Filter Card */}
          <div className="bg-gradient-to-br from-slate-50 to-white rounded-xl shadow-lg border border-slate-200 p-6 mb-6">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-1 h-6 bg-amber-500 rounded-full"></div>
              <h3 className="font-bold text-lg text-slate-800">Suppliers</h3>
            </div>

            <div className="flex flex-wrap gap-3">
              {['Delta Light', 'Meyer Lighting'].map(supplier => (
                <label
                  key={supplier}
                  className={`
                    flex items-center gap-2 px-4 py-2.5 rounded-lg border-2 cursor-pointer transition-all font-medium
                    ${suppliers.includes(supplier)
                      ? 'bg-blue-500 text-white border-blue-600 shadow-md'
                      : 'bg-white text-slate-700 border-slate-200 hover:border-slate-300 hover:bg-slate-50'
                    }
                  `}
                >
                  <input
                    type="checkbox"
                    checked={suppliers.includes(supplier)}
                    onChange={() => toggleSupplier(supplier)}
                    className="sr-only"
                  />
                  {supplier}
                </label>
              ))}
            </div>
          </div>

          {/* Error Display */}
          {error && (
            <div className="bg-red-50 border-2 border-red-200 rounded-xl p-4 mb-6 flex items-start gap-3">
              <div className="text-red-500 font-bold text-lg">⚠</div>
              <div>
                <strong className="text-red-800 font-bold">Error:</strong>
                <p className="text-red-700 mt-1">{error}</p>
              </div>
            </div>
          )}

          {/* Active Filter Chips */}
          <ActiveFilters
            selectedTaxonomyCodes={selectedTaxonomies}
            onRemoveTaxonomy={handleRemoveTaxonomy}
            onClearAll={handleClearAllTaxonomies}
          />

          {/* Results Section */}
          <div className="mt-8">
            {/* Results Header */}
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-2xl font-bold text-slate-800">
                Products
                <span className="ml-3 text-lg font-normal text-slate-500">
                  {loading ? (
                    <span className="inline-flex items-center gap-2">
                      <div className="w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
                      Searching...
                    </span>
                  ) : (
                    <>
                      ({products.length}{hasMore ? '+' : ''})
                      {totalCount !== null && ` of ${totalCount.toLocaleString()}`}
                    </>
                  )}
                </span>
              </h2>
            </div>

            {/* Loading Skeletons */}
            {loading && products.length === 0 && (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: '24px' }}>
                {[...Array(8)].map((_, i) => (
                  <ProductCardSkeleton key={i} />
                ))}
              </div>
            )}

            {/* Empty State */}
            {!loading && products.length === 0 && (
              <EmptyState hasFilters={hasAnyFilters} />
            )}

            {/* Product Grid */}
            {products.length > 0 && (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: '24px' }}>
                {products.map((product) => (
                  <ProductCard key={product.product_id} product={product} />
                ))}
              </div>
            )}

            {/* Load More Button */}
            {hasMore && products.length > 0 && (
              <div className="flex justify-center mt-12">
                <button
                  onClick={loadMore}
                  disabled={loading}
                  className="px-8 py-3 bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-xl font-semibold shadow-lg hover:shadow-xl hover:from-blue-700 hover:to-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                >
                  {loading ? (
                    <span className="flex items-center gap-2">
                      <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      Loading...
                    </span>
                  ) : (
                    'Load More (24 more)'
                  )}
                </button>
              </div>
            )}
          </div>
        </ProductTabs>
      </div>
    </div>
  )
}
