'use server'

import { createClient } from '@supabase/supabase-js'

// Server-side Supabase client with service role key
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!

if (!supabaseUrl || !supabaseServiceKey) {
  throw new Error('Missing Supabase environment variables')
}

const supabaseServer = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

// =====================================================================
// TYPE DEFINITIONS
// =====================================================================

export interface SearchFilters {
  query?: string
  indoor?: boolean
  outdoor?: boolean
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
  sortBy?: 'relevance' | 'price_asc' | 'price_desc' | 'power_asc' | 'power_desc'
  limit?: number
  offset?: number
}

export interface SearchProduct {
  product_id: string
  foss_pid: string
  description_short: string
  description_long: string | null
  supplier_name: string
  class_name: string | null
  price: number | null
  image_url: string | null
  taxonomy_path: string[]
  flags: {
    indoor: boolean
    outdoor: boolean
    ceiling: boolean
    wall: boolean
    pendant: boolean
    recessed: boolean
    dimmable: boolean
  }
  key_features: {
    power: number | null
    color_temp: number | null
    luminous_flux: number | null
    ip_rating: string | null
  }
  relevance_score: number
}

export interface SearchStatistics {
  total_products: number
  indoor_products: number
  outdoor_products: number
  dimmable_products: number
  filter_entries: number
  taxonomy_nodes: number
  classification_rules: number
  filter_definitions: number
}

export interface FacetData {
  filter_key: string
  filter_type: 'boolean' | 'numeric_range' | 'alphanumeric'
  label_el: string
  label_en: string
  facet_data: {
    min?: number
    max?: number
    avg?: number
    count?: number
    values?: Array<{
      value: string
      count: number
    }>
  }
}

export interface TaxonomyNode {
  code: string
  parent_code: string | null
  level: number
  name_el: string
  name_en: string
  product_count: number
  icon: string | null
}

// =====================================================================
// INPUT VALIDATION
// =====================================================================

function validateSearchFilters(filters: SearchFilters): SearchFilters {
  const validated: SearchFilters = {}

  // Text query validation
  if (filters.query !== undefined && filters.query !== null) {
    const trimmed = String(filters.query).trim().slice(0, 200)
    if (trimmed.length > 0) {
      validated.query = trimmed
    }
  }

  // Boolean flags - ensure they're actually boolean or undefined
  const booleanFlags = ['indoor', 'outdoor', 'ceiling', 'wall', 'pendant', 'recessed', 'dimmable'] as const
  for (const flag of booleanFlags) {
    if (filters[flag] === true || filters[flag] === false) {
      validated[flag] = filters[flag]
    }
  }

  // Numeric ranges - validate they're positive numbers
  if (filters.powerMin !== undefined && filters.powerMin !== null) {
    const val = Number(filters.powerMin)
    if (!isNaN(val) && val >= 0 && val <= 10000) {
      validated.powerMin = val
    }
  }
  if (filters.powerMax !== undefined && filters.powerMax !== null) {
    const val = Number(filters.powerMax)
    if (!isNaN(val) && val >= 0 && val <= 10000) {
      validated.powerMax = val
    }
  }

  if (filters.colorTempMin !== undefined && filters.colorTempMin !== null) {
    const val = Number(filters.colorTempMin)
    if (!isNaN(val) && val >= 0 && val <= 10000) {
      validated.colorTempMin = val
    }
  }
  if (filters.colorTempMax !== undefined && filters.colorTempMax !== null) {
    const val = Number(filters.colorTempMax)
    if (!isNaN(val) && val >= 0 && val <= 10000) {
      validated.colorTempMax = val
    }
  }

  // IP Ratings array - validate each value
  if (Array.isArray(filters.ipRatings) && filters.ipRatings.length > 0) {
    const validIpPattern = /^IP\d{2}$/i
    validated.ipRatings = filters.ipRatings
      .filter(ip => typeof ip === 'string' && validIpPattern.test(ip))
      .slice(0, 20) // Max 20 IP ratings
  }

  // Sort by validation
  const validSortOptions = ['relevance', 'price_asc', 'price_desc', 'power_asc', 'power_desc']
  if (filters.sortBy && validSortOptions.includes(filters.sortBy)) {
    validated.sortBy = filters.sortBy
  } else {
    validated.sortBy = 'relevance'
  }

  // Pagination validation
  if (filters.limit !== undefined && filters.limit !== null) {
    const val = Number(filters.limit)
    if (!isNaN(val) && val > 0 && val <= 100) {
      validated.limit = val
    } else {
      validated.limit = 24
    }
  } else {
    validated.limit = 24
  }

  if (filters.offset !== undefined && filters.offset !== null) {
    const val = Number(filters.offset)
    if (!isNaN(val) && val >= 0) {
      validated.offset = val
    } else {
      validated.offset = 0
    }
  } else {
    validated.offset = 0
  }

  return validated
}

// =====================================================================
// SERVER ACTIONS
// =====================================================================

/**
 * Search products with filters
 *
 * @param filters - Search filters including text query, boolean flags, numeric ranges
 * @returns Array of matching products with relevance scores
 */
export async function searchProductsServerAction(
  filters: SearchFilters = {}
): Promise<SearchProduct[]> {
  try {
    const validated = validateSearchFilters(filters)

    const { data, error } = await supabaseServer.rpc('search_products', {
      p_query: validated.query || null,
      p_indoor: validated.indoor ?? null,
      p_outdoor: validated.outdoor ?? null,
      p_ceiling: validated.ceiling ?? null,
      p_wall: validated.wall ?? null,
      p_pendant: validated.pendant ?? null,
      p_recessed: validated.recessed ?? null,
      p_dimmable: validated.dimmable ?? null,
      p_power_min: validated.powerMin ?? null,
      p_power_max: validated.powerMax ?? null,
      p_color_temp_min: validated.colorTempMin ?? null,
      p_color_temp_max: validated.colorTempMax ?? null,
      p_ip_ratings: validated.ipRatings ?? null,
      p_sort_by: validated.sortBy || 'relevance',
      p_limit: validated.limit || 24,
      p_offset: validated.offset || 0
    })

    if (error) {
      console.error('Search products error:', error)
      return []
    }

    return data || []
  } catch (error) {
    console.error('Search products action error:', error)
    return []
  }
}

/**
 * Get search system statistics
 *
 * @returns Statistics about indexed products and filters
 */
export async function getSearchStatisticsServerAction(): Promise<SearchStatistics | null> {
  try {
    const { data, error } = await supabaseServer.rpc('get_search_statistics')

    if (error) {
      console.error('Get statistics error:', error)
      return null
    }

    if (!data || !Array.isArray(data)) {
      return null
    }

    // Convert array of {stat_name, stat_value} to object
    const stats: Record<string, number> = {}
    for (const row of data) {
      stats[row.stat_name] = Number(row.stat_value) || 0
    }

    return {
      total_products: stats.total_products || 0,
      indoor_products: stats.indoor_products || 0,
      outdoor_products: stats.outdoor_products || 0,
      dimmable_products: stats.dimmable_products || 0,
      filter_entries: stats.filter_entries || 0,
      taxonomy_nodes: stats.taxonomy_nodes || 0,
      classification_rules: stats.classification_rules || 0,
      filter_definitions: stats.filter_definitions || 0
    }
  } catch (error) {
    console.error('Get statistics action error:', error)
    return null
  }
}

/**
 * Get available facets for filters
 *
 * @returns Available filter facets with counts and value distributions
 */
export async function getAvailableFacetsServerAction(): Promise<FacetData[]> {
  try {
    const { data, error } = await supabaseServer.rpc('get_available_facets')

    if (error) {
      console.error('Get facets error:', error)
      return []
    }

    return data || []
  } catch (error) {
    console.error('Get facets action error:', error)
    return []
  }
}

/**
 * Get taxonomy tree structure
 *
 * @returns Hierarchical taxonomy tree with product counts
 */
export async function getTaxonomyTreeServerAction(): Promise<TaxonomyNode[]> {
  try {
    const { data, error } = await supabaseServer.rpc('get_taxonomy_tree')

    if (error) {
      console.error('Get taxonomy error:', error)
      return []
    }

    return data || []
  } catch (error) {
    console.error('Get taxonomy action error:', error)
    return []
  }
}

// =====================================================================
// HELPER FUNCTIONS FOR EXISTING FOSSAPP CODE
// =====================================================================

/**
 * Simple search function matching existing FOSSAPP pattern
 * Can be used as drop-in replacement for searchProductsAction
 *
 * @param query - Text search query
 * @returns Array of products matching the query
 */
export async function searchProductsCompatAction(query: string): Promise<SearchProduct[]> {
  try {
    // Validate query similar to existing pattern
    if (!query || typeof query !== 'string') {
      return []
    }

    const sanitized = query.trim().slice(0, 100)
    if (sanitized.length === 0) {
      return []
    }

    // Use search with just query parameter
    return await searchProductsServerAction({ query: sanitized, limit: 50 })
  } catch (error) {
    console.error('Search products compat error:', error)
    return []
  }
}
