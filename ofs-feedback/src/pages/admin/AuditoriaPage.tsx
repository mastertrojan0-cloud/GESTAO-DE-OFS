import { useState, useEffect } from 'react';
import api from '@/lib/api';
import { Table, Input, Select, DatePicker, Button } from '@/components/ui';
import { Search, RotateCcw } from 'lucide-react';
import type { AuditoriaLog } from '@/types';
import { format, parseISO } from 'date-fns';

export default function AuditoriaPage() {
  const [logs, setLogs] = useState<AuditoriaLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [filtros, setFiltros] = useState({
    usuario_id: '',
    acao: '',
    entidade: '',
    data_inicio: '',
    data_fim: '',
  });

  async function buscar() {
    setLoading(true);
    try {
      const params: Record<string, string> = {};
      Object.entries(filtros).forEach(([k, v]) => { if (v) params[k] = v; });
      const res = await api.get('/admin/auditoria', { params });
      setLogs(res.data.data || res.data);
    } catch {} finally {
      setLoading(false);
    }
  }

  useEffect(() => { buscar(); }, []);

  const columns = [
    { key: 'usuario_nome', header: 'Usuário' },
    { key: 'acao', header: 'Ação' },
    { key: 'entidade', header: 'Entidade' },
    { key: 'entidade_id', header: 'ID Entidade' },
    { key: 'detalhes', header: 'Detalhes', className: 'max-w-xs truncate' },
    { key: 'ip', header: 'IP' },
    {
      key: 'created_at', header: 'Data',
      render: (l: AuditoriaLog) => format(parseISO(l.created_at), 'dd/MM/yyyy HH:mm:ss'),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-brand-black">Auditoria</h1>
        <p className="text-sm text-gray-500 mt-1">Logs de ações do sistema</p>
      </div>

      <div className="flex flex-wrap items-center gap-3 bg-surface rounded-lg border border-gray-200 p-3">
        <Input
          placeholder="Usuário ID"
          value={filtros.usuario_id}
          onChange={(e) => setFiltros({ ...filtros, usuario_id: e.target.value })}
          className="w-40"
        />
        <Select
          value={filtros.acao}
          onChange={(e) => setFiltros({ ...filtros, acao: e.target.value })}
          options={[
            { value: '', label: 'Todas ações' },
            { value: 'CREATE', label: 'CREATE' },
            { value: 'UPDATE', label: 'UPDATE' },
            { value: 'DELETE', label: 'DELETE' },
            { value: 'LOGIN', label: 'LOGIN' },
          ]}
          className="w-40"
        />
        <DatePicker value={filtros.data_inicio} onChange={(e) => setFiltros({ ...filtros, data_inicio: e.target.value })} className="w-36" />
        <DatePicker value={filtros.data_fim} onChange={(e) => setFiltros({ ...filtros, data_fim: e.target.value })} className="w-36" />
        <Button variant="outline" size="sm" onClick={buscar}><Search className="h-4 w-4" /> Buscar</Button>
        <Button variant="ghost" size="sm" onClick={() => { setFiltros({ usuario_id: '', acao: '', entidade: '', data_inicio: '', data_fim: '' }); }}>
          <RotateCcw className="h-4 w-4" />
        </Button>
      </div>

      <Table columns={columns} data={logs} loading={loading} />
    </div>
  );
}
