import { cn } from '@/lib/utils';
import { Spinner } from './Spinner';
import { EmptyState } from './EmptyState';
import { type ReactNode } from 'react';

interface Column<T> {
  key: string;
  header: string;
  sortable?: boolean;
  render?: (item: T) => ReactNode;
  className?: string;
}

interface TableProps<T> {
  columns: Column<T>[];
  data: T[];
  loading?: boolean;
  error?: string | null;
  emptyMessage?: string;
  onRowClick?: (item: T) => void;
  orderBy?: string;
  orderDir?: 'asc' | 'desc';
  onSort?: (key: string) => void;
}

export function Table<T extends { id: string }>({
  columns,
  data,
  loading,
  error,
  emptyMessage,
  onRowClick,
  orderBy,
  orderDir,
  onSort,
}: TableProps<T>) {
  if (loading) {
    return (
      <div className="flex justify-center py-16">
        <Spinner size="lg" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-lg border border-danger/30 bg-danger/5 p-6 text-center">
        <p className="text-danger font-medium">{error}</p>
      </div>
    );
  }

  if (data.length === 0) {
    return <EmptyState description={emptyMessage || 'Nenhum registro encontrado.'} />;
  }

  return (
    <div className="overflow-x-auto rounded-lg border border-gray-200">
      <table className="w-full text-sm">
        <thead>
          <tr className="bg-gray-50 border-b border-gray-200">
            {columns.map((col) => (
              <th
                key={col.key}
                onClick={() => col.sortable && onSort?.(col.key)}
                className={cn(
                  'px-4 py-3 text-left font-semibold text-brand-black',
                  col.sortable && 'cursor-pointer hover:bg-gray-100 select-none',
                  col.className
                )}
              >
                <span className="inline-flex items-center gap-1">
                  {col.header}
                  {col.sortable && orderBy === col.key && (
                    <span className="text-brand-red">{orderDir === 'asc' ? '▲' : '▼'}</span>
                  )}
                </span>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {data.map((row) => (
            <tr
              key={row.id}
              onClick={() => onRowClick?.(row)}
              className={cn(
                'border-b border-gray-100 last:border-0',
                onRowClick && 'cursor-pointer hover:bg-gray-50'
              )}
            >
              {columns.map((col) => (
                <td key={col.key} className="px-4 py-3 text-gray-700">
                  {col.render ? col.render(row) : String((row as Record<string, unknown>)[col.key] ?? '')}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
