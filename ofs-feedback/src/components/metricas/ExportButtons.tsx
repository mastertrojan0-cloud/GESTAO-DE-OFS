import { useState } from 'react';
import { Button } from '@/components/ui';
import { FileText, FileSpreadsheet, Loader2 } from 'lucide-react';
import { toast } from 'sonner';
import api from '@/lib/api';
import { cn } from '@/lib/utils';

interface ExportButtonsProps {
  params: Record<string, string>;
  className?: string;
}

type ExportFormat = 'pdf' | 'excel';

const FORMAT_LABELS: Record<ExportFormat, { label: string; icon: React.ReactNode }> = {
  pdf: { label: 'PDF', icon: <FileText className="h-4 w-4" /> },
  excel: { label: 'Excel', icon: <FileSpreadsheet className="h-4 w-4" /> },
};

export function ExportButtons({ params, className }: ExportButtonsProps) {
  const [exporting, setExporting] = useState<ExportFormat | null>(null);

  const handleExport = async (format: ExportFormat) => {
    setExporting(format);
    const toastId = toast.loading(`Gerando ${format.toUpperCase()}...`);

    try {
      const endpoint = format === 'pdf'
        ? '/metricas/exportar/pdf'
        : '/metricas/exportar/excel';

      const response = await api.get(endpoint, {
        params,
        responseType: 'blob',
      });

      const blob = new Blob([response.data], {
        type: format === 'pdf'
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      });

      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;

      const dataRef = params.semana_inicio || 'metricas';
      link.download = `metricas_${dataRef}.${format === 'pdf' ? 'pdf' : 'xlsx'}`;

      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);

      toast.success(`${format.toUpperCase()} exportado com sucesso!`, { id: toastId });
    } catch {
      toast.error(`Falha ao exportar ${format.toUpperCase()}. Tente novamente.`, { id: toastId });
    } finally {
      setExporting(null);
    }
  };

  return (
    <div className={cn('flex items-center gap-2', className)}>
      {(Object.keys(FORMAT_LABELS) as ExportFormat[]).map((format) => {
        const { label, icon } = FORMAT_LABELS[format];
        const isLoading = exporting === format;

        return (
          <Button
            key={format}
            variant="outline"
            size="sm"
            onClick={() => handleExport(format)}
            disabled={!!exporting}
          >
            {isLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : icon}
            {label}
          </Button>
        );
      })}
    </div>
  );
}
