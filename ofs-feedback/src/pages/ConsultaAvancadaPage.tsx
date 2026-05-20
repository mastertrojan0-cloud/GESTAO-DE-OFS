import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useDebounce } from '@/hooks';
import api from '@/lib/api';
import { Table, Pagination, Input, Select, DatePicker, Button, Badge } from '@/components/ui';
import { Download, RotateCcw } from 'lucide-react';
import type { OFS } from '@/types';
import { format, parseISO } from 'date-fns';

export default function ConsultaAvancadaPage() {
  const [data, setData] = useState<OFS[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [filtros, setFiltros] = useState({
    data_inicio: '',
    data_fim: '',
    empresa_id: '',
    tipo: '',
    turno: '',
    comportamento: '',
    status: '',
    nome_observado: '',
    usuario_gerador_id: '',
  });
  const navigate = useNavigate();
  const debouncedNome = useDebounce(filtros.nome_observado, 400);

  const buscar = useCallback(async () => {
    setLoading(true);
    try {
      const params: Record<string, string | number> = {};
      Object.entries(filtros).forEach(([k, v]) => { if (v) params[k] = v; });
      params.limit = 20;
      params.page = page;
      const res = await api.get('/ofs', { params });
      setData(res.data.data || []);
      setTotal(res.data.total || 0);
    } catch {} finally {
      setLoading(false);
    }
  }, [filtros, page]);

  useEffect(() => { buscar(); }, [page, debouncedNome]);

  function limparFiltros() {
    setFiltros({
      data_inicio: '', data_fim: '', empresa_id: '', tipo: '', turno: '',
      comportamento: '', status: '', nome_observado: '', usuario_gerador_id: '',
    });
    setPage(1);
  }

  function exportarCSV() {
    const params = new URLSearchParams();
    Object.entries(filtros).forEach(([k, v]) => { if (v) params.append(k, v); });
    window.open(`/api/ofs/export?${params.toString()}`, '_blank');
  }

  const columns = [
    { key: 'data', header: 'Data', sortable: true,
      render: (o: OFS) => format(parseISO(o.data), 'dd/MM/yyyy') },
    { key: 'nome_observado', header: 'Observado' },
    { key: 'empresa_nome', header: 'Empresa' },
    { key: 'turno', header: 'Turno' },
    { key: 'tipo', header: 'Tipo', render: (o: OFS) => <Badge variant={o.tipo === 'Positivo/Seguro' ? 'success' : 'danger'}>{o.tipo === 'Positivo/Seguro' ? 'OFS Positiva (Seguro)' : 'OFS Negativa (Inseguro)'}</Badge> },
    { key: 'comportamento', header: 'Comp.', render: (o: OFS) => <Badge variant={o.comportamento === 'seguro' ? 'success' : 'danger'}>{o.comportamento === 'seguro' ? 'Seguro' : 'Inseguro'}</Badge> },
    { key: 'status', header: 'Status', render: (o: OFS) => <Badge variant={o.status === 'ativo' ? 'success' : 'neutral'}>{o.status === 'ativo' ? 'Ativo' : 'Canc.'}</Badge> },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-brand-black">Consulta Avançada</h1>
          <p className="text-sm text-gray-500 mt-1">Filtros completos para análise detalhada</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="sm" onClick={limparFiltros}>
            <RotateCcw className="h-4 w-4" /> Limpar Filtros
          </Button>
          <Button size="sm" onClick={exportarCSV}>
            <Download className="h-4 w-4" /> Exportar CSV
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 bg-surface rounded-xl border border-gray-200 p-4">
        <DatePicker
          label="Data Início"
          value={filtros.data_inicio}
          onChange={(e) => setFiltros({ ...filtros, data_inicio: e.target.value })}
        />
        <DatePicker
          label="Data Fim"
          value={filtros.data_fim}
          onChange={(e) => setFiltros({ ...filtros, data_fim: e.target.value })}
        />
        <Input
          label="Nome Observado"
          value={filtros.nome_observado}
          onChange={(e) => setFiltros({ ...filtros, nome_observado: e.target.value })}
          placeholder="Buscar por nome..."
        />
        <Select
          label="Tipo"
          value={filtros.tipo}
          onChange={(e) => setFiltros({ ...filtros, tipo: e.target.value })}
          options={[
            { value: 'Positivo/Seguro', label: 'OFS Positiva (Seguro)' },
            { value: 'Negativo/Inseguro', label: 'OFS Negativa (Inseguro)' },
          ]}
        />
        <Select
          label="Turno"
          value={filtros.turno}
          onChange={(e) => setFiltros({ ...filtros, turno: e.target.value })}
          options={[
            { value: 'ADM', label: 'ADM' },
            { value: '1', label: '1º Turno' },
            { value: '2', label: '2º Turno' },
            { value: '3', label: '3º Turno' },
          ]}
        />
        <Select
          label="Comportamento"
          value={filtros.comportamento}
          onChange={(e) => setFiltros({ ...filtros, comportamento: e.target.value })}
          options={[{ value: 'seguro', label: 'Seguro' }, { value: 'inseguro', label: 'Inseguro' }]}
        />
        <Select
          label="Status"
          value={filtros.status}
          onChange={(e) => setFiltros({ ...filtros, status: e.target.value })}
          options={[{ value: 'ativo', label: 'Ativo' }, { value: 'cancelado', label: 'Cancelado' }]}
        />
      </div>

      <div className="text-sm text-gray-500 font-medium">
        Total: {total} registro{total !== 1 ? 's' : ''}
      </div>

      <Table
        columns={columns}
        data={data}
        loading={loading}
        onRowClick={(o) => navigate(`/ofs/${o.id}`)}
      />

      <Pagination
        page={page}
        totalPages={Math.ceil(total / 20)}
        onPageChange={(p) => setPage(p)}
      />
    </div>
  );
}
