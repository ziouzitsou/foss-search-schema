'use client'

import { Home, TreePine, Droplet, Scissors, Circle, Square, ArrowUp, Square as SquareIcon, Flashlight, ArrowDown, Box, Link2, Zap, Thermometer, Shield } from 'lucide-react'

type ProductCardProps = {
  product: {
    product_id: string
    foss_pid: string
    description_short: string
    description_long: string | null
    supplier_name: string
    class_name: string
    price: number | null
    image_url: string | null
    flags: {
      indoor: boolean
      outdoor: boolean
      submersible: boolean
      trimless: boolean
      cut_shape_round: boolean
      cut_shape_rectangular: boolean
      ceiling: boolean
      wall: boolean
      floor: boolean
      recessed: boolean
      surface_mounted: boolean
      suspended: boolean
    }
    key_features: {
      power: number | null
      color_temp: number | null
      ip_rating: string | null
    }
    relevance_score: number
  }
}

export default function ProductCard({ product }: ProductCardProps) {
  const flagIcons = [
    { condition: product.flags.indoor, icon: Home, label: 'Indoor', color: 'bg-blue-50 text-blue-700 border-blue-200' },
    { condition: product.flags.outdoor, icon: TreePine, label: 'Outdoor', color: 'bg-green-50 text-green-700 border-green-200' },
    { condition: product.flags.submersible, icon: Droplet, label: 'Submersible', color: 'bg-cyan-50 text-cyan-700 border-cyan-200' },
    { condition: product.flags.trimless, icon: Scissors, label: 'Trimless', color: 'bg-purple-50 text-purple-700 border-purple-200' },
    { condition: product.flags.cut_shape_round, icon: Circle, label: 'Round Cut', color: 'bg-amber-50 text-amber-700 border-amber-200' },
    { condition: product.flags.cut_shape_rectangular, icon: Square, label: 'Rect Cut', color: 'bg-orange-50 text-orange-700 border-orange-200' },
    { condition: product.flags.ceiling, icon: ArrowUp, label: 'Ceiling', color: 'bg-indigo-50 text-indigo-700 border-indigo-200' },
    { condition: product.flags.wall, icon: SquareIcon, label: 'Wall', color: 'bg-violet-50 text-violet-700 border-violet-200' },
    { condition: product.flags.floor, icon: Flashlight, label: 'Floor', color: 'bg-rose-50 text-rose-700 border-rose-200' },
    { condition: product.flags.recessed, icon: ArrowDown, label: 'Recessed', color: 'bg-slate-50 text-slate-700 border-slate-200' },
    { condition: product.flags.surface_mounted, icon: Box, label: 'Surface', color: 'bg-gray-50 text-gray-700 border-gray-200' },
    { condition: product.flags.suspended, icon: Link2, label: 'Suspended', color: 'bg-teal-50 text-teal-700 border-teal-200' },
  ]

  const activeFlags = flagIcons.filter(flag => flag.condition)

  return (
    <div className="group bg-white rounded-xl shadow-md hover:shadow-xl border border-slate-200 overflow-hidden transition-all duration-300 hover:-translate-y-1">
      {/* Image Container with Overlay */}
      <div className="relative aspect-square bg-gradient-to-br from-slate-100 to-slate-50 overflow-hidden">
        {product.image_url ? (
          <>
            <img
              src={product.image_url}
              alt={product.foss_pid}
              className="w-full h-full object-contain transition-transform duration-300 group-hover:scale-105"
            />
            {/* Gradient overlay on hover */}
            <div className="absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300" />

            {/* View Details button on hover */}
            <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-300">
              <button className="bg-white text-slate-800 px-6 py-2.5 rounded-lg font-semibold shadow-lg hover:bg-slate-50 transition-colors">
                View Details
              </button>
            </div>
          </>
        ) : (
          <div className="w-full h-full flex items-center justify-center text-slate-400">
            <Box size={48} strokeWidth={1} />
          </div>
        )}

        {/* Price badge */}
        {product.price && (
          <div className="absolute top-3 right-3 bg-green-500 text-white px-3 py-1.5 rounded-lg font-bold shadow-lg">
            €{product.price.toFixed(2)}
          </div>
        )}
      </div>

      {/* Content */}
      <div className="p-4">
        {/* Product ID */}
        <h3 className="font-bold text-slate-800 mb-2 text-lg group-hover:text-blue-600 transition-colors">
          {product.foss_pid}
        </h3>

        {/* Description */}
        <p className="text-sm text-slate-600 mb-3 line-clamp-2 min-h-[2.5rem]">
          {product.description_short}
        </p>

        {/* Supplier and Class */}
        <div className="flex items-center gap-2 text-xs text-slate-500 mb-3 pb-3 border-b border-slate-100">
          <span className="font-medium">{product.supplier_name}</span>
          <span className="text-slate-300">•</span>
          <span className="truncate">{product.class_name}</span>
        </div>

        {/* Key Features */}
        {(product.key_features.power || product.key_features.color_temp || product.key_features.ip_rating) && (
          <div className="flex items-center gap-3 mb-3 pb-3 border-b border-slate-100">
            {product.key_features.power && (
              <div className="flex items-center gap-1 text-xs text-slate-600">
                <Zap size={14} className="text-amber-500" />
                <span className="font-medium">{product.key_features.power}W</span>
              </div>
            )}
            {product.key_features.color_temp && (
              <div className="flex items-center gap-1 text-xs text-slate-600">
                <Thermometer size={14} className="text-orange-500" />
                <span className="font-medium">{product.key_features.color_temp}K</span>
              </div>
            )}
            {product.key_features.ip_rating && (
              <div className="flex items-center gap-1 text-xs text-slate-600">
                <Shield size={14} className="text-blue-500" />
                <span className="font-medium">{product.key_features.ip_rating}</span>
              </div>
            )}
          </div>
        )}

        {/* Flags */}
        {activeFlags.length > 0 && (
          <div className="flex flex-wrap gap-1.5">
            {activeFlags.slice(0, 6).map((flag, index) => {
              const Icon = flag.icon
              return (
                <div
                  key={index}
                  className={`flex items-center gap-1 px-2 py-1 rounded-md text-xs font-medium border ${flag.color} transition-all`}
                  title={flag.label}
                >
                  <Icon size={12} />
                  <span className="hidden sm:inline">{flag.label}</span>
                </div>
              )
            })}
            {activeFlags.length > 6 && (
              <div className="flex items-center px-2 py-1 rounded-md text-xs font-medium bg-slate-100 text-slate-600 border border-slate-200">
                +{activeFlags.length - 6}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
