'use client'

import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'

interface ProductTabsProps {
  children: React.ReactNode
  onTabChange?: (value: string) => void
}

type RootCategory = {
  code: string
  name: string
  icon: string | null
  description: string | null
  display_order: number
}

export default function ProductTabs({ children, onTabChange }: ProductTabsProps) {
  const [activeTab, setActiveTab] = useState('')
  const [tabs, setTabs] = useState<RootCategory[]>([])
  const [loading, setLoading] = useState(true)

  // Load root categories from database on mount
  useEffect(() => {
    loadRootCategories()
  }, [])

  const loadRootCategories = async () => {
    try {
      setLoading(true)
      const { data, error } = await supabase.rpc('get_root_categories')

      if (error) throw error

      if (data && data.length > 0) {
        setTabs(data)
        // Set first tab as active by default
        setActiveTab(data[0].code)
        // Notify parent of initial tab
        onTabChange?.(data[0].code)
      }
    } catch (error) {
      console.error('Error loading root categories:', error)
      // Fallback to empty state
      setTabs([])
    } finally {
      setLoading(false)
    }
  }

  const handleTabClick = (code: string) => {
    setActiveTab(code)
    onTabChange?.(code)
  }

  if (loading) {
    return (
      <div style={{ width: '100%', marginBottom: '24px', textAlign: 'center', padding: '40px' }}>
        <div style={{ color: '#6b7280' }}>Loading categories...</div>
      </div>
    )
  }

  return (
    <div style={{ width: '100%', marginBottom: '24px' }}>
      {/* Tab Buttons */}
      <div style={{
        backgroundColor: '#f3f4f6',
        padding: '12px',
        borderRadius: '8px',
        marginBottom: '24px'
      }}>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '12px' }}>
          {tabs.map((tab) => (
            <button
              key={tab.code}
              onClick={() => handleTabClick(tab.code)}
              style={{
                padding: '12px 24px',
                borderRadius: '6px',
                fontWeight: '500',
                border: 'none',
                cursor: 'pointer',
                transition: 'all 0.2s',
                backgroundColor: activeTab === tab.code ? '#2563eb' : '#ffffff',
                color: activeTab === tab.code ? '#ffffff' : '#374151',
                boxShadow: activeTab === tab.code
                  ? '0 4px 6px -1px rgba(0, 0, 0, 0.1)'
                  : '0 1px 2px 0 rgba(0, 0, 0, 0.05)'
              }}
              title={tab.description || ''}
            >
              {tab.icon && <span style={{ marginRight: '8px' }}>{tab.icon}</span>}
              {tab.name}
            </button>
          ))}
        </div>
      </div>

      {/* Tab Content */}
      <div>
        {children}
      </div>
    </div>
  )
}
