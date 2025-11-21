'use client'

export default function ProductCardSkeleton() {
  return (
    <div className="bg-white rounded-xl shadow-md border border-slate-200 overflow-hidden animate-pulse">
      {/* Image skeleton */}
      <div className="aspect-square bg-gradient-to-br from-slate-200 to-slate-100" />

      {/* Content skeleton */}
      <div className="p-4">
        {/* Product ID skeleton */}
        <div className="h-6 bg-slate-200 rounded-lg mb-2 w-3/4" />

        {/* Description skeleton */}
        <div className="space-y-2 mb-3">
          <div className="h-4 bg-slate-100 rounded w-full" />
          <div className="h-4 bg-slate-100 rounded w-5/6" />
        </div>

        {/* Supplier and Class skeleton */}
        <div className="flex items-center gap-2 mb-3 pb-3 border-b border-slate-100">
          <div className="h-3 bg-slate-100 rounded w-20" />
          <div className="h-3 bg-slate-100 rounded w-2" />
          <div className="h-3 bg-slate-100 rounded w-24" />
        </div>

        {/* Key Features skeleton */}
        <div className="flex items-center gap-3 mb-3 pb-3 border-b border-slate-100">
          <div className="h-5 bg-slate-100 rounded w-12" />
          <div className="h-5 bg-slate-100 rounded w-16" />
          <div className="h-5 bg-slate-100 rounded w-14" />
        </div>

        {/* Flags skeleton */}
        <div className="flex flex-wrap gap-1.5">
          <div className="h-6 bg-slate-100 rounded-md w-20" />
          <div className="h-6 bg-slate-100 rounded-md w-24" />
          <div className="h-6 bg-slate-100 rounded-md w-18" />
          <div className="h-6 bg-slate-100 rounded-md w-16" />
        </div>
      </div>
    </div>
  )
}
