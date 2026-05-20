import { AlertTriangle } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

export function MetaBanner() {
  const navigate = useNavigate();

  return (
    <div className="flex items-start gap-3 p-4 rounded-lg bg-yellow-50 border border-yellow-200">
      <AlertTriangle className="h-5 w-5 text-yellow-600 flex-shrink-0 mt-0.5" />
      <div className="flex-1">
        <p className="text-sm font-semibold text-yellow-800">
          Meta não cadastrada
        </p>
        <p className="text-sm text-yellow-700 mt-0.5">
          Esta empresa não possui meta cadastrada para o período atual.
          Os indicadores de aderência e status não serão calculados.
        </p>
        <button
          onClick={() => navigate('/admin/metas')}
          className="mt-2 text-sm font-medium text-yellow-800 underline hover:text-yellow-900"
        >
          Ir para Admin &gt; Metas
        </button>
      </div>
    </div>
  );
}
