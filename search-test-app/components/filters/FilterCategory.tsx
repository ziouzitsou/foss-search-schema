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
  // Category icons
  const getCategoryIcon = (label: string) => {
    if (label.toLowerCase().includes('electrical')) return '⚡'
    if (label.toLowerCase().includes('design')) return '🎨'
    if (label.toLowerCase().includes('light')) return '💡'
    return '📋'
  }

  return (
    <div className="border-b border-slate-200 last:border-b-0">
      {/* Category Header */}
      <button
        onClick={onToggle}
        className={`
          w-full flex items-center justify-between px-6 py-4
          font-semibold text-sm uppercase tracking-wide
          transition-all duration-200
          ${isExpanded
            ? 'bg-gradient-to-r from-blue-50 to-indigo-50 text-blue-900'
            : 'text-slate-700 hover:bg-slate-50'
          }
        `}
        aria-expanded={isExpanded}
      >
        <div className="flex items-center gap-2">
          <span className="text-lg">{getCategoryIcon(label)}</span>
          <span className="font-bold">{label}</span>
        </div>
        <div className={`
          transition-transform duration-200
          ${isExpanded ? 'rotate-180' : ''}
        `}>
          <ChevronDown size={18} className={isExpanded ? 'text-blue-600' : 'text-slate-400'} />
        </div>
      </button>

      {/* Category Content */}
      {isExpanded && (
        <div className="px-6 py-4 space-y-6 bg-white">
          {children}
        </div>
      )}
    </div>
  )
}
