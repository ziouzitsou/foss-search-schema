'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '@/lib/supabase'

type TaxonomyNode = {
  code: string
  parent_code: string | null
  level: number
  name: string
  icon: string | null
  product_count: number
}

type TreeNode = TaxonomyNode & {
  children: TreeNode[]
}

type FacetedCategoryNavigationProps = {
  onSelectTaxonomies: (codes: string[]) => void
  autoSearch?: boolean // Whether to trigger search automatically (default: true)
  debounceMs?: number // Debounce time in milliseconds (default: 300)
  rootCode?: string // Optional root code to filter taxonomy tree (e.g., 'LUMINAIRE', 'ACCESSORIES')
}

export default function FacetedCategoryNavigation({
  onSelectTaxonomies,
  autoSearch = true,
  debounceMs = 300,
  rootCode
}: FacetedCategoryNavigationProps) {
  const [nodes, setNodes] = useState<TaxonomyNode[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [expandedSections, setExpandedSections] = useState<Set<string>>(new Set(['level-1'])) // Only Level 1 expanded by default
  const [selectedCodes, setSelectedCodes] = useState<Set<string>>(new Set())
  const debounceTimerRef = useRef<NodeJS.Timeout>()

  // Category icons mapping (updated for human-friendly codes)
  const iconMap: Record<string, string> = {
    'LUMINAIRE': '💡',
    'LAMPS': '🔦',
    'ACCESSORIES': '🔌',
    'DRIVERS': '⚡',
    'LUMINAIRE-INDOOR-CEILING': '⬆️',
    'LUMINAIRE-INDOOR-WALL': '◾',
    'LUMINAIRE-INDOOR-FLOOR': '⬇️',
    'LUMINAIRE-DECORATIVE': '✨',
    'LUMINAIRE-SPECIAL': '🎯',
    'ACCESSORY-TRACK': '🛤️',
    'DRIVER-CONSTANT-CURRENT': '⚡',
    'DRIVER-CONSTANT-VOLTAGE': '🔋',
    'LAMP-FILAMENT': '💡',
    'LAMP-MODULE': '🔆'
  }

  useEffect(() => {
    loadTaxonomy()
  }, [])

  // Debounced search trigger
  useEffect(() => {
    if (!autoSearch) return

    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current)
    }

    debounceTimerRef.current = setTimeout(() => {
      onSelectTaxonomies(Array.from(selectedCodes))
    }, debounceMs)

    return () => {
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current)
      }
    }
  }, [selectedCodes, onSelectTaxonomies, autoSearch, debounceMs])

  const loadTaxonomy = async () => {
    setLoading(true)
    setError(null)

    try {
      const { data, error } = await supabase.rpc('get_taxonomy_tree')

      if (error) throw error

      if (data) {
        const taxonomyNodes: TaxonomyNode[] = data.map((item: any) => ({
          code: item.code,
          parent_code: item.parent_code,
          level: item.level,
          name: item.name, // Database returns 'name' field directly
          icon: item.icon,
          product_count: item.product_count || 0
        }))

        setNodes(taxonomyNodes)
      }
    } catch (err: any) {
      setError(err.message)
      console.error('Taxonomy load error:', err)
    } finally {
      setLoading(false)
    }
  }

  // Build tree structure from flat array
  const buildTree = (nodes: TaxonomyNode[]): TreeNode[] => {
    const nodeMap = new Map<string, TreeNode>()
    const rootNodes: TreeNode[] = []

    // Create all nodes
    nodes.forEach(node => {
      nodeMap.set(node.code, { ...node, children: [] })
    })

    // Build parent-child relationships
    nodes.forEach(node => {
      const treeNode = nodeMap.get(node.code)!
      if (node.parent_code && nodeMap.has(node.parent_code)) {
        nodeMap.get(node.parent_code)!.children.push(treeNode)
      } else {
        rootNodes.push(treeNode)
      }
    })

    return rootNodes
  }

  // Get all descendant codes for a node
  const getDescendantCodes = useCallback((node: TreeNode): string[] => {
    const codes = [node.code]
    node.children.forEach(child => {
      codes.push(...getDescendantCodes(child))
    })
    return codes
  }, [])

  // Check if node has any selected descendants
  const hasSelectedDescendants = useCallback((node: TreeNode): boolean => {
    if (selectedCodes.has(node.code)) return true
    return node.children.some(child => hasSelectedDescendants(child))
  }, [selectedCodes])

  // Check if all descendants are selected
  const allDescendantsSelected = useCallback((node: TreeNode): boolean => {
    if (!selectedCodes.has(node.code)) return false
    return node.children.every(child => allDescendantsSelected(child))
  }, [selectedCodes])

  // Handle checkbox change - SINGLE SELECTION ONLY (no multi-select)
  const handleCheckboxChange = (node: TreeNode, checked: boolean) => {
    if (checked) {
      // Single selection: clear all previous selections and add only this node
      setSelectedCodes(new Set([node.code]))
    } else {
      // Uncheck: clear all selections
      setSelectedCodes(new Set())
    }
  }

  // Toggle section expansion
  const toggleSection = (sectionId: string) => {
    const newExpanded = new Set(expandedSections)
    if (newExpanded.has(sectionId)) {
      newExpanded.delete(sectionId)
    } else {
      newExpanded.add(sectionId)
    }
    setExpandedSections(newExpanded)
  }

  // Clear all selections
  const clearAll = () => {
    setSelectedCodes(new Set())
  }

  // Render a tree node with checkbox
  const renderNode = (node: TreeNode, depth: number = 0) => {
    const isSelected = selectedCodes.has(node.code)
    const hasSelected = hasSelectedDescendants(node)
    const allSelected = allDescendantsSelected(node)
    const isIndeterminate = hasSelected && !allSelected
    const icon = iconMap[node.code] || node.icon || ''

    return (
      <div key={node.code} style={{ marginLeft: depth > 0 ? '20px' : '0' }}>
        <label
          className={`flex items-center px-3 py-2 cursor-pointer rounded-lg transition-all duration-200
            ${isSelected
              ? 'bg-blue-100 border-blue-300 shadow-sm'
              : 'hover:bg-slate-50'
            }`}
        >
          <input
            type="checkbox"
            checked={isSelected}
            ref={el => {
              if (el) el.indeterminate = isIndeterminate
            }}
            onChange={(e) => handleCheckboxChange(node, e.target.checked)}
            className="mr-3 cursor-pointer"
          />
          {icon && <span className="mr-2 text-base">{icon}</span>}
          <span className="flex-1 text-sm text-slate-800 font-medium">
            {node.name}
          </span>
          <span className="text-xs text-slate-500 ml-2 bg-slate-100 px-2 py-0.5 rounded-full">
            {node.product_count.toLocaleString()}
          </span>
        </label>
        {node.children.length > 0 && (
          <div className="mt-1 space-y-1">
            {node.children.map(child => renderNode(child, depth + 1))}
          </div>
        )}
      </div>
    )
  }

  // Group nodes by level
  const tree = buildTree(nodes)
  // If tree has ROOT node, get its children (level 1 nodes), otherwise use tree as-is
  let level1Nodes = tree.length > 0 && tree[0].code === 'ROOT' ? tree[0].children : tree

  // Filter by rootCode if provided - show children of root node, not root itself
  if (rootCode) {
    const rootNode = level1Nodes.find(node => node.code === rootCode)
    level1Nodes = rootNode && rootNode.children ? rootNode.children : []
  }

  if (loading) {
    return (
      <div className="p-6 text-center">
        <div className="animate-pulse flex items-center justify-center gap-2 text-slate-600">
          <div className="w-3 h-3 bg-blue-500 rounded-full animate-bounce"></div>
          <div className="w-3 h-3 bg-blue-500 rounded-full animate-bounce" style={{ animationDelay: '0.1s' }}></div>
          <div className="w-3 h-3 bg-blue-500 rounded-full animate-bounce" style={{ animationDelay: '0.2s' }}></div>
        </div>
        <p className="text-sm text-slate-600 mt-3">Loading categories...</p>
      </div>
    )
  }

  if (error) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-3">
          <p className="text-red-700 text-sm">
            <strong>Error:</strong> {error}
          </p>
        </div>
        <button
          onClick={loadTaxonomy}
          className="w-full bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg
                     font-medium transition-colors duration-200"
        >
          Retry Loading
        </button>
      </div>
    )
  }

  return (
    <div className="space-y-3">
      {/* Header - only show if there are selections */}
      {selectedCodes.size > 0 && (
        <div className="flex justify-end items-center pb-3 border-b border-slate-200">
          <button
            onClick={clearAll}
            className="px-3 py-1.5 text-xs text-blue-600 bg-white hover:bg-blue-50
                       border border-blue-300 rounded-lg transition-colors duration-200
                       font-medium"
          >
            Clear all ({selectedCodes.size})
          </button>
        </div>
      )}

      {/* Level 1 Categories */}
      <div className="space-y-1">
        {level1Nodes.map(node => renderNode(node))}
      </div>

      {/* Auto-search indicator */}
      {autoSearch && selectedCodes.size > 0 && (
        <div className="mt-3 px-3 py-2 bg-blue-50 border border-blue-200 rounded-lg">
          <div className="flex items-center justify-center gap-2 text-xs text-blue-700">
            <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span className="font-medium">
              Auto-searching with {selectedCodes.size} {selectedCodes.size === 1 ? 'category' : 'categories'}
            </span>
          </div>
        </div>
      )}
    </div>
  )
}
