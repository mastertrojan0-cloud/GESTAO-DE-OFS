import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell } from 'recharts';
import { Card } from '@/components/ui';

interface BarChartCardProps {
  title: string;
  data: { name: string; value: number; color?: string }[];
  height?: number;
}

export function BarChartCard({ title, data, height = 300 }: BarChartCardProps) {
  const defaultColors = ['#CC0000', '#1A1A1A', '#22C55E', '#EAB308', '#3B82F6'];

  return (
    <Card title={title}>
      <ResponsiveContainer width="100%" height={height}>
        <BarChart data={data} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="name" tick={{ fontSize: 12 }} stroke="#9CA3AF" />
          <YAxis tick={{ fontSize: 12 }} stroke="#9CA3AF" />
          <Tooltip
            contentStyle={{ borderRadius: '8px', border: '1px solid #e5e7eb', fontSize: '13px' }}
          />
          <Bar dataKey="value" radius={[4, 4, 0, 0]}>
            {data.map((entry, index) => (
              <Cell key={index} fill={entry.color || defaultColors[index % defaultColors.length]} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </Card>
  );
}
