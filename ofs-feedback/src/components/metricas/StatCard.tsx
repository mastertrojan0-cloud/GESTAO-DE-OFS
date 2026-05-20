import { cn } from '@/lib/utils';
import { ChevronRight, TrendingUp, TrendingDown } from 'lucide-react';

interface StatCardProps {
  label: string;
  value: string | number;
  subtitle?: string;
  icon?: React.ReactNode;
  variant?: 'default' | 'success' | 'warning' | 'danger';
  accentBar?: boolean;
  trend?: { direction: 'up' | 'down'; value: string };
  progress?: number;
  onClick?: () => void;
  className?: string;
}

const variantStyles = {
  default: 'text-brand-black',
  success: 'text-success',
  warning: 'text-warning',
  danger: 'text-danger',
};

const accentColors = {
  success: 'before:bg-success',
  warning: 'before:bg-warning',
  danger: 'before:bg-danger',
  default: 'before:bg-brand-red',
};

export function StatCard({
  label,
  value,
  subtitle,
  icon,
  variant = 'default',
  accentBar = false,
  trend,
  progress,
  onClick,
  className,
}: StatCardProps) {
  return (
    <div
      onClick={onClick}
      className={cn(
        'relative rounded-xl bg-surface shadow-sm border border-gray-100 p-5',
        'transition-all duration-200',
        onClick && 'cursor-pointer hover:shadow-md hover:border-gray-300 hover:-translate-y-0.5',
        accentBar && `before:absolute before:top-0 before:right-0 before:w-1 before:h-full before:rounded-r`,
        accentBar && accentColors[variant],
        className
      )}
    >
      <div className="flex items-start justify-between">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            {icon && <span className="text-gray-400 flex-shrink-0">{icon}</span>}
            <p className="text-xs text-gray-500 uppercase tracking-wider truncate">{label}</p>
          </div>
          <p className={cn('text-3xl font-bold mt-1.5 tracking-tight', variantStyles[variant])}>
            {value}
          </p>
          {subtitle && (
            <p className="text-xs text-gray-400 mt-1">{subtitle}</p>
          )}
          {trend && (
            <div className="flex items-center gap-1 mt-2">
              {trend.direction === 'up' ? (
                <TrendingUp className="h-3.5 w-3.5 text-success" />
              ) : (
                <TrendingDown className="h-3.5 w-3.5 text-danger" />
              )}
              <span className={cn(
                'text-xs font-medium',
                trend.direction === 'up' ? 'text-success' : 'text-danger'
              )}>
                {trend.value}
              </span>
            </div>
          )}
          {progress !== undefined && (
            <div className="mt-3">
              <div className="h-1.5 bg-gray-100 rounded-full overflow-hidden">
                <div
                  className={cn(
                    'h-full rounded-full transition-all duration-500',
                    variant === 'success' && 'bg-success',
                    variant === 'warning' && 'bg-warning',
                    variant === 'danger' && 'bg-danger',
                    variant === 'default' && 'bg-brand-red'
                  )}
                  style={{ width: `${Math.min(progress, 100)}%` }}
                />
              </div>
            </div>
          )}
        </div>
        {onClick && (
          <ChevronRight className="h-5 w-5 text-gray-300 flex-shrink-0 mt-1" />
        )}
      </div>
    </div>
  );
}
