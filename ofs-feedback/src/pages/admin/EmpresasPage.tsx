import { useState, useEffect } from 'react';
import api from '@/lib/api';
import { Table, Button, Badge } from '@/components/ui';
import { Plus } from 'lucide-react';
import type { Empresa } from '@/types';
import { format, parseISO } from 'date-fns';

export default function EmpresasPage() {
  const [empresas, setEmpresas] = useState<Empresa[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/admin/empresas')
      .then((r) => setEmpresas(r.data.data || r.data))
      .finally(() => setLoading(false));
  }, []);

  const columns = [
    { key: 'nome', header: 'Nome' },
    { key: 'cnpj', header: 'CNPJ', render: (e: Empresa) => e.cnpj || '-' },
    {
      key: 'ativo', header: 'Status',
      render: (e: Empresa) => (
        <Badge variant={e.ativo ? 'success' : 'neutral'}>
          {e.ativo ? 'Ativo' : 'Inativo'}
        </Badge>
      ),
    },
    {
      key: 'created_at', header: 'Criada em',
      render: (e: Empresa) => e.created_at ? format(parseISO(e.created_at), 'dd/MM/yyyy') : '-',
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-brand-black">Empresas</h1>
          <p className="text-sm text-gray-500 mt-1">Gerenciamento de empresas</p>
        </div>
        <Button><Plus className="h-4 w-4" /> Nova Empresa</Button>
      </div>

      <Table columns={columns} data={empresas} loading={loading} />
    </div>
  );
}
