import { useState, useEffect } from 'react';
import api from '@/lib/api';
import { Card, Button, Select, DatePicker, Badge, Spinner, EmptyState } from '@/components/ui';
import { FileText, Download } from 'lucide-react';
import type { Relatorio } from '@/types';
import { format, parseISO } from 'date-fns';

const tiposRelatorio = [
  { key: 'semanal', label: 'Relatório Semanal', icon: 'S' },
  { key: 'mensal', label: 'Relatório Mensal', icon: 'M' },
  { key: 'empresa', label: 'Relatório por Empresa', icon: 'E' },
  { key: 'individual', label: 'Relatório Individual', icon: 'I' },
];

export default function RelatoriosPage() {
  const [tipo, setTipo] = useState('');
  const [dataInicio, setDataInicio] = useState('');
  const [dataFim, setDataFim] = useState('');
  const [empresaId, setEmpresaId] = useState('');
  const [loading, setLoading] = useState(false);
  const [historico, setHistorico] = useState<Relatorio[]>([]);

  useEffect(() => {
    api.get('/relatorios').then((r) => setHistorico(r.data.data || r.data));
  }, []);

  async function gerarPDF() {
    if (!tipo) return;
    setLoading(true);
    try {
      const params = new URLSearchParams({ tipo });
      if (dataInicio) params.append('data_inicio', dataInicio);
      if (dataFim) params.append('data_fim', dataFim);
      if (empresaId) params.append('empresa_id', empresaId);
      window.open(`/api/relatorios/gerar?${params.toString()}`, '_blank');
      setTimeout(() => {
        api.get('/relatorios').then((r) => setHistorico(r.data.data || r.data));
        setLoading(false);
      }, 1500);
    } catch {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-brand-black">Relatórios</h1>
        <p className="text-sm text-gray-500 mt-1">Gere e baixe relatórios do sistema</p>
      </div>

      <Card title="Gerar Relatório">
        <div className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
            <Select
              label="Tipo de Relatório *"
              value={tipo}
              onChange={(e) => setTipo(e.target.value)}
              options={tiposRelatorio.map((t) => ({ value: t.key, label: t.label }))}
            />
            <DatePicker
              label="Data Início"
              value={dataInicio}
              onChange={(e) => setDataInicio(e.target.value)}
            />
            <DatePicker
              label="Data Fim"
              value={dataFim}
              onChange={(e) => setDataFim(e.target.value)}
            />
            <Select
              label="Empresa/Contrato"
              value={empresaId}
              onChange={(e) => setEmpresaId(e.target.value)}
              options={[{ value: '', label: 'Todas' }]}
            />
          </div>
          <Button onClick={gerarPDF} loading={loading} disabled={!tipo}>
            <FileText className="h-4 w-4" /> Gerar PDF
          </Button>
        </div>
      </Card>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {tiposRelatorio.map((t) => (
          <Card key={t.key} className="text-center">
            <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-brand-red/10 text-brand-red text-lg font-bold mx-auto mb-3">
              {t.icon}
            </div>
            <h3 className="font-semibold text-brand-black">{t.label}</h3>
            <p className="text-xs text-gray-500 mt-1">Gere o relatório do tipo {t.label.toLowerCase()}</p>
          </Card>
        ))}
      </div>

      <Card title="Histórico de Relatórios">
        {historico.length === 0 ? (
          <EmptyState description="Nenhum relatório gerado." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 text-left">
                  <th className="pb-2 text-xs text-gray-500">Tipo</th>
                  <th className="pb-2 text-xs text-gray-500">Parâmetros</th>
                  <th className="pb-2 text-xs text-gray-500">Status</th>
                  <th className="pb-2 text-xs text-gray-500">Gerado por</th>
                  <th className="pb-2 text-xs text-gray-500">Data</th>
                  <th className="pb-2 text-xs text-gray-500">Ação</th>
                </tr>
              </thead>
              <tbody>
                {historico.map((r) => (
                  <tr key={r.id} className="border-b border-gray-50 last:border-0">
                    <td className="py-2 font-medium capitalize">{r.tipo}</td>
                    <td className="py-2 text-gray-500 text-xs">{r.parametros}</td>
                    <td className="py-2">
                      <Badge
                        variant={r.status === 'gerado' ? 'success' : r.status === 'pendente' ? 'warning' : 'danger'}
                      >
                        {r.status}
                      </Badge>
                    </td>
                    <td className="py-2 text-gray-500">{r.gerado_por}</td>
                    <td className="py-2 text-gray-500">{(r.created_at) ? format(parseISO(r.created_at), 'dd/MM/yyyy HH:mm') : '-'}</td>
                    <td className="py-2">
                      {r.status === 'gerado' && r.arquivo && (
                        <a
                          href={`/api/relatorios/download/${r.id}`}
                          className="text-brand-red hover:underline text-xs inline-flex items-center gap-1"
                        >
                          <Download className="h-3 w-3" /> Baixar
                        </a>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </div>
  );
}
