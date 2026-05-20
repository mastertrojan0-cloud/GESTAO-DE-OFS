import { create } from 'zustand';
import api from '@/lib/api';
import type { OFS, OFSFiltros, ApiResponse } from '@/types';

interface OFSState {
  ofss: OFS[];
  current: OFS | null;
  loading: boolean;
  error: string | null;
  total: number;
  filtros: OFSFiltros;
  buscarOFSs: (filtros?: OFSFiltros) => Promise<void>;
  buscarPorId: (id: string) => Promise<void>;
  criar: (data: Partial<OFS>) => Promise<OFS>;
  atualizar: (id: string, data: Partial<OFS>) => Promise<void>;
  cancelar: (id: string) => Promise<void>;
  setFiltros: (filtros: Partial<OFSFiltros>) => void;
  limparFiltros: () => void;
}

export const useOFSStore = create<OFSState>((set, get) => ({
  ofss: [],
  current: null,
  loading: false,
  error: null,
  total: 0,
  filtros: { limit: 20, page: 1, order_by: 'data', order_dir: 'desc' },

  buscarOFSs: async (filtros?: OFSFiltros) => {
    set({ loading: true, error: null });
    try {
      const params = filtros || get().filtros;
      const res = await api.get<ApiResponse<OFS[]>>('/ofs', { params });
      set({
        ofss: res.data.data,
        total: res.data.total || 0,
        loading: false,
        filtros: params,
      });
    } catch (err: unknown) {
      const e = err as { userMessage?: string };
      set({ error: e.userMessage || 'Erro ao carregar OFSs', loading: false });
    }
  },

  buscarPorId: async (id: string) => {
    set({ loading: true, error: null });
    try {
      const res = await api.get<OFS>(`/ofs/${id}`);
      set({ current: res.data, loading: false });
    } catch (err: unknown) {
      const e = err as { userMessage?: string };
      set({ error: e.userMessage || 'Erro ao carregar OFS', loading: false });
    }
  },

  criar: async (data: Partial<OFS>) => {
    set({ loading: true, error: null });
    try {
      const res = await api.post<OFS>('/ofs', data);
      set({ loading: false });
      return res.data;
    } catch (err: unknown) {
      const e = err as { userMessage?: string };
      set({ error: e.userMessage || 'Erro ao criar OFS', loading: false });
      throw err;
    }
  },

  atualizar: async (id: string, data: Partial<OFS>) => {
    set({ loading: true, error: null });
    try {
      await api.put(`/ofs/${id}`, data);
      set({ loading: false });
    } catch (err: unknown) {
      const e = err as { userMessage?: string };
      set({ error: e.userMessage || 'Erro ao atualizar OFS', loading: false });
      throw err;
    }
  },

  cancelar: async (id: string) => {
    set({ loading: true, error: null });
    try {
      await api.patch(`/ofs/${id}/cancelar`);
      set({ loading: false });
    } catch (err: unknown) {
      const e = err as { userMessage?: string };
      set({ error: e.userMessage || 'Erro ao cancelar OFS', loading: false });
      throw err;
    }
  },

  setFiltros: (filtros: Partial<OFSFiltros>) => {
    set((s) => ({ filtros: { ...s.filtros, ...filtros, page: 1 } }));
  },

  limparFiltros: () => {
    set({ filtros: { limit: 20, page: 1, order_by: 'data', order_dir: 'desc' } });
  },
}));

