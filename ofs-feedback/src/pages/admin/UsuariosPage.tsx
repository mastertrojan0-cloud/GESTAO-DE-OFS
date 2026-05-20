import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '@/lib/api';
import { Table, Button, Badge, Select } from '@/components/ui';
import { Plus } from 'lucide-react';
import type { Usuario } from '@/types';
import { format, parseISO } from 'date-fns';

export default function UsuariosPage() {
  const navigate = useNavigate();
  const [usuarios, setUsuarios] = useState<Usuario[]>([]);
  const [loading, setLoading] = useState(true);
  const [filtroPerfil, setFiltroPerfil] = useState('');

  useEffect(() => {
    const params: Record<string, string> = {};
    if (filtroPerfil) params.perfil = filtroPerfil;
    api.get('/admin/usuarios', { params })
      .then((r) => setUsuarios(r.data.data || r.data))
      .finally(() => setLoading(false));
  }, [filtroPerfil]);

  const columns = [
    { key: 'username', header: 'Usuário' },
    { key: 'nome', header: 'Nome' },
    { key: 'email', header: 'Email' },
    {
      key: 'perfil', header: 'Perfil',
      render: (u: Usuario) => (
        <Badge variant={u.perfil === 'admin' ? 'danger' : u.perfil === 'gestor' ? 'warning' : 'info'}>
          {u.perfil}
        </Badge>
      ),
    },
    {
      key: 'ativo', header: 'Status',
      render: (u: Usuario) => (
        <Badge variant={u.ativo ? 'success' : 'neutral'}>
          {u.ativo ? 'Ativo' : 'Inativo'}
        </Badge>
      ),
    },
    {
      key: 'created_at', header: 'Criado em',
      render: (u: Usuario) => u.created_at ? format(parseISO(u.created_at), 'dd/MM/yyyy') : '-',
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-brand-black">Usuários</h1>
          <p className="text-sm text-gray-500 mt-1">Gerenciamento de usuários do sistema</p>
        </div>
        <Button onClick={() => navigate('/admin/usuarios/novo')}><Plus className="h-4 w-4" /> Novo Usuário</Button>
      </div>

      <div className="flex items-center gap-3">
        <Select
          value={filtroPerfil}
          onChange={(e) => { setFiltroPerfil(e.target.value); setLoading(true); }}
          options={[
            { value: '', label: 'Todos os perfis' },
            { value: 'observador', label: 'Observador' },
            { value: 'supervisor', label: 'Supervisor' },
            { value: 'gestor', label: 'Gestor' },
            { value: 'admin', label: 'Admin' },
          ]}
          className="w-48"
        />
      </div>

      <Table
        columns={columns}
        data={usuarios}
        loading={loading}
      />
    </div>
  );
}
