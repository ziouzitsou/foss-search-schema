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
  debounceMs?: number // Debounce time in milliseconds (default: 0 for instant response)
  rootCode?: string // Optional root code to filter taxonomy tree (e.g., 'LUMINAIRE', 'ACCESSORIES')
}

export default function FacetedCategoryNavigation({
  onSelectTaxonomies,
  autoSearch = true,
  debounceMs = 0, // Changed from 300ms to 0ms for instant single-selection response
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

    // If debounce is 0, call immediately without setTimeout
    if (debounceMs === 0) {
      onSelectTaxonomies(Array.from(selectedCodes))
      return
    }

    // Otherwise use debounce
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
          style={{
            display: 'flex',
            alignItems: 'center',
            padding: '6px 8px',
            cursor: 'pointer',
            borderRadius: '4px',
            transition: 'background-color 0.2s',
            backgroundColor: isSelected ? '#e0f2fe' : 'transparent'
          }}
          onMouseEnter={(e) => {
            if (!isSelected) e.currentTarget.style.backgroundColor = '#f0f9ff'
          }}
          onMouseLeave={(e) => {
            if (!isSelected) e.currentTarget.style.backgroundColor = 'transparent'
          }}
        >
          <input
            type="checkbox"
            checked={isSelected}
            ref={el => {
              if (el) el.indeterminate = isIndeterminate
            }}
            onChange={(e) => handleCheckboxChange(node, e.target.checked)}
            style={{
              marginRight: '8px',
              cursor: 'pointer',
              width: '16px',
              height: '16px'
            }}
          />
          {icon && <span style={{ marginRight: '6px', fontSize: '16px' }}>{icon}</span>}
          <span style={{ flex: 1, fontSize: '14px', color: '#1f2937' }}>
            {node.name}
          </span>
          <span style={{ fontSize: '12px', color: '#6b7280', marginLeft: '8px' }}>
            ({node.product_count.toLocaleString()})
          </span>
        </label>
        {node.children.length > 0 && (
          <div style={{ marginTop: '2px' }}>
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
      <div style={{ padding: '16px', textAlign: 'center', color: '#6b7280' }}>
        Loading categories...
      </div>
    )
  }

  if (error) {
    return (
      <div style={{ padding: '16px' }}>
        <p style={{ color: '#dc2626', marginBottom: '8px' }}>Error loading categories: {error}</p>
        <button
          onClick={loadTaxonomy}
          style={{
            padding: '6px 12px',
            backgroundColor: '#3b82f6',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer'
          }}
        >
          Retry
        </button>
      </div>
    )
  }

  return (
    <div style={{
      border: '1px solid #e5e7eb',
      borderRadius: '8px',
      backgroundColor: 'white',
      padding: '16px'
    }}>
      {/* Header - only show if there are selections */}
      {selectedCodes.size > 0 && (
        <div style={{
          display: 'flex',
          justifyContent: 'flex-end',
          alignItems: 'center',
          marginBottom: '12px',
          paddingBottom: '12px',
          borderBottom: '1px solid #e5e7eb'
        }}>
          <button
            onClick={clearAll}
            style={{
              padding: '4px 8px',
              fontSize: '12px',
              color: '#3b82f6',
              backgroundColor: 'transparent',
              border: '1px solid #3b82f6',
              borderRadius: '4px',
              cursor: 'pointer',
              transition: 'all 0.2s'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.backgroundColor = '#eff6ff'
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.backgroundColor = 'transparent'
            }}
          >
            Clear all ({selectedCodes.size})
          </button>
        </div>
      )}

      {/* Level 1 Categories */}
      <div>
        <div style={{ marginBottom: '4px' }}>
          {level1Nodes.map(node => renderNode(node))}
        </div>
      </div>

      {/* Auto-search indicator */}
      {autoSearch && selectedCodes.size > 0 && (
        <div style={{
          marginTop: '12px',
          padding: '8px',
          backgroundColor: '#f0f9ff',
          borderRadius: '4px',
          fontSize: '12px',
          color: '#0369a1',
          textAlign: 'center'
        }}>
          🔍 Auto-searching with {selectedCodes.size} {selectedCodes.size === 1 ? 'category' : 'categories'}...
        </div>
      )}
    </div>
  )
}
