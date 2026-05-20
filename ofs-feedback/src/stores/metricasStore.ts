import { create } from 'zustand';
import api from '@/lib/api';
import type { MetricasSemana, EmpresaConsolidada } from '@/types';

type GrafData = { name: string; value: number; color?: string }[];

interface MetricasState {
  metricas: MetricasSemana | null;
  loading: boolean;
  error: string | null;
  metaNaoCadastrada: boolean;
  consolidado: EmpresaConsolidada[];
  consolidadoLoading: boolean;
  graficos: {
    programadoRealizado: GrafData;
    positivoNegativo: GrafData;
    porEmpresa: GrafData;
    evolucaoSemanal: Record<string, unknown>[];
  };

  empresas: { value: string; label: string }[];
  contratos: { value: string; label: string }[];
  usuarios: { value: string; label: string }[];

  loadMetricas: (params: Record<string, string>) => Promise<void>;
  loadConsolidado: (params: Record<string, string>) => Promise<void>;
  loadEmpresas: () => Promise<void>;
  loadContratos: (empresaId?: string) => Promise<void>;
  loadUsuarios: () => Promise<void>;
  reset: () => void;
}

const initialState = {
  metricas: null,
  loading: false,
  error: null,
  metaNaoCadastrada: false,
  consolidado: [],
  consolidadoLoading: false,
  graficos: {
    programadoRealizado: [],
    positivoNegativo: [],
    porEmpresa: [],
    evolucaoSemanal: [],
  },
  empresas: [],
  contratos: [],
  usuarios: [],
};

export const useMetricasStore = create<MetricasState>((set) => ({
  ...initialState,

  loadMetricas: async (params) => {
    set({ loading: true, error: null, metaNaoCadastrada: false });
    try {
      const [metRes, grafRes] = await Promise.all([
        api.get('/metricas/semana', { params }),
        api.get('/metricas/graficos', { params }),
      ]);

      const met = metRes.data as MetricasSemana;
      set({
        metricas: met,
        graficos: grafRes.data,
        metaNaoCadastrada: !met.meta_cadastrada,
        loading: false,
      });
    } catch (err: unknown) {
      const e = err as { userMessage?: string; status?: number };
      if (e.status === 404) {
        set({ metricas: null, metaNaoCadastrada: true, loading: false });
      } else {
        set({
          error: e.userMessage || 'Erro ao carregar métricas da semana.',
          loading: false,
        });
      }
    }
  },

  loadConsolidado: async (params) => {
    set({ consolidadoLoading: true });
    try {
      const res = await api.get('/metricas/consolidado', { params });
      set({ consolidado: res.data.data || res.data || [], consolidadoLoading: false });
    } catch {
      set({ consolidado: [], consolidadoLoading: false });
    }
  },

  loadEmpresas: async () => {
    try {
      const res = await api.get('/empresas');
      const data = res.data.data || res.data || [];
      set({ empresas: data.map((e: { id: string; nome: string }) => ({ value: e.id, label: e.nome })) });
    } catch { /* silent */ }
  },

  loadContratos: async (empresaId?: string) => {
    try {
      const params: Record<string, string> = {};
      if (empresaId) params.empresa_id = empresaId;
      const res = await api.get('/contratos', { params });
      const data = res.data.data || res.data || [];
      set({ contratos: data.map((c: { id: string; nome: string }) => ({ value: c.id, label: c.nome })) });
    } catch { /* silent */ }
  },

  loadUsuarios: async () => {
    try {
      const res = await api.get('/usuarios');
      const data = res.data.data || res.data || [];
      set({ usuarios: data.map((u: { id: string; nome: string }) => ({ value: u.id, label: u.nome })) });
    } catch { /* silent */ }
  },

  reset: () => set(initialState),
}));
