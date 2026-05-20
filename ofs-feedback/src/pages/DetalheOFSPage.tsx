import { useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useOFSStore } from '@/stores/ofsStore';
import { useAuthStore } from '@/stores/authStore';
import { Card, Badge, Button, Spinner } from '@/components/ui';
import { ArrowLeft, Edit, XCircle } from 'lucide-react';
import { format, parseISO } from 'date-fns';

export default function DetalheOFSPage() {
  const { id } = useParams<{ id: string }>();
  const { current, loading, error, buscarPorId, cancelar } = useOFSStore();
  const { user } = useAuthStore();
  const navigate = useNavigate();

  useEffect(() => {
    if (id) buscarPorId(id);
  }, [id]);

  const podeEditar = current && (
    user?.perfil === 'admin' ||
    user?.perfil === 'gestor' ||
    (user?.perfil === 'supervisor' && current.empresa_id === user.empresa_id && current.status === 'ativo') ||
    (user?.perfil === 'observador' && current.usuario_gerador_id === user.id && current.status === 'ativo')
  );

  const podeCancelar = current && current.status === 'ativo' && (
    user?.perfil === 'gestor' || user?.perfil === 'admin'
  );

  async function handleCancelar() {
    if (!id || !confirm('Tem certeza que deseja cancelar esta OFS?')) return;
    try {
      await cancelar(id);
      buscarPorId(id);
    } catch {}
  }

  if (loading) return <div className="flex justify-center py-16"><Spinner size="lg" /></div>;
  if (error) return <div className="p-6 text-danger font-medium">{error}</div>;
  if (!current) return null;

  const tipoLabel = (tipo: string | undefined) => {
    if (tipo === 'Positivo/Seguro' || tipo === 'seguro') return 'OFS Positiva (Seguro)';
    if (tipo === 'Negativo/Inseguro' || tipo === 'inseguro' || tipo === 'desvio') return 'OFS Negativa (Inseguro)';
    return tipo || '-';
  };

  const tipoVariant = (tipo: string | undefined) => {
    if (tipo === 'Positivo/Seguro' || tipo === 'seguro') return 'success' as const;
    return 'danger' as const;
  };

  const info = [
    { label: 'ID', value: current.id },
    { label: 'Data', value: format(parseISO(current.data), 'dd/MM/yyyy') },
    { label: 'Hora', value: current.hora },
    { label: 'Gerado por', value: current.usuario_gerador_nome },
    { label: 'Nome Observado', value: current.nome_observado },
    { label: 'Atividade', value: current.atividade || '-' },
    { label: 'Local', value: current.local || '-' },
    { label: 'Empresa', value: current.empresa_nome },
    { label: 'Contrato', value: current.contrato_nome || '-' },
    { label: 'Turno', value: current.turno },
    {
      label: 'Tipo',
      value: (
        <Badge variant={tipoVariant(current.tipo || current.tipo_observacao)}>
          {tipoLabel(current.tipo || current.tipo_observacao)}
        </Badge>
      ),
    },
    {
      label: 'Comportamento',
      value: (
        <Badge variant={tipoVariant(current.comportamento)}>
          {tipoLabel(current.comportamento)}
        </Badge>
      ),
    },
    {
      label: 'Status',
      value: (
        <Badge variant={current.status === 'ativo' ? 'success' : 'neutral'}>
          {current.status === 'ativo' ? 'Ativo' : 'Cancelado'}
        </Badge>
      ),
    },
    { label: 'Observação', value: current.observacao || '-' },
  ];

  return (
    <div className="space-y-6 max-w-3xl">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-brand-black">Detalhe OFS</h1>
          <p className="text-sm text-gray-500 mt-1">{current.id}</p>
        </div>
        <div className="flex gap-2">
          <Button variant="ghost" size="sm" onClick={() => navigate(-1)}>
            <ArrowLeft className="h-4 w-4" /> Voltar
          </Button>
          {podeEditar && (
            <Button size="sm" onClick={() => navigate(`/ofs/${id}/editar`)}>
              <Edit className="h-4 w-4" /> Editar
            </Button>
          )}
          {podeCancelar && (
            <Button variant="danger" size="sm" onClick={handleCancelar}>
              <XCircle className="h-4 w-4" /> Cancelar
            </Button>
          )}
        </div>
      </div>

      <Card title="Dados do Registro">
        <dl className="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-3">
          {info.map(({ label, value }) => (
            <div key={label}>
              <dt className="text-xs text-gray-500">{label}</dt>
              <dd className="text-sm font-medium text-brand-black mt-0.5">{value}</dd>
            </div>
          ))}
        </dl>
      </Card>

      {current.updated_at !== current.created_at && (
        <Card title="Última Alteração">
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <span className="text-xs text-gray-500">Editado em</span>
              <p>{current.editado_em ? format(parseISO(current.editado_em), 'dd/MM/yyyy HH:mm') : '-'}</p>
            </div>
            <div>
              <span className="text-xs text-gray-500">Editado por</span>
              <p>{current.editado_por || '-'}</p>
            </div>
          </div>
        </Card>
      )}

      {current.historico && current.historico.length > 0 && (
        <Card title="Histórico de Edições">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 text-left">
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
                    <td className="py-2 text-gray-500">{format(parseISO(h.editado_em), 'dd/MM HH:mm')}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}
    </div>
  );
}
