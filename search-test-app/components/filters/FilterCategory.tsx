'use client'

import { FilterCategoryProps } from './types'
import { ChevronDown, ChevronUp } from 'lucide-react'

/**
 * FilterCategory - Collapsible container for filter groups
 * Groups related filters together (Electricals, Design, Light Engine)
 */
export default function FilterCategory({
  label,
  isExpanded,
  onToggle,
  children
}: FilterCategoryProps) {
  return (
    <div className="border-b pb-4 last:border-b-0">
      {/* Category Header */}
      <button
        onClick={onToggle}
        className="w-full flex items-center justify-between py-2 font-semibold text-sm uppercase tracking-wide text-gray-700 hover:text-gray-900 transition-colors"
        aria-expanded={isExpanded}
      >
        <span>{label}</span>
        {isExpanded ? (
          <ChevronUp size={16} className="text-gray-500" />
        ) : (
          <ChevronDown size={16} className="text-gray-500" />
        )}
      </button>

      {/* Category Content */}
      {isExpanded && (
        <div className="mt-2 space-y-4 animate-in fade-in duration-200">
          {children}
        </div>
      )}
    </div>
  )
}
