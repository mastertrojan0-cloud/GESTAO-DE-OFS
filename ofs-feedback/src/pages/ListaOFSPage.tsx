import { useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useOFSStore } from '@/stores/ofsStore';
import { useDebounce } from '@/hooks';
import { Table, Pagination, Input, Select, DatePicker, Badge, Button } from '@/components/ui';
import { Search, RotateCcw } from 'lucide-react';
import type { OFS } from '@/types';
import { format, parseISO } from 'date-fns';

export default function ListaOFSPage() {
  const { ofss, total, loading, error, filtros, buscarOFSs, setFiltros } = useOFSStore();
  const navigate = useNavigate();
  const debouncedBusca = useDebounce(filtros.nome_observado || '', 400);

  useEffect(() => {
    buscarOFSs();
  }, []);

  useEffect(() => {
    if (filtros.nome_observado !== undefined) {
      buscarOFSs();
    }
  }, [debouncedBusca]);

  const handleSort = useCallback((key: string) => {
    const newDir = filtros.order_by === key && filtros.order_dir === 'asc' ? 'desc' : 'asc';
    setFiltros({ order_by: key, order_dir: newDir });
    buscarOFSs({ ...filtros, order_by: key, order_dir: newDir });
  }, [filtros, buscarOFSs, setFiltros]);

  const columns = [
    { key: 'data', header: 'Data', sortable: true,
      render: (o: OFS) => format(parseISO(o.data), 'dd/MM/yyyy') },
    { key: 'hora', header: 'Hora', sortable: true },
    { key: 'nome_observado', header: 'Observado', sortable: true },
    { key: 'empresa_nome', header: 'Empresa', sortable: true },
    { key: 'turno', header: 'Turno' },
    {
      key: 'tipo', header: 'Tipo',
      render: (o: OFS) => (
        <Badge variant={o.tipo === 'Positivo/Seguro' ? 'success' : 'danger'}>
          {o.tipo === 'Positivo/Seguro' ? 'OFS Positiva (Seguro)' : 'OFS Negativa (Inseguro)'}
        </Badge>
      ),
    },
    {
      key: 'comportamento', header: 'Comportamento',
      render: (o: OFS) => (
        <Badge variant={o.comportamento === 'seguro' ? 'success' : 'danger'}>
          {o.comportamento === 'seguro' ? 'Seguro' : 'Inseguro'}
        </Badge>
      ),
    },
    {
      key: 'status', header: 'Status', sortable: true,
      render: (o: OFS) => (
        <Badge variant={o.status === 'ativo' ? 'success' : 'neutral'}>
          {o.status === 'ativo' ? 'Ativo' : 'Cancelado'}
        </Badge>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-brand-black">OFSs Registradas</h1>
          <p className="text-sm text-gray-500 mt-1">{total} registros encontrados</p>
        </div>
        <Button onClick={() => navigate('/ofs/novo')}>+ Nova OFS</Button>
      </div>

      <div className="flex flex-wrap items-center gap-3 bg-surface rounded-lg border border-gray-200 p-3">
        <div className="flex-1 min-w-[200px]">
          <Input
            placeholder="Buscar por nome..."
            value={filtros.nome_observado || ''}
            onChange={(e) => setFiltros({ nome_observado: e.target.value })}
          />
        </div>
        <DatePicker
          value={filtros.data_inicio || ''}
          onChange={(e) => setFiltros({ data_inicio: e.target.value || undefined })}
          placeholder="Data início"
          className="w-36"
        />
        <DatePicker
          value={filtros.data_fim || ''}
          onChange={(e) => setFiltros({ data_fim: e.target.value || undefined })}
          placeholder="Data fim"
          className="w-36"
        />
        <Select
          value={filtros.tipo || ''}
          onChange={(e) => setFiltros({ tipo: (e.target.value || undefined) as typeof filtros.tipo })}
          options={[
            { value: 'Positivo/Seguro', label: 'OFS Positiva (Seguro)' },
            { value: 'Negativo/Inseguro', label: 'OFS Negativa (Inseguro)' },
          ]}
          className="w-56"
        />
        <Select
          value={filtros.status || ''}
          onChange={(e) => setFiltros({ status: e.target.value || undefined })}
          options={[{ value: 'ativo', label: 'Ativo' }, { value: 'cancelado', label: 'Cancelado' }]}
          className="w-32"
        />
        <Button variant="ghost" size="sm" onClick={() => { useOFSStore.getState().limparFiltros(); buscarOFSs(); }}>
          <RotateCcw className="h-4 w-4" />
        </Button>
      </div>

      <Table
        columns={columns}
        data={ofss}
        loading={loading}
        error={error}
        onRowClick={(o) => navigate(`/ofs/${o.id}`)}
        orderBy={filtros.order_by}
        orderDir={filtros.order_dir}
        onSort={handleSort}
      />

      <Pagination
        page={filtros.page || 1}
        totalPages={Math.ceil(total / (filtros.limit || 20))}
        onPageChange={(p) => { setFiltros({ page: p }); buscarOFSs({ ...filtros, page: p }); }}
      />
    </div>
  );
}
