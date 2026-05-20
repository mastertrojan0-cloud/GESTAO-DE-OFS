import { useState, useEffect, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { useOFSStore } from '@/stores/ofsStore';
import { useAuthStore } from '@/stores/authStore';
import api from '@/lib/api';
import { Button, Input, Select, Card } from '@/components/ui';
import { Save, Plus, CheckCircle2, XCircle } from 'lucide-react';
import type { Empresa, TipoOFS, Turno } from '@/types';
import { EMPRESAS_FALLBACK, filtrarEmpresasSelect } from '@/lib/empresasFallback';
import { format } from 'date-fns';

interface ToastState {
  show: boolean;
  type: 'success' | 'error';
  message: string;
}

export default function NovoOFSPage() {
  const [form, setForm] = useState({
    atividade: '',
    local: '',
    empresa_id: '',
    empresa_outros: '',
    turno: '' as Turno | '',
    tipo: '' as TipoOFS | '',
    comportamento: '',
    observacao: '',
  });
  const [empresas, setEmpresas] = useState<Empresa[]>([]);
  const [toast, setToast] = useState<ToastState>({ show: false, type: 'success', message: '' });
  const { criar, loading } = useOFSStore();
  const { user } = useAuthStore();
  const navigate = useNavigate();

  useEffect(() => {
    api.get('/empresas?ativos=true')
      .then((r) => {
        const lista: Empresa[] = r.data.data || r.data || [];
        setEmpresas(filtrarEmpresasSelect(lista));
      })
      .catch(() => setEmpresas(EMPRESAS_FALLBACK));
  }, []);

  const handleField = (field: string, value: string) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  async function handleSubmit(e: FormEvent, saveAndNew: boolean) {
    e.preventDefault();
    if (!form.empresa_id || !form.turno || !form.tipo || !form.comportamento) {
      setToast({ show: true, type: 'error', message: 'Preencha todos os campos obrigatórios.' });
      return;
    }

    const empresaNome = form.empresa_id === 'outros'
      ? form.empresa_outros
      : empresas.find((e) => e.id === form.empresa_id)?.nome || '';

    try {
      await criar({
        nome_observado: 'Não informado',
        atividade: form.atividade,
        local: form.local,
        empresa_id: form.empresa_id,
        empresa_nome: empresaNome,
        turno: form.turno as Turno,
        tipo: form.tipo as TipoOFS,
        comportamento: form.comportamento,
        observacao: form.observacao,
      });

      setToast({ show: true, type: 'success', message: 'OFS registrada com sucesso!' });

      if (saveAndNew) {
        setForm({
          atividade: '',
          local: '',
          empresa_id: '',
          empresa_outros: '',
          turno: '' as Turno | '',
          tipo: '' as TipoOFS | '',
          comportamento: '',
          observacao: '',
        });
      } else {
        setTimeout(() => navigate('/ofs'), 800);
      }
    } catch {
      setToast({ show: true, type: 'error', message: 'Erro ao salvar OFS.' });
    }
  }

  const hoje = format(new Date(), "dd/MM/yyyy '-' HH:mm");

  return (
    <div className="space-y-6 max-w-2xl">
      <div>
        <h1 className="text-2xl font-bold text-brand-black">Nova OFS</h1>
        <p className="text-sm text-gray-500 mt-1">Registre rapidamente um feedback comportamental</p>
      </div>

      {toast.show && (
        <div
          className={`flex items-center gap-2 rounded-lg px-4 py-3 text-sm font-medium ${
            toast.type === 'success'
              ? 'bg-green-50 text-green-800 border border-green-200'
              : 'bg-red-50 text-red-800 border border-red-200'
          }`}
        >
          {toast.type === 'success' ? (
            <CheckCircle2 className="h-4 w-4" />
          ) : (
            <XCircle className="h-4 w-4" />
          )}
          {toast.message}
          <button className="ml-auto text-sm underline" onClick={() => setToast({ ...toast, show: false })}>
            Fechar
          </button>
        </div>
      )}

      <form className="space-y-5">
        <Card title="Informações Automáticas">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <span className="text-xs text-gray-500">ID</span>
              <p className="text-sm font-medium text-gray-400">Automático</p>
            </div>
            <div>
              <span className="text-xs text-gray-500">Data / Hora</span>
              <p className="text-sm font-medium text-gray-400">{hoje}</p>
            </div>
            <div className="col-span-2">
              <span className="text-xs text-gray-500">Gerado por</span>
              <p className="text-sm font-medium text-gray-400">{user?.nome || user?.username}</p>
            </div>
          </div>
        </Card>

        <Card title="Dados da OFS">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Input
              label="Atividade"
              value={form.atividade}
              onChange={(e) => handleField('atividade', e.target.value)}
              placeholder="Atividade realizada"
            />

            <Input
              label="Local"
              value={form.local}
              onChange={(e) => handleField('local', e.target.value)}
              placeholder="Local da observação"
            />

            <Select
              label="Empresa *"
              value={form.empresa_id}
              onChange={(e) => handleField('empresa_id', e.target.value)}
              options={[
                ...empresas.map((e) => ({ value: e.id, label: e.nome })),
                { value: 'outros', label: 'Outros' },
              ]}
            />

            {form.empresa_id === 'outros' && (
              <Input
                label="Nome da Empresa *"
                value={form.empresa_outros}
                onChange={(e) => handleField('empresa_outros', e.target.value)}
                placeholder="Digite o nome da empresa"
              />
            )}

            <Select
              label="Turno *"
              value={form.turno}
              onChange={(e) => handleField('turno', e.target.value)}
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
              onChange={(e) => handleField('tipo', e.target.value)}
              options={[
                { value: 'Positivo/Seguro', label: 'OFS Positiva (Seguro)' },
                { value: 'Negativo/Inseguro', label: 'OFS Negativa (Inseguro)' },
              ]}
            />

            <div className="md:col-span-2">
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Comportamento Observado *
              </label>
              <textarea
                value={form.comportamento}
                onChange={(e) => handleField('comportamento', e.target.value)}
                placeholder="Descreva o comportamento observado em detalhes"
                rows={4}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-red-600 focus:ring-1 focus:ring-red-600"
                required
              />
            </div>

            <div className="md:col-span-2">
              <Input
                label="Observação Complementar"
                value={form.observacao}
                onChange={(e) => handleField('observacao', e.target.value)}
                placeholder="Informações adicionais (opcional)"
              />
            </div>
          </div>
        </Card>

        <div className="flex gap-3">
          <Button type="submit" loading={loading} onClick={(e) => handleSubmit(e, false)}>
            <Save className="h-4 w-4" />
            Salvar
          </Button>
          <Button
            type="submit"
            variant="outline"
            loading={loading}
            onClick={(e) => handleSubmit(e, true)}
          >
            <Plus className="h-4 w-4" />
            Salvar e Novo
          </Button>
        </div>
      </form>
    </div>
  );
}
