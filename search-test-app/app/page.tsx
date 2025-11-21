'use client'

import { useState, useEffect, useCallback } from 'react'
import { supabase } from '@/lib/supabase'
import { Search, BarChart3 } from 'lucide-react'
import FacetedCategoryNavigation from '@/components/FacetedCategoryNavigation'
import ActiveFilters from '@/components/ActiveFilters'
import ProductTabs from '@/components/ProductTabs'
import FilterPanel from '@/components/FilterPanel'

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
    setActiveFilters(filters)
  }, [])

  const getTotalCount = async () => {
    try {
      const combinedTaxonomies = getCombinedTaxonomies()
      console.log('📊 Calling count RPC with params:', {
        p_indoor: indoor,
        p_outdoor: outdoor,
        p_submersible: submersible,
        p_taxonomy_codes: combinedTaxonomies
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
        p_taxonomy_codes: combinedTaxonomies,
        p_indoor: indoor,
        p_outdoor: outdoor,
        p_submersible: submersible,
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

  return (
    <div className="min-h-screen pb-12">
      {/* Header */}
      <div className="bg-gradient-to-r from-blue-600 to-blue-500 text-white shadow-xl">
        <div className="max-w-7xl mx-auto px-6 py-8">
          <h1 className="text-4xl font-bold mb-2">Foss SA Product Search</h1>
          <p className="text-blue-100">Professional lighting catalog search system</p>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-6 py-6">
        {/* Search Bar */}
        <div className="mb-6">
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search products by name, description, or features..."
            className="w-full px-4 py-3 text-base rounded-lg border-2 border-slate-200
                       focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20
                       transition-all duration-200 bg-white shadow-sm"
          />
        </div>

        {/* System Stats Toggle */}
        <div className="mb-6">
          <button
            onClick={loadStats}
            className="bg-white hover:bg-blue-50 text-blue-600 px-6 py-3 rounded-lg
                       font-semibold border-2 border-blue-200 hover:border-blue-400
                       transition-all duration-200 shadow-sm hover:shadow-md"
          >
            {stats ? 'Refresh Statistics' : 'Load System Statistics'}
          </button>
        </div>

        {stats && (
          <div className="bg-gradient-to-br from-blue-50 to-white p-6 rounded-xl mb-6 shadow-lg border border-blue-100">
            <h3 className="text-xl font-bold mb-4 text-slate-800 flex items-center gap-2">
              <BarChart3 className="w-5 h-5 text-blue-600" />
              System Statistics
            </h3>
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
              <div className="bg-white p-4 rounded-lg border border-slate-200">
                <div className="text-sm text-slate-600 mb-1">Total Products</div>
                <div className="text-2xl font-bold text-slate-800">{stats.total_products?.toLocaleString()}</div>
              </div>
              <div className="bg-white p-4 rounded-lg border border-slate-200">
                <div className="text-sm text-slate-600 mb-1">Indoor</div>
                <div className="text-2xl font-bold text-blue-600">{stats.indoor_products?.toLocaleString()}</div>
              </div>
              <div className="bg-white p-4 rounded-lg border border-slate-200">
                <div className="text-sm text-slate-600 mb-1">Outdoor</div>
                <div className="text-2xl font-bold text-green-600">{stats.outdoor_products?.toLocaleString()}</div>
              </div>
              <div className="bg-white p-4 rounded-lg border border-slate-200">
                <div className="text-sm text-slate-600 mb-1">Dimmable</div>
                <div className="text-2xl font-bold text-purple-600">{stats.dimmable_products?.toLocaleString()}</div>
              </div>
              <div className="bg-white p-4 rounded-lg border border-slate-200">
                <div className="text-sm text-slate-600 mb-1">Filter Entries</div>
                <div className="text-2xl font-bold text-slate-800">{stats.filter_entries?.toLocaleString()}</div>
              </div>
              <div className="bg-white p-4 rounded-lg border border-slate-200">
                <div className="text-sm text-slate-600 mb-1">Categories</div>
                <div className="text-2xl font-bold text-slate-800">{stats.taxonomy_nodes?.toLocaleString()}</div>
              </div>
            </div>
          </div>
        )}

      <ProductTabs onTabChange={handleTabChange}>
        {/* Three-Column Layout: Categories (left), Delta-Style Filters (middle), Location/Options (right) */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
          {/* Left Column: Fixation Categories */}
          <div className="filter-category p-5">
            <h3 className="text-lg font-bold mb-4 text-slate-800">Product Categories</h3>
            <FacetedCategoryNavigation
              onSelectTaxonomies={handleTaxonomiesChange}
              autoSearch={true}
              debounceMs={300}
              rootCode={activeTab}
            />
          </div>

          {/* Middle Column: Delta-Style Filters (Only shown when category is selected) */}
          {activeTab === 'LUMINAIRE' && selectedTaxonomies.length > 0 && (
            <div className="filter-category p-5">
              <h3 className="text-lg font-bold mb-4 text-slate-800">Technical Filters</h3>
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
            </div>
          )}

          {/* Right Column: Location & Options (Only shown when category is selected) */}
          {activeTab === 'LUMINAIRE' && selectedTaxonomies.length > 0 && (
            <div className="filter-category p-5">
              {/* Location Toggle Switches */}
              <div className="mb-6">
                <h3 className="text-lg font-bold mb-4 text-slate-800">Location</h3>
                <div className="space-y-3">
                  <label className="flex items-center gap-3 cursor-pointer p-3 rounded-lg hover:bg-slate-50 transition-colors">
                    <input
                      type="checkbox"
                      checked={indoor === true}
                      onChange={(e) => setIndoor(e.target.checked ? true : null)}
                      className="cursor-pointer"
                    />
                    <span className="flex-1 font-medium">Indoor</span>
                    {flagCounts.indoor && (
                      <span className="text-sm text-slate-500">{flagCounts.indoor.true_count.toLocaleString()}</span>
                    )}
                  </label>
                  <label className="flex items-center gap-3 cursor-pointer p-3 rounded-lg hover:bg-slate-50 transition-colors">
                    <input
                      type="checkbox"
                      checked={outdoor === true}
                      onChange={(e) => setOutdoor(e.target.checked ? true : null)}
                      className="cursor-pointer"
                    />
                    <span className="flex-1 font-medium">Outdoor</span>
                    {flagCounts.outdoor && (
                      <span className="text-sm text-slate-500">{flagCounts.outdoor.true_count.toLocaleString()}</span>
                    )}
                  </label>
                  <label className="flex items-center gap-3 cursor-pointer p-3 rounded-lg hover:bg-slate-50 transition-colors">
                    <input
                      type="checkbox"
                      checked={submersible === true}
                      onChange={(e) => setSubmersible(e.target.checked ? true : null)}
                      className="cursor-pointer"
                    />
                    <span className="flex-1 font-medium">Submersible</span>
                    {flagCounts.submersible && (
                      <span className="text-sm text-slate-500">{flagCounts.submersible.true_count.toLocaleString()}</span>
                    )}
                  </label>
                </div>
              </div>

              {/* Options Section */}
              <div>
                <h3 className="text-lg font-bold mb-4 text-slate-800">Options</h3>
                <div className="space-y-3">
                  <label className="flex items-center gap-3 cursor-pointer p-3 rounded-lg hover:bg-slate-50 transition-colors">
                    <input
                      type="checkbox"
                      checked={trimless === true}
                      onChange={(e) => setTrimless(e.target.checked ? true : null)}
                      className="cursor-pointer"
                    />
                    <span className="flex-1 font-medium">Trimless</span>
                    {flagCounts.trimless && (
                      <span className="text-sm text-slate-500">{flagCounts.trimless.true_count.toLocaleString()}</span>
                    )}
                  </label>
                  <label className="flex items-center gap-3 cursor-pointer p-3 rounded-lg hover:bg-slate-50 transition-colors">
                    <input
                      type="checkbox"
                      checked={cutShapeRound === true}
                      onChange={(e) => setCutShapeRound(e.target.checked ? true : null)}
                      className="cursor-pointer"
                    />
                    <span className="flex-1 font-medium">Cut Shape: Round</span>
                    {flagCounts.cut_shape_round && (
                      <span className="text-sm text-slate-500">{flagCounts.cut_shape_round.true_count.toLocaleString()}</span>
                    )}
                  </label>
                  <label className="flex items-center gap-3 cursor-pointer p-3 rounded-lg hover:bg-slate-50 transition-colors">
                    <input
                      type="checkbox"
                      checked={cutShapeRectangular === true}
                      onChange={(e) => setCutShapeRectangular(e.target.checked ? true : null)}
                      className="cursor-pointer"
                    />
                    <span className="flex-1 font-medium">Cut Shape: Rectangular</span>
                    {flagCounts.cut_shape_rectangular && (
                      <span className="text-sm text-slate-500">{flagCounts.cut_shape_rectangular.true_count.toLocaleString()}</span>
                    )}
                  </label>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Supplier Filter */}
        <div className="bg-white p-5 rounded-xl shadow-sm border border-slate-200 mb-6">
          <h2 className="text-lg font-bold mb-4 text-slate-800">Suppliers</h2>
          <div className="flex gap-3 flex-wrap">
            {['Delta Light', 'Meyer Lighting'].map(supplier => (
              <label
                key={supplier}
                className={`px-4 py-2 rounded-lg border-2 cursor-pointer transition-all duration-200 font-medium
                  ${suppliers.includes(supplier)
                    ? 'bg-blue-600 border-blue-600 text-white shadow-md'
                    : 'bg-white border-slate-300 text-slate-700 hover:border-blue-400 hover:bg-blue-50'
                  }`}
              >
                <input
                  type="checkbox"
                  checked={suppliers.includes(supplier)}
                  onChange={() => toggleSupplier(supplier)}
                  className="hidden"
                />
                {supplier}
              </label>
            ))}
          </div>
          {loading && (
            <div className="text-center text-blue-600 italic mt-4 flex items-center justify-center gap-2">
              <svg className="animate-spin h-5 w-5" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Searching...
            </div>
          )}
        </div>

        {/* Error Display */}
        {error && (
          <div className="bg-red-50 border-2 border-red-200 text-red-800 p-5 rounded-xl mb-6 shadow-sm">
            <div className="flex items-start gap-3">
              <svg className="w-6 h-6 text-red-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <div>
                <strong className="font-bold">Error:</strong> {error}
              </div>
            </div>
          </div>
        )}

        {/* Active Filter Chips */}
        <ActiveFilters
          selectedTaxonomyCodes={selectedTaxonomies}
          onRemoveTaxonomy={handleRemoveTaxonomy}
          onClearAll={handleClearAllTaxonomies}
        />

        {/* Results */}
        <div className="mt-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-2xl font-bold text-slate-800">
              Search Results
              <span className="ml-3 text-lg font-normal text-slate-600">
                ({products.length}{hasMore ? '+' : ''})
                {totalCount !== null && ` of ${totalCount.toLocaleString()}`}
              </span>
            </h2>
          </div>

          {products.length === 0 && !loading && (
            <div className="text-center py-16 bg-white rounded-xl border-2 border-dashed border-slate-300">
              <svg className="w-16 h-16 mx-auto text-slate-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <p className="text-lg text-slate-600">No products found</p>
              <p className="text-sm text-slate-500 mt-2">Try adjusting your filters or search terms</p>
            </div>
          )}

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {products.map((product) => (
              <div key={product.product_id} className="product-card group">
                {/* Product ID */}
                <div className="font-bold text-slate-800 mb-3 text-sm">
                  {product.foss_pid}
                </div>

                {/* Description */}
                <div className="text-sm text-slate-700 mb-3 line-clamp-2">
                  {product.description_short}
                </div>

                {/* Supplier and Class */}
                <div className="text-xs text-slate-500 mb-3">
                  {product.supplier_name} | {product.class_name}
                </div>

                {/* Price */}
                {product.price && (
                  <div className="text-lg font-bold text-green-600 mb-4">
                    €{product.price.toFixed(2)}
                  </div>
                )}

                {/* Flags */}
                <div className="flex flex-wrap gap-1 mb-3">
                  {product.flags.indoor && <span className="badge text-xs">🏠 Indoor</span>}
                  {product.flags.outdoor && <span className="badge text-xs">🌳 Outdoor</span>}
                  {product.flags.submersible && <span className="badge text-xs">🌊 Submersible</span>}
                  {product.flags.trimless && <span className="badge text-xs">✂️ Trimless</span>}
                  {product.flags.cut_shape_round && <span className="badge text-xs">⭕ Round</span>}
                  {product.flags.cut_shape_rectangular && <span className="badge text-xs">▭ Rect</span>}
                  {product.flags.ceiling && <span className="badge text-xs">⬆️ Ceiling</span>}
                  {product.flags.wall && <span className="badge text-xs">◾ Wall</span>}
                  {product.flags.floor && <span className="badge text-xs">🔦 Floor</span>}
                  {product.flags.recessed && <span className="badge text-xs">⬇️ Recessed</span>}
                  {product.flags.surface_mounted && <span className="badge text-xs">⬛ Surface</span>}
                  {product.flags.suspended && <span className="badge text-xs">🔗 Suspended</span>}
                </div>

                {/* Key Features */}
                <div className="text-xs text-slate-600 space-y-1">
                  {product.key_features.power && (
                    <div className="flex items-center gap-2">
                      <span className="font-medium">⚡ Power:</span>
                      <span>{product.key_features.power}W</span>
                    </div>
                  )}
                  {product.key_features.color_temp && (
                    <div className="flex items-center gap-2">
                      <span className="font-medium">🌡️ Color:</span>
                      <span>{product.key_features.color_temp}K</span>
                    </div>
                  )}
                  {product.key_features.ip_rating && (
                    <div className="flex items-center gap-2">
                      <span className="font-medium">🛡️ IP:</span>
                      <span>{product.key_features.ip_rating}</span>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>

          {/* Load More Button */}
          {hasMore && products.length > 0 && (
            <div className="text-center mt-8">
              <button
                onClick={loadMore}
                disabled={loading}
                className="bg-blue-600 hover:bg-blue-700 text-white px-8 py-3 rounded-lg
                           font-semibold shadow-md hover:shadow-lg transition-all duration-200
                           disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? 'Loading...' : 'Load More (24 more)'}
              </button>
            </div>
          )}
        </div>
      </ProductTabs>
      </div>
    </div>
  )
}
