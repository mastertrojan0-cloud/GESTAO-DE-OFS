import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '@/lib/api';
import { Card, Button, Spinner } from '@/components/ui';
import { FilePlus, List, BarChart3, Activity, TrendingUp, TrendingDown } from 'lucide-react';

interface Resumo {
  ofcs_hoje: number;
  ofcs_semana: number;
  taxa_positivo: number;
  taxa_negativo: number;
  ofss_hoje?: number;
  ofss_semana?: number;
}

export default function DashboardPage() {
  const [resumo, setResumo] = useState<Resumo | null>(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    api.get('/dashboard/resumo').then((r) => setResumo(r.data)).finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Spinner size="lg" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-brand-black">Dashboard</h1>
        <p className="text-sm text-gray-500 mt-1">Resumo do sistema de feedback comportamental</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card className="border-l-4 border-l-brand-red">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-red-50">
              <Activity className="h-5 w-5 text-brand-red" />
            </div>
            <div>
              <p className="text-2xl font-bold text-brand-black">{resumo?.ofss_hoje ?? resumo?.ofcs_hoje ?? 0}</p>
              <p className="text-xs text-gray-500">Minhas OFSs hoje</p>
            </div>
          </div>
        </Card>

        <Card className="border-l-4 border-l-blue-500">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-blue-50">
              <List className="h-5 w-5 text-blue-500" />
            </div>
            <div>
              <p className="text-2xl font-bold text-brand-black">{resumo?.ofss_semana ?? resumo?.ofcs_semana ?? 0}</p>
              <p className="text-xs text-gray-500">OFSs esta semana</p>
            </div>
          </div>
        </Card>

        <Card className="border-l-4 border-l-success">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-green-50">
              <TrendingUp className="h-5 w-5 text-success" />
            </div>
            <div>
              <p className="text-2xl font-bold text-green-600">{resumo?.taxa_positivo ?? 0}%</p>
              <p className="text-xs text-gray-500">Taxa OFS Positiva</p>
            </div>
          </div>
        </Card>

        <Card className="border-l-4 border-l-danger">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-red-50">
              <TrendingDown className="h-5 w-5 text-danger" />
            </div>
            <div>
              <p className="text-2xl font-bold text-danger">{resumo?.taxa_negativo ?? 0}%</p>
              <p className="text-xs text-gray-500">Taxa OFS Negativa</p>
            </div>
          </div>
        </Card>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Button
          variant="primary"
          size="lg"
          className="w-full"
          onClick={() => navigate('/ofs/novo')}
        >
          <FilePlus className="h-5 w-5" />
          Nova OFS
        </Button>
        <Button
          variant="outline"
          size="lg"
          className="w-full"
          onClick={() => navigate('/consulta')}
        >
          <List className="h-5 w-5" />
          Consultar
        </Button>
        <Button
          variant="secondary"
          size="lg"
          className="w-full"
          onClick={() => navigate('/metricas')}
        >
          <BarChart3 className="h-5 w-5" />
          Métricas
        </Button>
      </div>
    </div>
  );
}
