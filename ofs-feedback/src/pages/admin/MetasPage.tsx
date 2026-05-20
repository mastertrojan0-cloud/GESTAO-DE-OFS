import { useState, useEffect } from 'react';
import api from '@/lib/api';
import { Table, Button, Badge, Card } from '@/components/ui';
import { Plus } from 'lucide-react';
import type { Meta } from '@/types';

export default function MetasPage() {
  const [metas, setMetas] = useState<Meta[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/admin/metas')
      .then((r) => setMetas(r.data.data || r.data))
      .finally(() => setLoading(false));
  }, []);

  const columns = [
    { key: 'empresa_id', header: 'Empresa' },
    { key: 'pessoas_ativas', header: 'Pessoas Ativas' },
    { key: 'meta_diaria', header: 'Meta Diária' },
    { key: 'meta_semanal', header: 'Meta Semanal' },
    { key: 'vigencia_inicio', header: 'Vigência Início' },
    { key: 'vigencia_fim', header: 'Vigência Fim', render: (m: Meta) => m.vigencia_fim || 'Indeterminado' },
    {
      key: 'ativo', header: 'Status',
      render: (m: Meta) => (
        <Badge variant={m.ativo ? 'success' : 'neutral'}>
          {m.ativo ? 'Ativo' : 'Inativo'}
        </Badge>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-brand-black">Metas</h1>
          <p className="text-sm text-gray-500 mt-1">Gestão de metas por empresa</p>
        </div>
        <Button><Plus className="h-4 w-4" /> Nova Meta</Button>
      </div>

      <Table columns={columns} data={metas} loading={loading} />
    </div>
  );
}
