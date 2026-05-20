import { Card, Table } from '@/components/ui';
import { StatusBadge } from './StatusBadge';
import { ExportButtons } from './ExportButtons';
import type { EmpresaConsolidada } from '@/types';
import { cn } from '@/lib/utils';

interface ConsolidatedTableProps {
  data: EmpresaConsolidada[];
  loading: boolean;
  error: string | null;
  onRowClick?: (item: EmpresaConsolidada) => void;
  exportParams: Record<string, string>;
}

export function ConsolidatedTable({
  data,
  loading,
  error,
  onRowClick,
  exportParams,
}: ConsolidatedTableProps) {
  const columns = [
    { key: 'empresa_nome', header: 'Empresa' },
    { key: 'contrato_nome', header: 'Contrato', render: (r: EmpresaConsolidada) => r.contrato_nome || '-' },
    { key: 'ofc_programadas', header: 'Progr.', className: 'text-right' },
    { key: 'ofc_realizadas', header: 'Realiz.', className: 'text-right' },
    {
      key: 'aderencia_percentual',
      header: 'Aderência',
      className: 'text-right',
      render: (r: EmpresaConsolidada) => (
        <span className={cn(
          'font-medium',
          r.aderencia_percentual >= 90 ? 'text-success' :
          r.aderencia_percentual >= 70 ? 'text-warning' : 'text-danger'
        )}>
          {r.aderencia_percentual}%
        </span>
      ),
    },
    {
      key: 'percentual_seguro',
      header: '% Seguro',
      className: 'text-right',
      render: (r: EmpresaConsolidada) => (
        <span className={cn(
          'font-medium',
          r.percentual_seguro >= 70 ? 'text-success' :
          r.percentual_seguro >= 50 ? 'text-warning' : 'text-danger'
        )}>
          {r.percentual_seguro}%
        </span>
      ),
    },
    { key: 'ofc_positivas', header: 'Posit.', className: 'text-right' },
    { key: 'ofc_negativas', header: 'Negat.', className: 'text-right' },
    { key: 'usuarios_ativos', header: 'Usuár.', className: 'text-right' },
    {
      key: 'media_ofc_usuario',
      header: 'Média',
      className: 'text-right',
      render: (r: EmpresaConsolidada) => r.media_ofc_usuario.toFixed(1),
    },
    {
      key: 'status',
      header: 'Status',
      render: (r: EmpresaConsolidada) => <StatusBadge status={r.status} />,
    },
  ];

  const totalRow: EmpresaConsolidada = {
    id: '_total',
    empresa_nome: 'TOTAL',
    contrato_nome: '',
    ofc_programadas: data.reduce((s, r) => s + r.ofc_programadas, 0),
    ofc_realizadas: data.reduce((s, r) => s + r.ofc_realizadas, 0),
    aderencia_percentual: data.length > 0
      ? Math.round((data.reduce((s, r) => s + r.ofc_realizadas, 0) / data.reduce((s, r) => s + r.ofc_programadas, 0)) * 100 * 10) / 10
      : 0,
    percentual_seguro: data.length > 0
      ? Math.round((data.reduce((s, r) => s + r.ofc_positivas, 0) / (data.reduce((s, r) => s + r.ofc_positivas + r.ofc_negativas, 0) || 1)) * 100 * 10) / 10
      : 0,
    ofc_positivas: data.reduce((s, r) => s + r.ofc_positivas, 0),
    ofc_negativas: data.reduce((s, r) => s + r.ofc_negativas, 0),
    usuarios_ativos: data.reduce((s, r) => s + r.usuarios_ativos, 0),
    media_ofc_usuario: 0,
    status: 'OK',
  };

  return (
    <Card
      title="Consolidado por Empresa / Contrato"
      subtitle={`${data.length} registro${data.length !== 1 ? 's' : ''}`}
      action={<ExportButtons params={exportParams} />}
      className="overflow-hidden"
    >
      <Table
        columns={columns}
        data={data}
        loading={loading}
        error={error}
        emptyMessage="Nenhum dado consolidado para os filtros atuais."
        onRowClick={onRowClick}
      />
      {data.length > 0 && !loading && !error && (
        <div className="border-t border-gray-200 bg-gray-50 px-4 py-2.5">
          <div className="flex items-center text-sm font-semibold text-brand-black">
            <span className="w-[140px]">TOTAL</span>
            <span className="w-[80px]"></span>
            <span className="flex-1 flex justify-end gap-6 pr-4">
              <span className="w-16 text-right">{totalRow.ofc_programadas}</span>
              <span className="w-16 text-right">{totalRow.ofc_realizadas}</span>
              <span className="w-20 text-right">{totalRow.aderencia_percentual}%</span>
              <span className="w-20 text-right">{totalRow.percentual_seguro}%</span>
              <span className="w-16 text-right">{totalRow.ofc_positivas}</span>
              <span className="w-16 text-right">{totalRow.ofc_negativas}</span>
              <span className="w-16 text-right">{totalRow.usuarios_ativos}</span>
              <span className="w-16 text-right">-</span>
              <span className="w-20"></span>
            </span>
          </div>
        </div>
      )}
    </Card>
  );
}
