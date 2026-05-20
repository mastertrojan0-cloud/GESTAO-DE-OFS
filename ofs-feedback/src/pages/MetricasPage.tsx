import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { format, subWeeks, addWeeks, startOfWeek } from 'date-fns';
import { AlertTriangle, Users, ClipboardList, CheckCircle2, ThumbsUp, ThumbsDown, UserCheck, BarChart3 } from 'lucide-react';

import { useMetricasStore } from '@/stores/metricasStore';
import { useDebounce } from '@/hooks';
import { Button, EmptyState } from '@/components/ui';
import { BarChartCard, PieChartCard, LineChartCard } from '@/components/charts';
import {
  FilterBar,
  StatCard,
  StatusBadge,
  ConsolidatedTable,
  MetaBanner,
  MetricasSkeleton,
} from '@/components/metricas';

export default function MetricasPage() {
  const navigate = useNavigate();
  const store = useMetricasStore();

  const [semanaInicio, setSemanaInicio] = useState(startOfWeek(new Date(), { weekStartsOn: 1 }));
  const [empresaId, setEmpresaId] = useState('');
  const [contratoId, setContratoId] = useState('');
  const [turno, setTurno] = useState('');
  const [usuarioId, setUsuarioId] = useState('');

  const debouncedEmpresa = useDebounce(empresaId, 300);
  const debouncedContrato = useDebounce(contratoId, 300);
  const debouncedTurno = useDebounce(turno, 300);
  const debouncedUsuario = useDebounce(usuarioId, 300);

  const buildParams = useCallback((): Record<string, string> => {
    const params: Record<string, string> = {
      semana_inicio: format(semanaInicio, 'yyyy-MM-dd'),
      semana_fim: format(addWeeks(semanaInicio, 1), 'yyyy-MM-dd'),
    };
    if (empresaId) params.empresa_id = empresaId;
    if (contratoId) params.contrato_id = contratoId;
    if (turno) params.turno = turno;
    if (usuarioId) params.usuario_id = usuarioId;
    return params;
  }, [semanaInicio, empresaId, contratoId, turno, usuarioId]);

  useEffect(() => {
    const params = buildParams();
    store.loadMetricas(params);
    store.loadConsolidado(params);
  }, [semanaInicio, debouncedEmpresa, debouncedContrato, debouncedTurno, debouncedUsuario]);

  useEffect(() => {
    store.loadEmpresas();
    store.loadUsuarios();
  }, []);

  useEffect(() => {
    store.loadContratos(empresaId || undefined);
  }, [empresaId]);

  const handleCardClick = (type: string) => {
    const params = new URLSearchParams(buildParams());
    params.set('filtro', type);
    navigate(`/ofs?${params.toString()}`);
  };

  const handleRetry = () => {
    const params = buildParams();
    store.loadMetricas(params);
    store.loadConsolidado(params);
  };

  const getAderenciaVariant = (val: number) =>
    val >= 90 ? 'success' : val >= 70 ? 'warning' : 'danger';

  const getSeguroVariant = (val: number) =>
    val >= 70 ? 'success' : val >= 50 ? 'warning' : 'danger';

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-brand-black">Métricas da Semana</h1>
          <p className="text-sm text-gray-500 mt-1">Análise de indicadores e desempenho</p>
        </div>
      </div>

      <FilterBar
        semanaInicio={semanaInicio}
        onSemanaChange={setSemanaInicio}
        empresaId={empresaId}
        onEmpresaChange={(id) => { setEmpresaId(id); setContratoId(''); }}
        empresas={store.empresas}
        contratoId={contratoId}
        onContratoChange={setContratoId}
        contratos={store.contratos}
        turno={turno}
        onTurnoChange={setTurno}
        turnos={[]}
        usuarioId={usuarioId}
        onUsuarioChange={setUsuarioId}
        usuarios={store.usuarios}
      />

      {store.error && (
        <div className="flex flex-col items-center justify-center py-16 text-center bg-surface rounded-xl border border-danger/20">
          <AlertTriangle className="h-10 w-10 text-danger mb-3" />
          <h3 className="text-lg font-semibold text-brand-black">Erro ao carregar dados</h3>
          <p className="text-sm text-gray-500 mt-1 max-w-md">{store.error}</p>
          <Button variant="outline" className="mt-4" onClick={handleRetry}>
            Tentar novamente
          </Button>
        </div>
      )}

      {store.loading && !store.error && <MetricasSkeleton />}

      {!store.loading && !store.error && store.metaNaoCadastrada && <MetaBanner />}

      {!store.loading && !store.error && !store.metaNaoCadastrada && !store.metricas && !store.consolidadoLoading && store.consolidado.length === 0 && (
        <EmptyState
          title="Nenhum dado na semana"
          description="Esta semana não possui OFSs registradas para os filtros atuais. Tente alterar a semana ou os filtros."
          action={
            <Button variant="primary" onClick={() => navigate('/ofs/novo')}>
              Registrar OFS
            </Button>
          }
        />
      )}

      {!store.loading && !store.error && store.metricas && (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <StatCard
              label="Aderência"
              value={`${store.metricas.aderencia_percentual}%`}
              subtitle={store.metricas.meta_aderencia_minima ? `meta: ${store.metricas.meta_aderencia_minima}%` : undefined}
              variant={getAderenciaVariant(store.metricas.aderencia_percentual)}
              accentBar
              progress={store.metricas.aderencia_percentual}
              onClick={() => handleCardClick('aderencia')}
            />
            <StatCard
              label="% Seguro"
              value={`${store.metricas.percentual_seguro}%`}
              subtitle={store.metricas.variacao_seguro !== undefined ? `${store.metricas.variacao_seguro >= 0 ? '+' : ''}${store.metricas.variacao_seguro}% vs. anterior` : undefined}
              variant={getSeguroVariant(store.metricas.percentual_seguro)}
              accentBar
              trend={
                store.metricas.variacao_seguro !== undefined
                  ? { direction: store.metricas.variacao_seguro >= 0 ? 'up' : 'down', value: `${store.metricas.variacao_seguro >= 0 ? '+' : ''}${store.metricas.variacao_seguro}%` }
                  : undefined
              }
              onClick={() => handleCardClick('seguro')}
            />
            <StatCard
              label="Status"
              value={<StatusBadge status={store.metricas.status} />}
              subtitle={store.metricas.status === 'OK' ? 'Todas as metas dentro do esperado' : store.metricas.status === 'ATENCAO' ? 'Algumas metas abaixo do ideal' : 'Metas críticas abaixo do mínimo'}
              variant={store.metricas.status === 'OK' ? 'success' : store.metricas.status === 'ATENCAO' ? 'warning' : 'danger'}
              accentBar
            />
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-7 gap-4">
            <StatCard
              label="Pessoas Ativas"
              value={store.metricas.pessoas_ativas}
              icon={<Users className="h-4 w-4" />}
              onClick={() => handleCardClick('pessoas_ativas')}
            />
            <StatCard
              label="Programadas"
              value={store.metricas.ofc_programadas}
              icon={<ClipboardList className="h-4 w-4" />}
              onClick={() => handleCardClick('programadas')}
            />
            <StatCard
              label="Realizadas"
              value={store.metricas.ofc_realizadas}
              icon={<CheckCircle2 className="h-4 w-4" />}
              onClick={() => handleCardClick('realizadas')}
            />
            <StatCard
              label="Positivas"
              value={store.metricas.ofc_positivas}
              icon={<ThumbsUp className="h-4 w-4" />}
              variant="success"
            />
            <StatCard
              label="Negativas"
              value={store.metricas.ofc_negativas}
              icon={<ThumbsDown className="h-4 w-4" />}
              variant="danger"
            />
            <StatCard
              label="Usuários Ativos"
              value={store.metricas.usuarios_ativos}
              icon={<UserCheck className="h-4 w-4" />}
            />
            <StatCard
              label="Média OFS/Usuário"
              value={store.metricas.media_ofc_usuario.toFixed(1)}
              icon={<BarChart3 className="h-4 w-4" />}
            />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <BarChartCard
              title="Programado x Realizado"
              data={store.graficos.programadoRealizado}
            />
            <PieChartCard
              title="OFS Positiva (Seguro) x OFS Negativa (Inseguro)"
              data={store.graficos.positivoNegativo}
            />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <BarChartCard
              title="OFS por Empresa"
              data={store.graficos.porEmpresa}
              height={350}
            />
            <LineChartCard
              title="Evolução Semanal"
              data={store.graficos.evolucaoSemanal}
              lines={[
                { dataKey: 'programado', color: '#3B82F6', name: 'Programado' },
                { dataKey: 'realizado', color: '#CC0000', name: 'Realizado' },
              ]}
            />
          </div>

          <ConsolidatedTable
            data={store.consolidado}
            loading={store.consolidadoLoading}
            error={null}
            exportParams={buildParams()}
            onRowClick={(item) => {
              if (item.id === '_total') return;
              const params = new URLSearchParams(buildParams());
              params.set('empresa_id', item.id);
              navigate(`/ofs?${params.toString()}`);
            }}
          />
        </>
      )}

      {!store.loading && !store.error && !store.metaNaoCadastrada && !store.metricas && store.consolidado.length > 0 && (
        <>
          <ConsolidatedTable
            data={store.consolidado}
            loading={store.consolidadoLoading}
            error={null}
            exportParams={buildParams()}
          />
        </>
      )}
    </div>
  );
}
