import { cn } from '@/lib/utils';

function Pulse({ className }: { className?: string }) {
  return <div className={cn('animate-pulse bg-gray-200 rounded', className)} />;
}

export function MetricasSkeleton() {
  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Pulse className="h-10 w-64" />
        <Pulse className="h-9 w-48" />
        <Pulse className="h-9 w-44" />
        <Pulse className="h-9 w-40" />
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {[1, 2, 3].map((i) => (
          <div key={i} className="rounded-xl bg-surface shadow-sm border border-gray-100 p-5 space-y-3">
            <Pulse className="h-3 w-20" />
            <Pulse className="h-8 w-24" />
            <Pulse className="h-3 w-32" />
            <Pulse className="h-1.5 w-full" />
          </div>
        ))}
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-7 gap-4">
        {[1, 2, 3, 4, 5, 6, 7].map((i) => (
          <div key={i} className="rounded-xl bg-surface shadow-sm border border-gray-100 p-4 space-y-2">
            <Pulse className="h-3 w-20" />
            <Pulse className="h-7 w-16" />
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {[1, 2].map((i) => (
          <div key={i} className="rounded-xl bg-surface shadow-sm border border-gray-100 p-5 space-y-3">
            <Pulse className="h-4 w-40" />
            <Pulse className="h-[200px] w-full" />
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {[1, 2].map((i) => (
          <div key={i} className="rounded-xl bg-surface shadow-sm border border-gray-100 p-5 space-y-3">
            <Pulse className="h-4 w-36" />
            <Pulse className="h-[200px] w-full" />
          </div>
        ))}
      </div>

      <div className="rounded-xl bg-surface shadow-sm border border-gray-100 p-5 space-y-3">
        <Pulse className="h-4 w-48" />
        <div className="space-y-2">
          {[1, 2, 3, 4, 5].map((i) => (
            <Pulse key={i} className="h-10 w-full" />
          ))}
        </div>
      </div>
    </div>
  );
}
