import { Badge } from '@/components/ui';
import type { StatusSemana } from '@/types';

const STATUS_MAP: Record<StatusSemana, { label: string; variant: 'success' | 'warning' | 'danger' }> = {
  OK: { label: 'OK', variant: 'success' },
  ATENCAO: { label: 'ATENÇÃO', variant: 'warning' },
  ALERTA: { label: 'ALERTA', variant: 'danger' },
};

interface StatusBadgeProps {
  status: StatusSemana;
  className?: string;
}

export function StatusBadge({ status, className }: StatusBadgeProps) {
  const config = STATUS_MAP[status] || STATUS_MAP.ATENCAO;
  return <Badge variant={config.variant} className={className}>{config.label}</Badge>;
}
