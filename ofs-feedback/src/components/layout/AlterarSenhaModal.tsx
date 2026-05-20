import { useState, type FormEvent } from 'react';
import api from '@/lib/api';
import { Button, Input } from '@/components/ui';
import { Lock, CheckCircle2, XCircle } from 'lucide-react';

interface AlterarSenhaModalProps {
  open: boolean;
  onClose: () => void;
}

export function AlterarSenhaModal({ open, onClose }: AlterarSenhaModalProps) {
  const [senhaAtual, setSenhaAtual] = useState('');
  const [novaSenha, setNovaSenha] = useState('');
  const [confirmar, setConfirmar] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  if (!open) return null;

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');

    if (!senhaAtual || !novaSenha || !confirmar) {
      setError('Preencha todos os campos.');
      return;
    }
    if (novaSenha !== confirmar) {
      setError('As senhas não conferem.');
      return;
    }
    if (novaSenha.length < 6) {
      setError('A nova senha deve ter no mínimo 6 caracteres.');
      return;
    }

    setLoading(true);
    try {
      await api.put('/auth/alterar-senha', {
        senha_atual: senhaAtual,
        nova_senha: novaSenha,
      });
      setSuccess(true);
      setTimeout(() => {
        setSuccess(false);
        setSenhaAtual('');
        setNovaSenha('');
        setConfirmar('');
        onClose();
      }, 1500);
    } catch (err: unknown) {
      const e = err as { userMessage?: string };
      setError(e.userMessage || 'Erro ao alterar senha.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <>
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
        <div
          className="w-full max-w-md rounded-xl bg-surface shadow-xl animate-in"
          onClick={(e) => e.stopPropagation()}
        >
          <div className="flex items-center gap-3 px-5 py-4 border-b border-gray-100">
            <Lock className="h-5 w-5 text-brand-red" />
            <h2 className="text-lg font-semibold text-brand-black">Alterar Senha</h2>
          </div>

          <form onSubmit={handleSubmit} className="p-5 space-y-4">
            {success && (
              <div className="flex items-center gap-2 text-sm rounded-lg bg-green-50 text-green-800 border border-green-200 px-3 py-2.5">
                <CheckCircle2 className="h-4 w-4" />
                Senha alterada com sucesso!
              </div>
            )}

            {error && (
              <div className="flex items-center gap-2 text-sm rounded-lg bg-red-50 text-red-800 border border-red-200 px-3 py-2.5">
                <XCircle className="h-4 w-4" />
                {error}
              </div>
            )}

            <Input
              id="senha_atual"
              type="password"
              label="Senha atual"
              value={senhaAtual}
              onChange={(e) => setSenhaAtual(e.target.value)}
              autoComplete="current-password"
            />

            <Input
              id="nova_senha"
              type="password"
              label="Nova senha"
              value={novaSenha}
              onChange={(e) => setNovaSenha(e.target.value)}
              autoComplete="new-password"
            />

            <Input
              id="confirmar_senha"
              type="password"
              label="Confirmar nova senha"
              value={confirmar}
              onChange={(e) => setConfirmar(e.target.value)}
              autoComplete="new-password"
            />

            <div className="flex gap-3 pt-2">
              <Button type="submit" loading={loading} className="flex-1">
                <Lock className="h-4 w-4" />
                Alterar Senha
              </Button>
              <Button variant="ghost" type="button" onClick={onClose} className="flex-1">
                Cancelar
              </Button>
            </div>
          </form>
        </div>
      </div>
    </>
  );
}
