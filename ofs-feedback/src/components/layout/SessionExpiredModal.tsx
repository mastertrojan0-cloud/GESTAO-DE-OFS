import { useEffect, useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '@/stores/authStore';
import { Modal, Button } from '@/components/ui';
import { AlertTriangle } from 'lucide-react';

export function SessionExpiredModal() {
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
  const logout = useAuthStore((s) => s.logout);
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const [countdown, setCountdown] = useState(5);
  const wasAuthenticated = useRef(isAuthenticated);

  // detect in-tab deauth (refresh failure, forced logout)
  useEffect(() => {
    if (wasAuthenticated.current && !isAuthenticated) {
      setOpen(true);
    }
    wasAuthenticated.current = isAuthenticated;
  }, [isAuthenticated]);

  // detect cross-tab logout via storage.clear
  useEffect(() => {
    const handler = (e: StorageEvent) => {
      if (e.key === null || e.key === 'access_token' || e.key === 'user') {
        if (!localStorage.getItem('access_token')) {
          if (useAuthStore.getState().isAuthenticated) {
            useAuthStore.getState().logout({ expired: true });
          }
          setOpen(true);
        }
      }
    };
    window.addEventListener('storage', handler);
    return () => window.removeEventListener('storage', handler);
  }, []);

  useEffect(() => {
    if (open && countdown > 0) {
      const timer = setInterval(() => {
        setCountdown((prev) => prev - 1);
      }, 1000);
      return () => clearInterval(timer);
    }
    if (open && countdown === 0) {
      navigate('/login', { replace: true });
    }
  }, [open, countdown, navigate]);

  function handleRedirect() {
    setOpen(false);
    navigate('/login', { replace: true });
  }

  if (!open) return null;

  return (
    <Modal open={open} onClose={handleRedirect} title="Sessao Expirada" size="sm">
      <div className="text-center space-y-4">
        <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-amber-100">
          <AlertTriangle className="h-6 w-6 text-amber-600" />
        </div>
        <div>
          <p className="text-sm font-medium text-brand-black">
            Sua sessao expirou por inatividade.
          </p>
          <p className="text-xs text-gray-500 mt-1">
            Voce sera redirecionado para o login em {countdown}s
          </p>
        </div>
        <Button onClick={handleRedirect} size="sm" className="w-full">
          Ir para o Login
        </Button>
      </div>
    </Modal>
  );
}
