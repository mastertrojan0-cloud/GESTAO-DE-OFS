import axios, { type AxiosError, type InternalAxiosRequestConfig } from 'axios';

const api = axios.create({
  baseURL: '/api',
  headers: { 'Content-Type': 'application/json' },
});

// ── Request interceptor: inject access token ──
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('access_token')
    || localStorage.getItem('token'); // legacy fallback
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// ── Refresh token queue (prevents concurrent refresh calls) ──
let isRefreshing = false;
let failedQueue: Array<{
  resolve: (token: string | null) => void;
  reject: (error: unknown) => void;
}> = [];

function processQueue(error: unknown, token: string | null = null) {
  failedQueue.forEach(({ resolve, reject }) => {
    if (error) {
      reject(error);
    } else {
      resolve(token);
    }
  });
  failedQueue = [];
}

// ── Response interceptor: 401 → refresh → retry ──
api.interceptors.response.use(
  (response) => response,
  async (error: AxiosError<{ detail?: string; message?: string }>) => {
    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };
    const status = error.response?.status;

    // 401: try refresh once, then retry
    if (status === 401 && !originalRequest._retry) {
      if (isRefreshing) {
        // join the existing refresh attempt
        return new Promise((resolve, reject) => {
          failedQueue.push({
            resolve: (token: string | null) => {
              if (token) {
                originalRequest.headers.Authorization = `Bearer ${token}`;
                resolve(api(originalRequest));
              } else {
                reject(new Error('Sessão expirada'));
              }
            },
            reject,
          });
        });
      }

      originalRequest._retry = true;
      isRefreshing = true;

      const refreshToken = localStorage.getItem('refresh_token');
      if (!refreshToken) {
        isRefreshing = false;
        // trigger global logout
        import('@/stores/authStore').then(({ useAuthStore }) => {
          useAuthStore.getState().logout({ expired: true });
        });
        window.location.href = '/login';
        return Promise.reject(error);
      }

      try {
        const res = await axios.post<{
          access_token: string;
          refresh_token: string;
        }>('/api/auth/refresh', { refresh_token: refreshToken });

        const newAccess = res.data.access_token;
        const newRefresh = res.data.refresh_token;
        localStorage.setItem('access_token', newAccess);
        localStorage.setItem('refresh_token', newRefresh);

        originalRequest.headers.Authorization = `Bearer ${newAccess}`;
        processQueue(null, newAccess);
        return api(originalRequest);
      } catch {
        processQueue(error, null);
        isRefreshing = false;
        // trigger global logout
        import('@/stores/authStore').then(({ useAuthStore }) => {
          useAuthStore.getState().logout({ expired: true });
        });
        window.location.href = '/login';
        return Promise.reject(error);
      }
    }

    // 403: forbidden
    if (status === 403) {
      return Promise.reject({
        ...error,
        userMessage: error.response?.data?.detail
          || 'Sem permissão para executar esta ação.',
      });
    }

    // extract detail message from FastAPI
    const message =
      error.response?.data?.detail ||
      error.response?.data?.message ||
      'Erro de conexão com o servidor.';

    return Promise.reject({
      ...error,
      userMessage: message,
    });
  }
);

export default api;
