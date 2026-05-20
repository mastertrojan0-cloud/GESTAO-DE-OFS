import { NavLink } from 'react-router-dom';
import { useAuthStore } from '@/stores/authStore';
import {
  LayoutDashboard,
  FilePlus,
  List,
  Search,
  BarChart3,
  FileText,
  Users,
  UserPlus,
  Building2,
  FileCheck,
  Target,
  ShieldCheck,
  Database,
  ChevronLeft,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { Flag } from '@/components/ui';
import type { Perfil } from '@/types';

interface NavItem {
  label: string;
  icon: React.ElementType;
  to: string;
  perfis?: Perfil[];
}

const navItems: NavItem[] = [
  { label: 'Dashboard', icon: LayoutDashboard, to: '/' },
  { label: 'Nova OFS', icon: FilePlus, to: '/ofs/novo' },
  { label: 'Lista de OFSs', icon: List, to: '/ofs' },
  { label: 'Consulta Avançada', icon: Search, to: '/consulta' },
  { label: 'Métricas', icon: BarChart3, to: '/metricas', perfis: ['supervisor', 'gestor', 'admin'] },
  { label: 'Relatórios', icon: FileText, to: '/relatorios', perfis: ['supervisor', 'gestor', 'admin'] },
];

const adminItems: NavItem[] = [
  { label: 'Usuários', icon: Users, to: '/admin/usuarios', perfis: ['admin'] },
  { label: 'Cadastrar Usuário', icon: UserPlus, to: '/admin/usuarios/novo', perfis: ['admin'] },
  { label: 'Empresas', icon: Building2, to: '/admin/empresas', perfis: ['admin'] },
  { label: 'Contratos', icon: FileCheck, to: '/admin/contratos', perfis: ['admin'] },
  { label: 'Metas', icon: Target, to: '/admin/metas', perfis: ['admin'] },
  { label: 'Auditoria', icon: ShieldCheck, to: '/admin/auditoria', perfis: ['admin'] },
  { label: 'Backup', icon: Database, to: '/admin/backup', perfis: ['admin'] },
];

interface SidebarProps {
  open: boolean;
  onClose: () => void;
}

export function Sidebar({ open, onClose }: SidebarProps) {
  const { user } = useAuthStore();

  const canSee = (item: NavItem) => {
    if (!item.perfis) return true;
    return user ? item.perfis.includes(user.perfil) : false;
  };

  const visibleNav = navItems.filter(canSee);
  const visibleAdmin = adminItems.filter(canSee);

  return (
    <>
      {open && (
        <div className="fixed inset-0 z-40 bg-black/50 lg:hidden" onClick={onClose} />
      )}

      <aside
        className={cn(
          'fixed top-0 left-0 z-50 h-full w-64 bg-surface border-r border-gray-200 flex flex-col transition-transform',
          'lg:static lg:z-0 lg:translate-x-0',
          open ? 'translate-x-0' : '-translate-x-full'
        )}
      >
        <div className="flex items-center justify-between h-16 px-4 border-b border-gray-100 lg:hidden">
          <span className="text-brand-red font-bold flex items-center gap-1.5">
            <Flag country="VE" className="h-4 w-6 rounded-sm" />
            <Flag country="BR" className="h-4 w-6 rounded-sm" />
            GESTÃO DE OFS
          </span>
          <button onClick={onClose} className="p-1 rounded-lg hover:bg-gray-100">
            <ChevronLeft className="h-5 w-5" />
          </button>
        </div>

        <nav className="flex-1 overflow-y-auto py-4 px-3">
          <ul className="space-y-1">
            {visibleNav.map((item) => (
              <li key={item.to}>
                <NavLink
                  to={item.to}
                  end={item.to === '/'}
                  onClick={onClose}
                  className={({ isActive }) =>
                    cn(
                      'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
                      isActive
                        ? 'bg-brand-red text-white'
                        : 'text-gray-700 hover:bg-gray-100'
                    )
                  }
                >
                  <item.icon className="h-5 w-5 flex-shrink-0" />
                  {item.label}
                </NavLink>
              </li>
            ))}
          </ul>

          {visibleAdmin.length > 0 && (
            <>
              <div className="mt-6 mb-2 px-3">
                <span className="text-xs font-semibold text-gray-400 uppercase tracking-wider">
                  Administração
                </span>
              </div>
              <ul className="space-y-1">
                {visibleAdmin.map((item) => (
                  <li key={item.to}>
                    <NavLink
                      to={item.to}
                      onClick={onClose}
                      className={({ isActive }) =>
                        cn(
                          'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
                          isActive
                            ? 'bg-brand-red text-white'
                            : 'text-gray-700 hover:bg-gray-100'
                        )
                      }
                    >
                      <item.icon className="h-5 w-5 flex-shrink-0" />
                      {item.label}
                    </NavLink>
                  </li>
                ))}
              </ul>
            </>
          )}
        </nav>

        <div className="px-4 py-3 border-t border-gray-100">
          <p className="text-xs text-gray-400">v1.0.0</p>
          <p className="text-[11px] text-gray-400 mt-0.5">&copy; {new Date().getFullYear()} Antonio Martinez</p>
        </div>
      </aside>
    </>
  );
}
