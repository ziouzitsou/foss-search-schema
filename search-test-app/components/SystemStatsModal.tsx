'use client'

import { X, BarChart3, Package, Home, TreePine, Lightbulb, Filter } from 'lucide-react'

type SystemStatsModalProps = {
  stats: {
    total_products: number
    indoor_products: number
    outdoor_products: number
    dimmable_products: number
    filter_entries: number
    taxonomy_nodes: number
  }
  onClose: () => void
}

export default function SystemStatsModal({ stats, onClose }: SystemStatsModalProps) {
  const statItems = [
    { icon: Package, label: 'Total Products', value: stats.total_products, color: 'bg-blue-500' },
    { icon: Home, label: 'Indoor Products', value: stats.indoor_products, color: 'bg-indigo-500' },
    { icon: TreePine, label: 'Outdoor Products', value: stats.outdoor_products, color: 'bg-green-500' },
    { icon: Lightbulb, label: 'Dimmable Products', value: stats.dimmable_products, color: 'bg-amber-500' },
    { icon: Filter, label: 'Filter Entries', value: stats.filter_entries, color: 'bg-purple-500' },
    { icon: BarChart3, label: 'Taxonomy Nodes', value: stats.taxonomy_nodes, color: 'bg-pink-500' },
  ]

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-auto" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="sticky top-0 bg-gradient-to-r from-blue-600 to-indigo-600 text-white px-6 py-4 rounded-t-2xl flex items-center justify-between">
          <div className="flex items-center gap-3">
            <BarChart3 size={24} />
            <h2 className="text-2xl font-bold">System Statistics</h2>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-white/20 rounded-lg transition-colors"
          >
            <X size={24} />
          </button>
        </div>

        {/* Content */}
        <div className="p-6">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {statItems.map((item, index) => {
              const Icon = item.icon
              return (
                <div
                  key={index}
                  className="bg-gradient-to-br from-slate-50 to-white rounded-xl p-5 border border-slate-200 shadow-sm hover:shadow-md transition-shadow"
                >
                  <div className="flex items-start gap-4">
                    <div className={`${item.color} p-3 rounded-lg text-white`}>
                      <Icon size={24} />
                    </div>
                    <div className="flex-1">
                      <p className="text-sm text-slate-600 mb-1">{item.label}</p>
                      <p className="text-2xl font-bold text-slate-800">
                        {item.value.toLocaleString()}
                      </p>
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}
