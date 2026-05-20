import { useState, type FormEvent, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '@/stores/authStore';
import { Button, Input, Flag } from '@/components/ui';
import { LogIn, Lock, ShieldOff, CheckCircle2 } from 'lucide-react';
import type { Perfil } from '@/types';

const PERFIL_REDIRECT: Record<Perfil, string> = {
  observador: '/',
  supervisor: '/',
  gestor: '/metricas',
  admin: '/admin/usuarios',
};

export default function LoginPage() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const {
    login,
    loginLoading,
    loginError,
    clearLoginError,
    isAuthenticated,
    user,
  } = useAuthStore();
  const navigate = useNavigate();
  const [successVisible, setSuccessVisible] = useState(false);

  // redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated && user) {
      setSuccessVisible(true);
      const timer = setTimeout(() => {
        navigate(PERFIL_REDIRECT[user.perfil] || '/', { replace: true });
      }, 800);
      return () => clearTimeout(timer);
    }
  }, [isAuthenticated, user, navigate]);

  const trimmedUser = username.trim();
  const camposPreenchidos = trimmedUser && password.trim();

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!camposPreenchidos) return;
    try {
      await login(trimmedUser, password);
    } catch {
      // error is already stored in loginError via the store
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-brand-gray px-4 relative">
      <div className="w-full max-w-sm">
        {/* branding */}
        <div className="text-center mb-8">
          <div className="flex items-center justify-center gap-3 mb-3">
            <Flag country="VE" className="h-7 w-10 rounded shadow-sm ring-1 ring-gray-200" />
            <Flag country="BR" className="h-7 w-10 rounded shadow-sm ring-1 ring-gray-200" />
          </div>
          <h1 className="text-2xl font-bold text-brand-red tracking-wide">GESTÃO DE OFS</h1>
          <p className="text-sm text-gray-500 mt-1">Sistema de Feedback Comportamental</p>
        </div>

        {/* success state */}
        {successVisible && (
          <div className="rounded-xl bg-green-50 border border-green-200 p-4 mb-4 flex items-center gap-3 animate-in">
            <CheckCircle2 className="h-5 w-5 text-success flex-shrink-0" />
            <div>
              <p className="text-sm font-medium text-green-800">Login realizado com sucesso!</p>
              <p className="text-xs text-green-600">Redirecionando...</p>
            </div>
          </div>
        )}

        <form
          onSubmit={handleSubmit}
          className="rounded-xl bg-surface shadow-sm border border-gray-100 p-6 space-y-4"
        >
          <Input
            id="username"
            label="Usuário"
            placeholder="Seu nome de usuário"
            value={username}
            onChange={(e) => {
              setUsername(e.target.value);
              if (loginError) clearLoginError();
            }}
            autoComplete="username"
            autoFocus
            disabled={loginLoading}
          />

          <Input
            id="password"
            type="password"
            label="Senha"
            placeholder="Sua senha"
            value={password}
            onChange={(e) => {
              setPassword(e.target.value);
              if (loginError) clearLoginError();
            }}
            autoComplete="current-password"
            disabled={loginLoading}
          />

          {/* error: invalid credentials */}
          {loginError && !loginError.toLowerCase().includes('bloquead') && (
            <div className="flex items-start gap-2 text-sm text-danger bg-red-50 border border-red-200 rounded-lg px-3 py-2.5">
              <ShieldOff className="h-4 w-4 flex-shrink-0 mt-0.5" />
              <span>{loginError}</span>
            </div>
          )}

          {/* error: blocked */}
          {loginError && loginError.toLowerCase().includes('bloquead') && (
            <div className="flex items-start gap-2 text-sm bg-amber-50 text-amber-800 border border-amber-200 rounded-lg px-3 py-2.5">
              <Lock className="h-4 w-4 flex-shrink-0 mt-0.5" />
              <span>{loginError}</span>
            </div>
          )}

          <Button
            type="submit"
            loading={loginLoading}
            disabled={!camposPreenchidos || loginLoading}
            className="w-full"
            size="lg"
          >
            {!loginLoading && <LogIn className="h-4 w-4" />}
            {loginLoading ? 'Entrando...' : 'Entrar'}
          </Button>
        </form>

        <p className="text-center text-xs text-gray-400 mt-4">
          &copy; {new Date().getFullYear()} Antonio Martinez — Todos os direitos reservados
        </p>
      </div>

      {/* session expired floating indicator (hidden on login) */}
      <div
        className="fixed top-4 right-4 z-50 transition-all duration-300 pointer-events-none opacity-0"
        id="session-expired-toast"
      />
    </div>
  );
}
