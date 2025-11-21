'use client'

import { Search, Filter } from 'lucide-react'

type EmptyStateProps = {
  hasFilters?: boolean
}

export default function EmptyState({ hasFilters = false }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-16 px-4">
      <div className="bg-gradient-to-br from-slate-100 to-slate-50 rounded-full p-6 mb-6">
        {hasFilters ? (
          <Filter className="w-12 h-12 text-slate-400" strokeWidth={1.5} />
        ) : (
          <Search className="w-12 h-12 text-slate-400" strokeWidth={1.5} />
        )}
      </div>

      <h3 className="text-xl font-bold text-slate-700 mb-2">
        {hasFilters ? 'No products match your filters' : 'No products found'}
      </h3>

      <p className="text-slate-500 text-center max-w-md mb-6">
        {hasFilters
          ? 'Try adjusting your filter selections to see more results.'
          : 'Start by selecting a category or adjusting your search criteria.'}
      </p>

      {hasFilters && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 max-w-md">
          <p className="text-sm text-blue-800">
            <strong>Tip:</strong> Remove some filters or try selecting different categories to expand your search.
          </p>
        </div>
      )}
    </div>
  )
}
