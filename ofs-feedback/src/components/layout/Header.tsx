import { useAuthStore } from '@/stores/authStore';
import { LogOut, ChevronDown, User, KeyRound } from 'lucide-react';
import { useState } from 'react';
import { Flag } from '@/components/ui';
import { AlterarSenhaModal } from './AlterarSenhaModal';

export function Header({ onMenuToggle }: { onMenuToggle?: () => void }) {
  const { user, logout } = useAuthStore();
  const [menuOpen, setMenuOpen] = useState(false);
  const [alterarSenhaOpen, setAlterarSenhaOpen] = useState(false);

  return (
    <>
      <header className="sticky top-0 z-30 flex h-16 items-center justify-between bg-brand-red px-4 lg:px-6 shadow-md">
        <div className="flex items-center gap-3">
          <button
            onClick={onMenuToggle}
            className="rounded-lg p-1.5 text-white hover:bg-white/10 lg:hidden"
          >
            <svg className="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>

          <div className="flex items-center gap-2">
            <Flag country="VE" className="h-5 w-7 rounded-sm shadow-sm ring-1 ring-white/30" />
            <Flag country="BR" className="h-5 w-7 rounded-sm shadow-sm ring-1 ring-white/30" />
            <span className="text-white font-bold text-sm sm:text-base ml-1 tracking-wide">
              GESTÃO DE OFS
            </span>
          </div>
        </div>

        <div className="relative">
          <button
            onClick={() => setMenuOpen(!menuOpen)}
            className="flex items-center gap-2 rounded-lg px-3 py-1.5 text-white hover:bg-white/10 transition-colors"
          >
            <User className="h-4 w-4" />
            <span className="text-sm hidden sm:inline">{user?.nome || user?.username}</span>
            <ChevronDown className="h-3 w-3" />
          </button>

          {menuOpen && (
            <>
              <div className="fixed inset-0 z-10" onClick={() => setMenuOpen(false)} />
              <div className="absolute right-0 top-full mt-1 z-20 w-48 rounded-lg bg-surface shadow-lg border border-gray-200 py-1">
                <div className="px-4 py-2 border-b border-gray-100">
                  <p className="text-sm font-medium text-brand-black">{user?.nome}</p>
                  <p className="text-xs text-gray-500 capitalize">{user?.perfil}</p>
                </div>

                <button
                  onClick={() => {
                    setMenuOpen(false);
                    setAlterarSenhaOpen(true);
                  }}
                  className="flex w-full items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                >
                  <KeyRound className="h-4 w-4" />
                  Alterar Senha
                </button>

                <button
                  onClick={() => { setMenuOpen(false); logout(); }}
                  className="flex w-full items-center gap-2 px-4 py-2 text-sm text-danger hover:bg-red-50"
                >
                  <LogOut className="h-4 w-4" />
                  Sair
                </button>
              </div>
            </>
          )}
        </div>
      </header>

      <AlterarSenhaModal
        open={alterarSenhaOpen}
        onClose={() => setAlterarSenhaOpen(false)}
      />
    </>
  );
}
