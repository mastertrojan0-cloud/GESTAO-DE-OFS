export type Perfil = 'observador' | 'supervisor' | 'gestor' | 'admin';

export const PERFIL_RANK: Record<Perfil, number> = {
  observador: 1,
  supervisor: 2,
  gestor: 3,
  admin: 4,
};

export type TipoOFS = 'Positivo/Seguro' | 'Negativo/Inseguro';

/** @deprecated Use TipoOFS */
export type TipoOFC = TipoOFS;

export type Turno = 'ADM' | '1' | '2' | '3';

export type StatusSemana = 'OK' | 'ATENCAO' | 'ALERTA';

export type TipoRelatorio = 'semanal' | 'mensal' | 'empresa' | 'individual';

export interface Usuario {
  id: string;
  username: string;
  nome: string;
  email: string;
  perfil: Perfil;
  empresa_id: string;
  empresa_nome: string;
  ativo: boolean;
  bloqueado_ate?: string;
  tentativas_restantes?: number;
  created_at: string;
}

export interface LoginResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  user: Usuario;
}

export interface LoginError {
  detail: string;
  error_type?: 'invalid_credentials' | 'user_inactive' | 'user_blocked';
  bloqueado_ate?: string;
  tentativas_restantes?: number;
}

export interface Empresa {
  id: string;
  nome: string;
  cnpj?: string;
  ativo: boolean;
  contratos?: Contrato[];
  created_at: string;
}

export interface Contrato {
  id: string;
  empresa_id: string;
  nome: string;
  numero?: string;
  ativo: boolean;
  created_at: string;
}

export interface Meta {
  id: string;
  empresa_id: string;
  contrato_id?: string;
  pessoas_ativas: number;
  meta_diaria: number;
  meta_semanal: number;
  vigencia_inicio: string;
  vigencia_fim?: string;
  ativo: boolean;
  historico?: MetaHistorico[];
}

export interface MetaHistorico {
  id: string;
  meta_id: string;
  campo: string;
  valor_anterior: string;
  valor_novo: string;
  alterado_por: string;
  alterado_em: string;
}

export interface OFS {
  id: string;
  data: string;
  hora: string;
  usuario_gerador_id: string;
  usuario_gerador_nome: string;
  nome_observado: string;
  atividade: string;
  local: string;
  empresa_id: string;
  empresa_nome: string;
  contrato_id?: string;
  contrato_nome?: string;
  turno: Turno;
  tipo: TipoOFS;
  tipo_observacao?: TipoOFS;
  comportamento: string;
  observacao: string;
  status: 'ativo' | 'cancelado';
  created_at: string;
  updated_at: string;
  editado_por?: string;
  editado_em?: string;
  cancelado_por?: string;
  cancelado_em?: string;
  historico?: EdicaoHistorico[];
}

export interface EdicaoHistorico {
  id: string;
  ofs_id: string;
  /** @deprecated Use ofs_id */
  ofc_id?: string;
  campo: string;
  valor_anterior: string;
  valor_novo: string;
  editado_por: string;
  editado_em: string;
}

export interface OFSFiltros {
  data_inicio?: string;
  data_fim?: string;
  tipo?: TipoOFS;
  status?: string;
  empresa_id?: string;
  contrato_id?: string;
  turno?: Turno;
  comportamento?: string;
  usuario_gerador_id?: string;
  nome_observado?: string;
  page?: number;
  limit?: number;
  order_by?: string;
  order_dir?: 'asc' | 'desc';
}

/** @deprecated Use OFSFiltros */
export type OFCFiltros = OFSFiltros;

export interface MetricasSemana {
  semana_inicio: string;
  semana_fim: string;
  aderencia_percentual: number;
  status: StatusSemana;
  percentual_seguro: number;
  percentual_negativo: number;
  /** @deprecated Use percentual_negativo */
  percentual_desvio?: number;
  pessoas_ativas: number;
  ofs_programadas: number;
  ofs_realizadas: number;
  ofs_positivas: number;
  ofs_negativas: number;
  /** @deprecated Use ofs_programadas */
  ofc_programadas?: number;
  /** @deprecated Use ofs_realizadas */
  ofc_realizadas?: number;
  /** @deprecated Use ofs_positivas */
  ofc_positivas?: number;
  /** @deprecated Use ofs_negativas */
  ofc_negativas?: number;
  usuarios_ativos: number;
  media_ofs_usuario: number;
  /** @deprecated Use media_ofs_usuario */
  media_ofc_usuario?: number;
  meta_cadastrada: boolean;
  meta_aderencia_minima?: number;
  meta_seguro_minima?: number;
  variacao_seguro?: number;
}

export interface EmpresaConsolidada {
  id: string;
  empresa_nome: string;
  contrato_nome?: string;
  ofs_programadas: number;
  ofs_realizadas: number;
  aderencia_percentual: number;
  percentual_seguro: number;
  ofs_positivas: number;
  ofs_negativas: number;
  /** @deprecated */
  ofc_programadas?: number;
  /** @deprecated */
  ofc_realizadas?: number;
  /** @deprecated */
  ofc_positivas?: number;
  /** @deprecated */
  ofc_negativas?: number;
  usuarios_ativos: number;
  media_ofs_usuario: number;
  status: StatusSemana;
}

export interface GraficoBarras {
  labels: string[];
  datasets: { label: string; data: number[]; color?: string }[];
}

export interface GraficoPizza {
  labels: string[];
  data: number[];
}

export interface AuditoriaLog {
  id: string;
  usuario_id: string;
  usuario_nome: string;
  acao: string;
  entidade: string;
  entidade_id: string;
  detalhes: string;
  ip: string;
  created_at: string;
}

export interface Backup {
  id: string;
  arquivo: string;
  tamanho: string;
  tipo: 'automatico' | 'manual';
  status: 'sucesso' | 'falha';
  created_at: string;
}

export interface Relatorio {
  id: string;
  tipo: TipoRelatorio;
  parametros: string;
  arquivo?: string;
  status: 'pendente' | 'gerado' | 'erro';
  gerado_por: string;
  created_at: string;
}

export interface ApiResponse<T> {
  data: T;
  total?: number;
  page?: number;
  limit?: number;
  message?: string;
}

export interface ApiError {
  message: string;
  detail?: string;
  status: number;
}
