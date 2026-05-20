import { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Toaster } from 'sonner';
import { AppShell } from '@/components/layout/AppShell';
import { ProtectedRoute } from '@/components/layout/ProtectedRoute';
import { SessionExpiredModal } from '@/components/layout/SessionExpiredModal';
import { Spinner } from '@/components/ui';

const LoginPage = lazy(() => import('@/pages/LoginPage'));
const DashboardPage = lazy(() => import('@/pages/DashboardPage'));
const NovoOFSPage = lazy(() => import('@/pages/NovoOFSPage'));
const ListaOFSPage = lazy(() => import('@/pages/ListaOFSPage'));
const DetalheOFSPage = lazy(() => import('@/pages/DetalheOFSPage'));
const EditarOFSPage = lazy(() => import('@/pages/EditarOFSPage'));
const ConsultaAvancadaPage = lazy(() => import('@/pages/ConsultaAvancadaPage'));
const MetricasPage = lazy(() => import('@/pages/MetricasPage'));
const RelatoriosPage = lazy(() => import('@/pages/RelatoriosPage'));

const UsuariosPage = lazy(() => import('@/pages/admin/UsuariosPage'));
const NovoUsuarioPage = lazy(() => import('@/pages/admin/NovoUsuarioPage'));
const EmpresasPage = lazy(() => import('@/pages/admin/EmpresasPage'));
const ContratosPage = lazy(() => import('@/pages/admin/ContratosPage'));
const MetasPage = lazy(() => import('@/pages/admin/MetasPage'));
const AuditoriaPage = lazy(() => import('@/pages/admin/AuditoriaPage'));
const BackupPage = lazy(() => import('@/pages/admin/BackupPage'));

function PageLoader() {
  return (
    <div className="flex items-center justify-center h-64">
      <Spinner size="lg" />
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <Toaster
        position="top-right"
        richColors
        closeButton
        toastOptions={{
          style: { fontSize: '14px' },
        }}
      />

      <SessionExpiredModal />

      <Suspense fallback={<PageLoader />}>
        <Routes>
          <Route path="/login" element={<LoginPage />} />

          <Route
            element={
              <ProtectedRoute>
                <AppShell />
              </ProtectedRoute>
            }
          >
            <Route index element={<DashboardPage />} />
            <Route path="/ofs/novo" element={<NovoOFSPage />} />
            <Route path="/ofs" element={<ListaOFSPage />} />
            <Route path="/ofs/:id" element={<DetalheOFSPage />} />
            <Route path="/ofs/:id/editar" element={<EditarOFSPage />} />
            <Route path="/consulta" element={<ConsultaAvancadaPage />} />
            <Route path="/metricas" element={<MetricasPage />} />
            <Route path="/relatorios" element={<RelatoriosPage />} />

            <Route element={<ProtectedRoute perfis={['admin']} />}>
              <Route path="/admin/usuarios" element={<UsuariosPage />} />
              <Route path="/admin/usuarios/novo" element={<NovoUsuarioPage />} />
              <Route path="/admin/empresas" element={<EmpresasPage />} />
              <Route path="/admin/contratos" element={<ContratosPage />} />
              <Route path="/admin/metas" element={<MetasPage />} />
              <Route path="/admin/auditoria" element={<AuditoriaPage />} />
              <Route path="/admin/backup" element={<BackupPage />} />
            </Route>
          </Route>

          <Route path="*" element={
            <div className="flex items-center justify-center h-screen">
              <div className="text-center">
                <h1 className="text-6xl font-bold text-brand-red">404</h1>
                <p className="text-gray-500 mt-2">Pagina nao encontrada</p>
              </div>
            </div>
          } />
        </Routes>
      </Suspense>
    </BrowserRouter>
  );
}
