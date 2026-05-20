import { useState, useEffect } from 'react';
import api from '@/lib/api';
import { Card, Button, Badge, Spinner } from '@/components/ui';
import { Database, Download, RefreshCw, AlertTriangle } from 'lucide-react';
import type { Backup } from '@/types';
import { format, parseISO } from 'date-fns';

export default function BackupPage() {
  const [backups, setBackups] = useState<Backup[]>([]);
  const [loading, setLoading] = useState(true);
  const [backingUp, setBackingUp] = useState(false);
  const [ultimoBackup, setUltimoBackup] = useState<Backup | null>(null);

  async function carregar() {
    setLoading(true);
    try {
      const res = await api.get('/admin/backup');
      const data = res.data.data || res.data;
      setBackups(data);
      if (data.length > 0) setUltimoBackup(data[0]);
    } catch {} finally {
      setLoading(false);
    }
  }

  useEffect(() => { carregar(); }, []);

  async function backupManual() {
    if (!confirm('Iniciar backup manual do banco de dados?')) return;
    setBackingUp(true);
    try {
      await api.post('/admin/backup');
      await carregar();
    } catch {} finally {
      setBackingUp(false);
    }
  }

  async function restaurar(id: string) {
    if (!confirm('Tem certeza que deseja restaurar este backup? Esta ação não pode ser desfeita.')) return;
    try {
      await api.post(`/admin/backup/${id}/restaurar`);
      await carregar();
    } catch {}
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-brand-black">Backup</h1>
        <p className="text-sm text-gray-500 mt-1">Gerenciamento de backups do banco de dados</p>
      </div>

      <Card>
        <div className="flex items-start justify-between">
          <div>
            <h3 className="font-semibold text-brand-black">Status do Último Backup</h3>
            {loading ? <Spinner size="sm" className="mt-2" /> : ultimoBackup ? (
              <div className="mt-2 space-y-1">
                <div className="flex items-center gap-2">
                  <Badge variant={ultimoBackup.status === 'sucesso' ? 'success' : 'danger'}>
                    {ultimoBackup.status === 'sucesso' ? 'Sucesso' : 'Falha'}
                  </Badge>
                  <span className="text-sm text-gray-500">
                    {format(parseISO(ultimoBackup.created_at), "dd/MM/yyyy 'às' HH:mm")}
                  </span>
                </div>
                <p className="text-sm text-gray-500">
                  Arquivo: {ultimoBackup.arquivo} ({ultimoBackup.tamanho})
                </p>
              </div>
            ) : (
              <p className="text-sm text-gray-500 mt-2">Nenhum backup realizado.</p>
            )}
          </div>
          <Button onClick={backupManual} loading={backingUp}>
            <Database className="h-4 w-4" /> Backup Manual
          </Button>
        </div>
      </Card>

      <Card title="Histórico de Backups">
        {backups.length === 0 ? (
          <p className="text-sm text-gray-500">Nenhum backup no histórico.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 text-left">
                  <th className="pb-2 text-xs text-gray-500">Arquivo</th>
                  <th className="pb-2 text-xs text-gray-500">Tamanho</th>
                  <th className="pb-2 text-xs text-gray-500">Tipo</th>
                  <th className="pb-2 text-xs text-gray-500">Status</th>
                  <th className="pb-2 text-xs text-gray-500">Data</th>
                  <th className="pb-2 text-xs text-gray-500">Ações</th>
                </tr>
              </thead>
              <tbody>
                {backups.map((b) => (
                  <tr key={b.id} className="border-b border-gray-50 last:border-0">
                    <td className="py-2 font-medium text-xs">{b.arquivo}</td>
                    <td className="py-2 text-gray-500">{b.tamanho}</td>
                    <td className="py-2">
                      <Badge variant={b.tipo === 'automatico' ? 'info' : 'warning'}>
                        {b.tipo === 'automatico' ? 'Automático' : 'Manual'}
                      </Badge>
                    </td>
                    <td className="py-2">
                      <Badge variant={b.status === 'sucesso' ? 'success' : 'danger'}>
                        {b.status}
                      </Badge>
                    </td>
                    <td className="py-2 text-gray-500">{format(parseISO(b.created_at), 'dd/MM/yyyy HH:mm')}</td>
                    <td className="py-2">
                      <div className="flex gap-1">
                        <a
                          href={`/api/admin/backup/${b.id}/download`}
                          className="p-1 text-gray-500 hover:text-brand-red"
                          title="Download"
                        >
                          <Download className="h-4 w-4" />
                        </a>
                        <button
                          onClick={() => restaurar(b.id)}
                          className="p-1 text-gray-500 hover:text-warning"
                          title="Restaurar"
                        >
                          <RefreshCw className="h-4 w-4" />
                        </button>
                      </div>
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
