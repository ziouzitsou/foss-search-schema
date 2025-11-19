'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

export default function TestFiltersPage() {
  const [filterDefs, setFilterDefs] = useState<any[]>([])
  const [facets, setFacets] = useState<any[]>([])
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    testConnection()
  }, [])

  const testConnection = async () => {
    try {
      setLoading(true)
      setError(null)

      // Test 1: Get filter definitions
      console.log('Testing filter_definitions...')
      const { data: defs, error: defError } = await supabase
        .from('filter_definitions')
        .select('*')
        .eq('active', true)
        .order('display_order')

      if (defError) {
        console.error('Filter definitions error:', defError)
        throw new Error(`Filter definitions: ${defError.message}`)
      }

      console.log('Filter definitions:', defs)
      setFilterDefs(defs || [])

      // Test 2: Get filter facets
      console.log('Testing filter_facets...')
      const { data: facetsData, error: facetsError } = await supabase
        .from('filter_facets')
        .select('*')
        .limit(10)

      if (facetsError) {
        console.error('Filter facets error:', facetsError)
        throw new Error(`Filter facets: ${facetsError.message}`)
      }

      console.log('Filter facets:', facetsData)
      setFacets(facetsData || [])

    } catch (err: any) {
      console.error('Test failed:', err)
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="p-8 max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold mb-4">🧪 Filter Database Connection Test</h1>

      {loading && (
        <div className="bg-blue-50 p-4 rounded">
          <p>⏳ Testing database connection...</p>
        </div>
      )}

      {error && (
        <div className="bg-red-50 border border-red-200 p-4 rounded mb-4">
          <h2 className="font-bold text-red-800 mb-2">❌ Error</h2>
          <pre className="text-sm text-red-700">{error}</pre>
        </div>
      )}

      {!loading && !error && (
        <div className="space-y-4">
          <div className="bg-green-50 border border-green-200 p-4 rounded">
            <h2 className="font-bold text-green-800 mb-2">✅ Connection Successful!</h2>
          </div>

          <div className="bg-white border p-4 rounded">
            <h2 className="font-bold mb-2">Filter Definitions ({filterDefs.length})</h2>
            <div className="space-y-2">
              {filterDefs.map(def => (
                <div key={def.filter_key} className="text-sm p-2 bg-gray-50 rounded">
                  <strong>{def.label}</strong> ({def.filter_type})
                  <span className="text-gray-500 ml-2">- {def.ui_config?.filter_category}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="bg-white border p-4 rounded">
            <h2 className="font-bold mb-2">Filter Facets (first 10)</h2>
            <div className="space-y-2">
              {facets.map((facet, idx) => (
                <div key={idx} className="text-sm p-2 bg-gray-50 rounded">
                  <strong>{facet.filter_label}:</strong> {facet.filter_value}
                  <span className="text-gray-500 ml-2">({facet.product_count} products)</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      <div className="mt-8 p-4 bg-gray-50 rounded">
        <h3 className="font-bold mb-2">Connection Info:</h3>
        <p className="text-sm">Supabase URL: {process.env.NEXT_PUBLIC_SUPABASE_URL}</p>
        <p className="text-sm">API Key: {process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.substring(0, 20)}...</p>
      </div>
    </div>
  )
}
