import { useAuthStore } from '@/stores/authStore';
import type { Perfil } from '@/types';

interface PermissionGateProps {
  children: React.ReactNode;
  perfis: Perfil[];
  fallback?: React.ReactNode;
}

export function PermissionGate({ children, perfis, fallback = null }: PermissionGateProps) {
  const { user } = useAuthStore();
  if (!user || !perfis.includes(user.perfil)) {
    return <>{fallback}</>;
  }
  return <>{children}</>;
}
