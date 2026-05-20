import { useState, useEffect } from 'react';
import api from '@/lib/api';
import { Table, Button, Badge } from '@/components/ui';
import { Plus } from 'lucide-react';
import type { Contrato } from '@/types';
import { format, parseISO } from 'date-fns';

export default function ContratosPage() {
  const [contratos, setContratos] = useState<Contrato[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/admin/contratos')
      .then((r) => setContratos(r.data.data || r.data))
      .finally(() => setLoading(false));
  }, []);

  const columns = [
    { key: 'nome', header: 'Nome' },
    { key: 'numero', header: 'Número', render: (c: Contrato) => c.numero || '-' },
    { key: 'empresa_id', header: 'Empresa ID' },
    {
      key: 'ativo', header: 'Status',
      render: (c: Contrato) => (
        <Badge variant={c.ativo ? 'success' : 'neutral'}>
          {c.ativo ? 'Ativo' : 'Inativo'}
        </Badge>
      ),
    },
    {
      key: 'created_at', header: 'Criado em',
      render: (c: Contrato) => c.created_at ? format(parseISO(c.created_at), 'dd/MM/yyyy') : '-',
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-brand-black">Contratos</h1>
          <p className="text-sm text-gray-500 mt-1">Gestão de contratos por empresa</p>
        </div>
        <Button><Plus className="h-4 w-4" /> Novo Contrato</Button>
      </div>

      <Table columns={columns} data={contratos} loading={loading} />
    </div>
  );
}
