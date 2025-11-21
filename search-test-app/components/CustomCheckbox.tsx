'use client'

import { Check } from 'lucide-react'

type CustomCheckboxProps = {
  checked: boolean
  onChange: (checked: boolean) => void
  label: string
  count?: number
  icon?: React.ComponentType<{ size?: number, className?: string }>
  disabled?: boolean
}

export default function CustomCheckbox({
  checked,
  onChange,
  label,
  count,
  icon: Icon,
  disabled = false
}: CustomCheckboxProps) {
  return (
    <label className={`
      flex items-center gap-3 p-3 rounded-lg border-2 transition-all cursor-pointer
      ${checked
        ? 'bg-blue-50 border-blue-500 shadow-sm'
        : 'bg-white border-slate-200 hover:border-slate-300 hover:bg-slate-50'
      }
      ${disabled ? 'opacity-50 cursor-not-allowed' : ''}
    `}>
      <div className="relative flex-shrink-0">
        <input
          type="checkbox"
          checked={checked}
          onChange={(e) => onChange(e.target.checked)}
          disabled={disabled}
          className="sr-only"
        />
        <div className={`
          w-5 h-5 rounded border-2 flex items-center justify-center transition-all
          ${checked
            ? 'bg-blue-500 border-blue-500'
            : 'bg-white border-slate-300'
          }
        `}>
          {checked && <Check size={14} className="text-white" strokeWidth={3} />}
        </div>
      </div>

      <div className="flex items-center gap-2 flex-1">
        {Icon && <Icon size={18} className={checked ? 'text-blue-600' : 'text-slate-500'} />}
        <span className={`font-medium ${checked ? 'text-blue-900' : 'text-slate-700'}`}>
          {label}
        </span>
      </div>

      {count !== undefined && (
        <span className={`
          text-sm font-semibold px-2 py-0.5 rounded
          ${checked
            ? 'bg-blue-100 text-blue-700'
            : 'bg-slate-100 text-slate-600'
          }
        `}>
          {count.toLocaleString()}
        </span>
      )}
    </label>
  )
}
