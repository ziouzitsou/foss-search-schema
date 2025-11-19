'use client'

import { useState, useEffect, useCallback } from 'react'
import { supabase } from '@/lib/supabase'
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
      trimless, cutShapeRound, cutShapeRectangular
    })
    handleSearch()
  }, [selectedTaxonomies, activeTab, suppliers, indoor, outdoor, submersible, trimless, cutShapeRound, cutShapeRectangular]) // eslint-disable-line react-hooks/exhaustive-deps

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
    <div className="p-5 max-w-7xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">🔍 Foss SA Search Test</h1>

      <button onClick={loadStats} className="mb-4 bg-blue-600 text-white px-5 py-2.5 rounded font-bold hover:bg-blue-700">
        Load System Stats
      </button>

      {stats && (
        <div className="bg-blue-50 p-5 rounded-lg mb-5 shadow-sm">
          <h3 className="text-xl font-bold mb-3">📊 System Statistics</h3>
          <div className="grid grid-cols-[repeat(auto-fit,minmax(200px,1fr))] gap-2.5">
            <div><strong>Total Products:</strong> {stats.total_products}</div>
            <div><strong>Indoor:</strong> {stats.indoor_products}</div>
            <div><strong>Outdoor:</strong> {stats.outdoor_products}</div>
            <div><strong>Dimmable:</strong> {stats.dimmable_products}</div>
            <div><strong>Filter Entries:</strong> {stats.filter_entries}</div>
            <div><strong>Taxonomy Nodes:</strong> {stats.taxonomy_nodes}</div>
          </div>
        </div>
      )}

      <ProductTabs onTabChange={handleTabChange}>
        {/* Three-Column Layout: Categories (left), Delta-Style Filters (middle), Location/Options (right) */}
        <div style={{ display: 'flex', gap: '20px', marginBottom: '20px' }}>
          {/* Left Column: Fixation Categories */}
          <div style={{ flex: '1', minWidth: '250px', maxWidth: '300px' }}>
            <FacetedCategoryNavigation
              onSelectTaxonomies={handleTaxonomiesChange}
              autoSearch={true}
              debounceMs={300}
              rootCode={activeTab}
            />
          </div>

          {/* Middle Column: Delta-Style Filters (Only shown when category is selected) */}
          {activeTab === 'LUMINAIRE' && selectedTaxonomies.length > 0 && (
            <div style={{ flex: '1', minWidth: '300px', maxWidth: '400px' }}>
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
            <div style={{ flex: '1', minWidth: '250px', maxWidth: '300px' }}>
              {/* Location Toggle Switches */}
              <div style={{ marginBottom: '20px' }}>
                <h3 style={{ fontSize: '14px', fontWeight: 'bold', marginBottom: '10px' }}>Location</h3>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={indoor === true}
                      onChange={(e) => setIndoor(e.target.checked ? true : null)}
                      style={{ width: '40px', height: '20px', cursor: 'pointer' }}
                    />
                    <span>Indoor {flagCounts.indoor && `(${flagCounts.indoor.true_count.toLocaleString()})`}</span>
                  </label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={outdoor === true}
                      onChange={(e) => setOutdoor(e.target.checked ? true : null)}
                      style={{ width: '40px', height: '20px', cursor: 'pointer' }}
                    />
                    <span>Outdoor {flagCounts.outdoor && `(${flagCounts.outdoor.true_count.toLocaleString()})`}</span>
                  </label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={submersible === true}
                      onChange={(e) => setSubmersible(e.target.checked ? true : null)}
                      style={{ width: '40px', height: '20px', cursor: 'pointer' }}
                    />
                    <span>Submersible {flagCounts.submersible && `(${flagCounts.submersible.true_count.toLocaleString()})`}</span>
                  </label>
                </div>
              </div>

              {/* Options Section */}
              <div style={{ marginBottom: '20px' }}>
                <h3 style={{ fontSize: '14px', fontWeight: 'bold', marginBottom: '10px' }}>Options</h3>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={trimless === true}
                      onChange={(e) => setTrimless(e.target.checked ? true : null)}
                      style={{ width: '40px', height: '20px', cursor: 'pointer' }}
                    />
                    <span>Trimless {flagCounts.trimless && `(${flagCounts.trimless.true_count.toLocaleString()})`}</span>
                  </label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={cutShapeRound === true}
                      onChange={(e) => setCutShapeRound(e.target.checked ? true : null)}
                      style={{ width: '40px', height: '20px', cursor: 'pointer' }}
                    />
                    <span>Cut Shape: Round {flagCounts.cut_shape_round && `(${flagCounts.cut_shape_round.true_count.toLocaleString()})`}</span>
                  </label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={cutShapeRectangular === true}
                      onChange={(e) => setCutShapeRectangular(e.target.checked ? true : null)}
                      style={{ width: '40px', height: '20px', cursor: 'pointer' }}
                    />
                    <span>Cut Shape: Rectangular {flagCounts.cut_shape_rectangular && `(${flagCounts.cut_shape_rectangular.true_count.toLocaleString()})`}</span>
                  </label>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Search Filters Below */}
        <div style={cardStyle}>
          <h2>Search Filters</h2>

          {/* Supplier Filter */}
          <div style={{ marginBottom: '15px' }}>
            <label style={labelStyle}>Supplier:</label>
            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
              {['Delta Light', 'Meyer Lighting'].map(supplier => (
                <label key={supplier} style={{
                  padding: '5px 10px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  background: suppliers.includes(supplier) ? '#3b82f6' : 'white',
                  color: suppliers.includes(supplier) ? 'white' : 'black',
                  cursor: 'pointer'
                }}>
                  <input
                    type="checkbox"
                    checked={suppliers.includes(supplier)}
                    onChange={() => toggleSupplier(supplier)}
                    style={{ marginRight: '5px' }}
                  />
                  {supplier}
                </label>
              ))}
            </div>
          </div>

        {/* Auto-filtering enabled - no manual search button needed */}
        {loading && (
          <div style={{ textAlign: 'center', color: '#3b82f6', fontStyle: 'italic', marginTop: '10px' }}>
            ⚡ Searching...
          </div>
        )}
      </div>

      {/* Error Display */}
      {error && (
        <div style={{ ...cardStyle, background: '#fee2e2', color: '#991b1b' }}>
          <strong>Error:</strong> {error}
        </div>
      )}

      {/* Active Filter Chips */}
      <ActiveFilters
        selectedTaxonomyCodes={selectedTaxonomies}
        onRemoveTaxonomy={handleRemoveTaxonomy}
        onClearAll={handleClearAllTaxonomies}
      />

      {/* Results */}
      <div style={{ marginTop: '20px' }}>
        <h2>
          Results ({products.length}{hasMore ? '+' : ''})
          {totalCount !== null && ` of total ${totalCount}`}
        </h2>

        {products.length === 0 && !loading && (
          <p style={{ color: '#666' }}>No products found. Try adjusting your filters.</p>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '15px' }}>
          {products.map((product) => (
            <div key={product.product_id} style={productCardStyle}>
              <div style={{ fontWeight: 'bold', marginBottom: '5px' }}>
                {product.foss_pid}
              </div>
              {product.image_url && (
                <div style={{ marginBottom: '10px', height: '200px', overflow: 'hidden', borderRadius: '4px', backgroundColor: '#f3f4f6', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <img
                    src={product.image_url}
                    alt={product.foss_pid}
                    style={{
                      width: '100%',
                      height: '100%',
                      objectFit: 'cover',
                      objectPosition: 'center'
                    }}
                  />
                </div>
              )}
              <div style={{ fontSize: '14px', marginBottom: '10px' }}>
                {product.description_short}
              </div>
              <div style={{ fontSize: '12px', color: '#666', marginBottom: '5px' }}>
                {product.supplier_name} | {product.class_name}
              </div>
              {product.price && (
                <div style={{ fontSize: '16px', fontWeight: 'bold', color: '#16a34a', marginBottom: '10px' }}>
                  €{product.price.toFixed(2)}
                </div>
              )}

              {/* Flags */}
              <div style={{ fontSize: '11px', marginBottom: '5px' }}>
                {product.flags.indoor && <span style={badgeStyle}>🏠 Indoor</span>}
                {product.flags.outdoor && <span style={badgeStyle}>🌳 Outdoor</span>}
                {product.flags.submersible && <span style={badgeStyle}>🌊 Submersible</span>}
                {product.flags.trimless && <span style={badgeStyle}>✂️ Trimless</span>}
                {product.flags.cut_shape_round && <span style={badgeStyle}>⭕ Round Cut</span>}
                {product.flags.cut_shape_rectangular && <span style={badgeStyle}>▭ Rect Cut</span>}
                {product.flags.ceiling && <span style={badgeStyle}>⬆️ Ceiling</span>}
                {product.flags.wall && <span style={badgeStyle}>◾ Wall</span>}
                {product.flags.floor && <span style={badgeStyle}>🔦 Floor</span>}
                {product.flags.recessed && <span style={badgeStyle}>⬇️ Recessed</span>}
                {product.flags.surface_mounted && <span style={badgeStyle}>⬛ Surface</span>}
                {product.flags.suspended && <span style={badgeStyle}>🔗 Suspended</span>}
              </div>

              {/* Key Features */}
              <div style={{ fontSize: '11px', color: '#666' }}>
                {product.key_features.power && <div>⚡ {product.key_features.power}W</div>}
                {product.key_features.color_temp && <div>🌡️ {product.key_features.color_temp}K</div>}
                {product.key_features.ip_rating && <div>🛡️ {product.key_features.ip_rating}</div>}
              </div>
            </div>
          ))}
        </div>

        {/* Load More Button */}
        {hasMore && products.length > 0 && (
          <div style={{ textAlign: 'center', marginTop: '20px' }}>
            <button onClick={loadMore} disabled={loading} style={buttonStyle}>
              {loading ? 'Loading...' : 'Load More (24 more)'}
            </button>
          </div>
        )}
      </div>
      </ProductTabs>
    </div>
  )
}

const cardStyle = {
  background: 'white',
  padding: '20px',
  borderRadius: '8px',
  boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
  marginBottom: '20px'
}

const labelStyle = {
  display: 'block',
  fontWeight: 'bold',
  marginBottom: '8px'
}

const inputStyle = {
  width: '100%',
  padding: '8px 12px',
  border: '1px solid #ddd',
  borderRadius: '4px',
  fontSize: '14px'
}

const buttonStyle = {
  background: '#3b82f6',
  color: 'white',
  padding: '10px 20px',
  border: 'none',
  borderRadius: '4px',
  cursor: 'pointer',
  fontSize: '16px',
  fontWeight: 'bold'
}

const productCardStyle = {
  background: 'white',
  padding: '15px',
  borderRadius: '8px',
  boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
  border: '1px solid #e5e7eb'
}

const badgeStyle = {
  display: 'inline-block',
  padding: '2px 6px',
  marginRight: '4px',
  marginBottom: '4px',
  background: '#eff6ff',
  borderRadius: '4px',
  fontSize: '10px'
}
