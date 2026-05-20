import { useAuthStore } from '@/stores/authStore';
import type { Perfil } from '@/types';
import { Navigate, useLocation } from 'react-router-dom';

interface ProtectedRouteProps {
  children: React.ReactNode;
  perfis?: Perfil[];
  perfilMinimo?: Perfil;
}

export function ProtectedRoute({ children, perfis, perfilMinimo }: ProtectedRouteProps) {
  const { isAuthenticated, user, hasPerfilMinimo } = useAuthStore();
  const location = useLocation();

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  if (perfis && user && !perfis.includes(user.perfil)) {
    return <Navigate to="/" replace />;
  }

  if (perfilMinimo && user && !hasPerfilMinimo(perfilMinimo)) {
    return <Navigate to="/" replace />;
  }

  return <>{children}</>;
}
