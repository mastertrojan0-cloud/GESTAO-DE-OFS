import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useOFSStore } from '@/stores/ofsStore';
import { useAuthStore } from '@/stores/authStore';
import api from '@/lib/api';
import { Button, Input, Select, Card } from '@/components/ui';
import { Save, ArrowLeft } from 'lucide-react';
import type { Empresa, TipoOFS, Turno } from '@/types';
import { EMPRESAS_FALLBACK, filtrarEmpresasSelect } from '@/lib/empresasFallback';

export default function EditarOFSPage() {
  const { id } = useParams<{ id: string }>();
  const { current, buscarPorId, atualizar, loading } = useOFSStore();
  const { user } = useAuthStore();
  const navigate = useNavigate();
  const [empresas, setEmpresas] = useState<Empresa[]>([]);
  const [form, setForm] = useState({
    atividade: '',
    local: '',
    empresa_id: '',
    turno: '' as Turno | '',
    tipo: '' as TipoOFS | '',
    comportamento: '',
    observacao: '',
  });
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    api.get('/empresas?ativos=true')
      .then((r) => {
        const lista: Empresa[] = r.data.data || r.data || [];
        setEmpresas(filtrarEmpresasSelect(lista));
      })
      .catch(() => setEmpresas(EMPRESAS_FALLBACK));
    if (id) buscarPorId(id);
  }, [id]);

  useEffect(() => {
    if (current && user) {
      const permitido =
        user.perfil === 'admin' ||
        user.perfil === 'gestor' ||
        (user.perfil === 'supervisor' && current.empresa_id === user.empresa_id && current.status === 'ativo') ||
        (user.perfil === 'observador' && current.usuario_gerador_id === user.id && current.status === 'ativo');
      if (!permitido) {
        navigate(`/ofs/${id}`, { replace: true });
      }
    }
  }, [current, user]);

  useEffect(() => {
    if (current && !loaded) {
      setForm({
        atividade: current.atividade || '',
        local: current.local || '',
        empresa_id: current.empresa_id,
        turno: current.turno,
        tipo: current.tipo,
        comportamento: current.comportamento,
        observacao: current.observacao || '',
      });
      setLoaded(true);
    }
  }, [current, loaded]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!id) return;
    try {
      await atualizar(id, {
        ...form,
        empresa_nome: empresas.find((e) => e.id === form.empresa_id)?.nome || '',
      });
      navigate(`/ofs/${id}`);
    } catch {}
  }

  return (
    <div className="space-y-6 max-w-2xl">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="sm" onClick={() => navigate(-1)}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <div>
          <h1 className="text-2xl font-bold text-brand-black">Editar OFS</h1>
          <p className="text-sm text-gray-500 mt-1">
            Criada por {current?.usuario_gerador_nome} em {current?.data}
          </p>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-5">
        <Card title="Dados da OFS">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Input label="Atividade" value={form.atividade} onChange={(e) => setForm({ ...form, atividade: e.target.value })} />
            <Input label="Local" value={form.local} onChange={(e) => setForm({ ...form, local: e.target.value })} />
            <Select
              label="Empresa *"
              value={form.empresa_id}
              onChange={(e) => setForm({ ...form, empresa_id: e.target.value })}
              options={empresas.map((e) => ({ value: e.id, label: e.nome }))}
            />
            <Select
              label="Turno *"
              value={form.turno}
              onChange={(e) => setForm({ ...form, turno: e.target.value as Turno })}
              options={[
                { value: 'ADM', label: 'ADM' },
                { value: '1', label: '1º Turno' },
                { value: '2', label: '2º Turno' },
                { value: '3', label: '3º Turno' },
              ]}
            />
            <Select
              label="Tipo *"
              value={form.tipo}
              onChange={(e) => setForm({ ...form, tipo: e.target.value as TipoOFS })}
              options={[
                { value: 'Positivo/Seguro', label: 'OFS Positiva (Seguro)' },
                { value: 'Negativo/Inseguro', label: 'OFS Negativa (Inseguro)' },
              ]}
            />
            <Select
              label="Comportamento *"
              value={form.comportamento}
              onChange={(e) => setForm({ ...form, comportamento: e.target.value })}
              options={[
                { value: 'seguro', label: 'Seguro' },
                { value: 'inseguro', label: 'Inseguro' },
              ]}
            />
            <div className="md:col-span-2">
              <Input
                label="Observação"
                value={form.observacao}
                onChange={(e) => setForm({ ...form, observacao: e.target.value })}
              />
            </div>
          </div>
        </Card>

        {current?.historico && current.historico.length > 0 && (
          <Card title="Histórico de Edições">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b text-left">
                    <th className="pb-2 text-xs text-gray-500">Campo</th>
                    <th className="pb-2 text-xs text-gray-500">Anterior</th>
                    <th className="pb-2 text-xs text-gray-500">Novo</th>
                    <th className="pb-2 text-xs text-gray-500">Por</th>
                    <th className="pb-2 text-xs text-gray-500">Em</th>
                  </tr>
                </thead>
                <tbody>
                  {current.historico.map((h) => (
                    <tr key={h.id} className="border-b border-gray-50 last:border-0">
                      <td className="py-2 font-medium">{h.campo}</td>
                      <td className="py-2 text-gray-500">{h.valor_anterior || '-'}</td>
                      <td className="py-2">{h.valor_novo}</td>
                      <td className="py-2 text-gray-500">{h.editado_por}</td>
                      <td className="py-2 text-gray-500">{new Date(h.editado_em).toLocaleString('pt-BR')}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        )}

        <div className="flex gap-3">
          <Button type="submit" loading={loading}>
            <Save className="h-4 w-4" /> Salvar Alterações
          </Button>
          <Button variant="ghost" onClick={() => navigate(-1)}>
            Cancelar
          </Button>
        </div>
      </form>
    </div>
  );
}
