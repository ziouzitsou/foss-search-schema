'use client'

import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'

interface ProductTabsProps {
  onTabChange?: (value: string) => void
}

type RootCategory = {
  code: string
  name: string
  icon: string | null
  description: string | null
  display_order: number
}

export default function ProductTabs({ onTabChange }: ProductTabsProps) {
  const [activeTab, setActiveTab] = useState('')
  const [tabs, setTabs] = useState<RootCategory[]>([])
  const [loading, setLoading] = useState(true)

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
        const initialTab = data[0].code
        setActiveTab(initialTab)
        onTabChange?.(initialTab)
      }
    } catch (error) {
      console.error('Error loading root categories:', error)
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
      <div className="w-full mb-6 text-center p-10">
        <div className="text-slate-600">Loading categories...</div>
      </div>
    )
  }

  return (
    <div className="w-full mb-6">
      <div className="bg-slate-100 p-3 rounded-lg mb-6">
        <div className="flex flex-wrap gap-3">
          {tabs.map((tab) => (
            <button
              key={tab.code}
              onClick={() => handleTabClick(tab.code)}
              className={`px-4 py-2 rounded-md font-medium text-sm transition-all
                ${activeTab === tab.code
                  ? 'bg-blue-600 text-white shadow'
                  : 'bg-white text-slate-700 hover:bg-slate-200'
                }`
              }
              title={tab.description || ''}
            >
              {tab.icon && <span className="mr-2">{tab.icon}</span>}
              {tab.name}
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
