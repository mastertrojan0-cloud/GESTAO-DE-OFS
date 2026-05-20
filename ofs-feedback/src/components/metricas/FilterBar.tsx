import { Button, Select } from '@/components/ui';
import { ChevronLeft, ChevronRight, Calendar } from 'lucide-react';
import { format, subWeeks, addWeeks, endOfWeek } from 'date-fns';

interface FilterBarProps {
  semanaInicio: Date;
  onSemanaChange: (date: Date) => void;
  empresaId: string;
  onEmpresaChange: (id: string) => void;
  empresas: { value: string; label: string }[];
  contratoId: string;
  onContratoChange: (id: string) => void;
  contratos: { value: string; label: string }[];
  turno: string;
  onTurnoChange: (turno: string) => void;
  turnos: { value: string; label: string }[];
  usuarioId: string;
  onUsuarioChange: (id: string) => void;
  usuarios: { value: string; label: string }[];
}

const TURNOS = [
  { value: '', label: 'Todos os Turnos' },
  { value: 'ADM', label: 'ADM' },
  { value: '1', label: '1º Turno' },
  { value: '2', label: '2º Turno' },
  { value: '3', label: '3º Turno' },
];

export function FilterBar({
  semanaInicio,
  onSemanaChange,
  empresaId,
  onEmpresaChange,
  empresas,
  contratoId,
  onContratoChange,
  contratos,
  turno,
  onTurnoChange,
  usuarioId,
  onUsuarioChange,
  usuarios,
}: FilterBarProps) {
  const inicio = format(semanaInicio, "dd/MM");
  const fim = format(endOfWeek(semanaInicio, { weekStartsOn: 1 }), "dd/MM/yyyy");
  const semanaLabel = `${inicio} - ${fim}`;

  return (
    <div className="flex flex-wrap items-center gap-3">
      <div className="flex items-center gap-1 bg-surface rounded-lg border border-gray-200 p-1">
        <Button
          variant="ghost"
          size="sm"
          onClick={() => onSemanaChange(subWeeks(semanaInicio, 1))}
          className="h-8 w-8 p-0"
        >
          <ChevronLeft className="h-4 w-4" />
        </Button>
        <span className="flex items-center gap-1.5 px-2 text-sm font-medium text-brand-black min-w-[160px] justify-center">
          <Calendar className="h-3.5 w-3.5 text-gray-400" />
          {semanaLabel}
        </span>
        <Button
          variant="ghost"
          size="sm"
          onClick={() => onSemanaChange(addWeeks(semanaInicio, 1))}
          className="h-8 w-8 p-0"
        >
          <ChevronRight className="h-4 w-4" />
        </Button>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <Select
          value={empresaId}
          onChange={(e) => onEmpresaChange(e.target.value)}
          options={[{ value: '', label: 'Todas as Empresas' }, ...empresas]}
          className="w-44"
        />
        <Select
          value={contratoId}
          onChange={(e) => onContratoChange(e.target.value)}
          options={[{ value: '', label: 'Todos os Contratos' }, ...contratos]}
          className="w-44"
        />
        <Select
          value={turno}
          onChange={(e) => onTurnoChange(e.target.value)}
          options={TURNOS}
          className="w-40"
        />
        <Select
          value={usuarioId}
          onChange={(e) => onUsuarioChange(e.target.value)}
          options={[{ value: '', label: 'Todos os Usuários' }, ...usuarios]}
          className="w-44"
        />
      </div>
    </div>
  );
}
