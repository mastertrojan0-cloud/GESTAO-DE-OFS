import { create } from 'zustand';
import type { Usuario, Perfil, LoginResponse, LoginError } from '@/types';
import { PERFIL_RANK } from '@/types';

interface AuthState {
  user: Usuario | null;
  accessToken: string | null;
  refreshToken: string | null;
  isAuthenticated: boolean;
  loginError: string | null;
  loginLoading: boolean;

  login: (username: string, password: string) => Promise<void>;
  logout: (options?: { expired?: boolean }) => void;
  refreshSession: () => Promise<string | null>;
  setTokens: (access: string, refresh: string) => void;
  hasPerfil: (...perfis: Perfil[]) => boolean;
  hasPerfilMinimo: (perfil: Perfil) => boolean;
  clearLoginError: () => void;
}

function loadTokens(): { access: string | null; refresh: string | null } {
  try {
    const access = localStorage.getItem('access_token');
    const refresh = localStorage.getItem('refresh_token');
    if (access && refresh) {
      return { access, refresh };
    }
    // fallback: legacy single token
    const legacy = localStorage.getItem('token');
    if (legacy) {
      localStorage.setItem('access_token', legacy);
      localStorage.removeItem('token');
      return { access: legacy, refresh: null };
    }
    return { access: null, refresh: null };
  } catch {
    return { access: null, refresh: null };
  }
}

function loadUser(): Usuario | null {
  try {
    const raw = localStorage.getItem('user');
    if (!raw || raw === 'null' || raw === 'undefined') return null;
    return JSON.parse(raw) as Usuario;
  } catch {
    return null;
  }
}

function persistTokens(access: string, refresh: string) {
  localStorage.setItem('access_token', access);
  localStorage.setItem('refresh_token', refresh);
}

function clearTokens() {
  localStorage.removeItem('access_token');
  localStorage.removeItem('refresh_token');
  localStorage.removeItem('token');
  localStorage.removeItem('user');
}

const { access, refresh } = loadTokens();
const initialUser = loadUser();
const validSession = !!(access && initialUser);

export const useAuthStore = create<AuthState>((set, get) => ({
  user: initialUser,
  accessToken: access,
  refreshToken: refresh,
  isAuthenticated: validSession,
  loginError: null,
  loginLoading: false,

  login: async (username: string, password: string) => {
    set({ loginLoading: true, loginError: null });
    try {
      const { default: api } = await import('@/lib/api');
      const form = new URLSearchParams();
      form.append('username', username);
      form.append('password', password);
      const res = await api.post<LoginResponse>('/auth/login', form, {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      });
      const { access_token, refresh_token, user } = res.data;
      localStorage.setItem('user', JSON.stringify(user));
      persistTokens(access_token, refresh_token);
      set({
        user,
        accessToken: access_token,
        refreshToken: refresh_token,
        isAuthenticated: true,
        loginLoading: false,
        loginError: null,
      });
    } catch (err: unknown) {
      const e = err as { response?: { status?: number; data?: LoginError } };
      const status = e.response?.status;
      const data = e.response?.data;

      let loginError = 'Usuário ou senha inválidos.';
      if (status === 401 && data?.detail) {
        loginError = data.detail;
      } else if (status === 403 && data?.detail) {
        loginError = data.detail;
      } else if (status === 429) {
        loginError = 'Muitas tentativas. Aguarde antes de tentar novamente.';
      }

      set({ loginLoading: false, loginError });
      throw err;
    }
  },

  logout: (options) => {
    const { accessToken, refreshToken } = get();
    // attempt server-side logout (fire & forget)
    if (accessToken && !options?.expired) {
      import('@/lib/api').then(({ default: api }) => {
        api.post('/auth/logout', { refresh_token: refreshToken }).catch(() => {});
      });
    }
    clearTokens();
    set({
      user: null,
      accessToken: null,
      refreshToken: null,
      isAuthenticated: false,
      loginError: null,
      loginLoading: false,
    });
  },

  refreshSession: async () => {
    const { refreshToken } = get();
    if (!refreshToken) {
      get().logout({ expired: true });
      return null;
    }
    try {
      const { default: api } = await import('@/lib/api');
      const res = await api.post<LoginResponse>('/auth/refresh', {
        refresh_token: refreshToken,
      });
      const { access_token, refresh_token } = res.data;
      persistTokens(access_token, refresh_token);
      set({ accessToken: access_token, refreshToken: refresh_token });
      return access_token;
    } catch {
      get().logout({ expired: true });
      return null;
    }
  },

  setTokens: (access, refresh) => {
    persistTokens(access, refresh);
    set({ accessToken: access, refreshToken: refresh });
  },

  hasPerfil: (...perfis) => {
    const { user } = get();
    return user ? perfis.includes(user.perfil) : false;
  },

  hasPerfilMinimo: (perfil) => {
    const { user } = get();
    if (!user) return false;
    return PERFIL_RANK[user.perfil] >= PERFIL_RANK[perfil];
  },

  clearLoginError: () => set({ loginError: null }),
}));
