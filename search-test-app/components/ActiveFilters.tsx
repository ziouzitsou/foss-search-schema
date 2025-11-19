'use client'

import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'

type ActiveFiltersProps = {
  selectedTaxonomyCodes: string[]
  onRemoveTaxonomy: (code: string) => void
  onClearAll: () => void
}

type TaxonomyInfo = {
  code: string
  name: string
  full_path: string // Formatted path like "Luminaires > Ceiling > Recessed"
}

export default function ActiveFilters({
  selectedTaxonomyCodes,
  onRemoveTaxonomy,
  onClearAll
}: ActiveFiltersProps) {
  const [taxonomyInfo, setTaxonomyInfo] = useState<Map<string, TaxonomyInfo>>(new Map())
  const [loading, setLoading] = useState(false)

  // Load taxonomy names for selected codes
  useEffect(() => {
    if (selectedTaxonomyCodes.length === 0) {
      setTaxonomyInfo(new Map())
      return
    }

    const loadTaxonomyInfo = async () => {
      setLoading(true)
      try {
        const { data, error } = await supabase.rpc('get_taxonomy_tree')

        if (error) throw error

        if (data) {
          const infoMap = new Map<string, TaxonomyInfo>()
          const nodeMap = new Map<string, any>()

          // First pass: create node map
          data.forEach((item: any) => {
            nodeMap.set(item.code, {
              code: item.code,
              name: item.name, // Database returns 'name' field directly
              parent_code: item.parent_code,
              level: item.level
            })
          })

          // Second pass: build full paths for selected codes
          selectedTaxonomyCodes.forEach(code => {
            const node = nodeMap.get(code)
            if (!node) return

            // Build path by traversing parents
            const path: string[] = [node.name]
            let currentCode = node.parent_code
            while (currentCode && nodeMap.has(currentCode)) {
              const parentNode = nodeMap.get(currentCode)
              if (parentNode.code !== 'ROOT') {
                path.unshift(parentNode.name)
              }
              currentCode = parentNode.parent_code
            }

            infoMap.set(code, {
              code,
              name: node.name,
              full_path: path.join(' > ')
            })
          })

          setTaxonomyInfo(infoMap)
        }
      } catch (err) {
        console.error('Error loading taxonomy info:', err)
      } finally {
        setLoading(false)
      }
    }

    loadTaxonomyInfo()
  }, [selectedTaxonomyCodes])

  if (selectedTaxonomyCodes.length === 0) {
    return null
  }

  return (
    <div style={{
      padding: '12px 16px',
      backgroundColor: '#f9fafb',
      border: '1px solid #e5e7eb',
      borderRadius: '6px',
      marginBottom: '16px'
    }}>
      <div style={{
        display: 'flex',
        alignItems: 'center',
        flexWrap: 'wrap',
        gap: '8px'
      }}>
        <span style={{
          fontSize: '14px',
          fontWeight: '500',
          color: '#374151',
          marginRight: '4px'
        }}>
          📁 Categories:
        </span>

        {loading ? (
          <span style={{ fontSize: '12px', color: '#6b7280' }}>Loading...</span>
        ) : (
          <>
            {selectedTaxonomyCodes.map(code => {
              const info = taxonomyInfo.get(code)
              if (!info) return null

              return (
                <div
                  key={code}
                  title={info.full_path} // Tooltip showing full path
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '6px',
                    padding: '4px 8px 4px 12px',
                    backgroundColor: '#dbeafe',
                    color: '#1e40af',
                    borderRadius: '16px',
                    fontSize: '13px',
                    border: '1px solid #93c5fd',
                    transition: 'all 0.2s',
                    cursor: 'default'
                  }}
                >
                  <span>{info.name}</span>
                  <button
                    onClick={() => onRemoveTaxonomy(code)}
                    aria-label={`Remove ${info.name} filter`}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      width: '16px',
                      height: '16px',
                      padding: 0,
                      backgroundColor: '#1e40af',
                      color: 'white',
                      border: 'none',
                      borderRadius: '50%',
                      cursor: 'pointer',
                      fontSize: '12px',
                      lineHeight: '1',
                      transition: 'all 0.2s'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.backgroundColor = '#1e3a8a'
                      e.currentTarget.style.transform = 'scale(1.1)'
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.backgroundColor = '#1e40af'
                      e.currentTarget.style.transform = 'scale(1)'
                    }}
                  >
                    ✕
                  </button>
                </div>
              )
            })}

            {selectedTaxonomyCodes.length > 1 && (
              <button
                onClick={onClearAll}
                style={{
                  padding: '4px 12px',
                  fontSize: '13px',
                  fontWeight: '500',
                  color: '#dc2626',
                  backgroundColor: 'transparent',
                  border: '1px solid #dc2626',
                  borderRadius: '16px',
                  cursor: 'pointer',
                  transition: 'all 0.2s',
                  marginLeft: '4px'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.backgroundColor = '#fef2f2'
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.backgroundColor = 'transparent'
                }}
              >
                Clear All
              </button>
            )}
          </>
        )}
      </div>
    </div>
  )
}
