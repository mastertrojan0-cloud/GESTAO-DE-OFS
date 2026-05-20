import { useState, useEffect, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '@/lib/api';
import { Button, Input, Select, Card } from '@/components/ui';
import { Save, ArrowLeft, CheckCircle2, XCircle } from 'lucide-react';
import type { Empresa, Perfil } from '@/types';
import { EMPRESAS_FALLBACK, filtrarEmpresasSelect } from '@/lib/empresasFallback';

interface ToastState {
  show: boolean;
  type: 'success' | 'error';
  message: string;
}

const PERFIS: { value: Perfil; label: string }[] = [
  { value: 'observador', label: 'Observador' },
  { value: 'supervisor', label: 'Supervisor' },
  { value: 'gestor', label: 'Gestor' },
  { value: 'admin', label: 'Admin' },
];

export default function NovoUsuarioPage() {
  const navigate = useNavigate();
  const [empresas, setEmpresas] = useState<Empresa[]>([]);
  const [loading, setLoading] = useState(false);
  const [toast, setToast] = useState<ToastState>({ show: false, type: 'success', message: '' });
  const [form, setForm] = useState({
    username: '',
    nome: '',
    email: '',
    perfil: 'observador' as Perfil,
    empresa_id: '',
    password: '',
    confirmPassword: '',
    ativo: true,
  });

  useEffect(() => {
    api.get('/empresas?ativos=true')
      .then((r) => {
        const lista: Empresa[] = r.data.data || r.data || [];
        setEmpresas(filtrarEmpresasSelect(lista));
      })
      .catch(() => setEmpresas(EMPRESAS_FALLBACK));
  }, []);

  function setField<K extends keyof typeof form>(key: K, value: typeof form[K]) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!form.username.trim() || !form.nome.trim() || !form.password || !form.empresa_id) {
      setToast({ show: true, type: 'error', message: 'Preencha todos os campos obrigatórios.' });
      return;
    }
    if (form.password.length < 8) {
      setToast({ show: true, type: 'error', message: 'A senha deve ter pelo menos 8 caracteres.' });
      return;
    }
    if (form.password !== form.confirmPassword) {
      setToast({ show: true, type: 'error', message: 'A confirmação de senha não confere.' });
      return;
    }

    const empresaNome = empresas.find((e) => e.id === form.empresa_id)?.nome || '';

    setLoading(true);
    try {
      await api.post('/admin/usuarios', {
        username: form.username.trim(),
        nome: form.nome.trim(),
        email: form.email.trim() || null,
        perfil: form.perfil,
        empresa_id: form.empresa_id,
        empresa_nome: empresaNome,
        password: form.password,
        ativo: form.ativo,
      });
      setToast({ show: true, type: 'success', message: 'Usuário cadastrado com sucesso!' });
      setTimeout(() => navigate('/admin/usuarios'), 800);
    } catch (err: unknown) {
      const e = err as { userMessage?: string };
      setToast({ show: true, type: 'error', message: e.userMessage || 'Erro ao cadastrar usuário.' });
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-6 max-w-2xl">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="sm" onClick={() => navigate('/admin/usuarios')}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <div>
          <h1 className="text-2xl font-bold text-brand-black">Novo Usuário</h1>
          <p className="text-sm text-gray-500 mt-1">Cadastro de usuário do sistema</p>
        </div>
      </div>

      {toast.show && (
        <div
          className={`flex items-center gap-2 rounded-lg px-4 py-3 text-sm font-medium ${
            toast.type === 'success'
              ? 'bg-green-50 text-green-800 border border-green-200'
              : 'bg-red-50 text-red-800 border border-red-200'
          }`}
        >
          {toast.type === 'success' ? <CheckCircle2 className="h-4 w-4" /> : <XCircle className="h-4 w-4" />}
          {toast.message}
          <button className="ml-auto text-sm underline" onClick={() => setToast({ ...toast, show: false })}>
            Fechar
          </button>
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-5">
        <Card title="Identificação">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Input
              label="Usuário (login) *"
              value={form.username}
              onChange={(e) => setField('username', e.target.value)}
              placeholder="ex.: joao.silva"
              autoComplete="off"
            />
            <Input
              label="Nome Completo *"
              value={form.nome}
              onChange={(e) => setField('nome', e.target.value)}
              placeholder="Nome completo"
            />
            <Input
              label="Email"
              type="email"
              value={form.email}
              onChange={(e) => setField('email', e.target.value)}
              placeholder="email@exemplo.com"
            />
            <Select
              label="Perfil *"
              value={form.perfil}
              onChange={(e) => setField('perfil', e.target.value as Perfil)}
              options={PERFIS}
            />
            <Select
              label="Empresa *"
              value={form.empresa_id}
              onChange={(e) => setField('empresa_id', e.target.value)}
              options={empresas.map((e) => ({ value: e.id, label: e.nome }))}
            />
            <Select
              label="Status"
              value={form.ativo ? '1' : '0'}
              onChange={(e) => setField('ativo', e.target.value === '1')}
              options={[
                { value: '1', label: 'Ativo' },
                { value: '0', label: 'Inativo' },
              ]}
            />
          </div>
        </Card>

        <Card title="Senha de acesso">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Input
              label="Senha *"
              type="password"
              value={form.password}
              onChange={(e) => setField('password', e.target.value)}
              placeholder="Mínimo 8 caracteres"
              autoComplete="new-password"
            />
            <Input
              label="Confirmar Senha *"
              type="password"
              value={form.confirmPassword}
              onChange={(e) => setField('confirmPassword', e.target.value)}
              placeholder="Repita a senha"
              autoComplete="new-password"
            />
          </div>
          <p className="text-xs text-gray-500 mt-2">
            O usuário poderá fazer login na rede local com estas credenciais.
          </p>
        </Card>

        <div className="flex gap-3">
          <Button type="submit" loading={loading}>
            <Save className="h-4 w-4" />
            Salvar
          </Button>
          <Button type="button" variant="ghost" onClick={() => navigate('/admin/usuarios')}>
            Cancelar
          </Button>
        </div>
      </form>
    </div>
  );
}
