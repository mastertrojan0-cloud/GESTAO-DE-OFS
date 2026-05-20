import { forwardRef, type InputHTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

interface DatePickerProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'type'> {
  label?: string;
  error?: string;
}

export const DatePicker = forwardRef<HTMLInputElement, DatePickerProps>(
  ({ className, label, error, id, ...props }, ref) => (
    <div className="flex flex-col gap-1">
      {label && (
        <label htmlFor={id} className="text-sm font-medium text-brand-black">
          {label}
        </label>
      )}
      <input
        ref={ref}
        id={id}
        type="date"
        className={cn(
          'w-full rounded-lg border border-gray-300 bg-surface px-3 py-2 text-sm',
          'focus:outline-none focus:ring-2 focus:ring-brand-red focus:border-transparent',
          error && 'border-danger focus:ring-danger',
          className
        )}
        {...props}
      />
      {error && <span className="text-xs text-danger">{error}</span>}
    </div>
  )
);

DatePicker.displayName = 'DatePicker';
