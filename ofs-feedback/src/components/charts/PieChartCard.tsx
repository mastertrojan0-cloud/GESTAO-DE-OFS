import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer, Legend } from 'recharts';
import { Card } from '@/components/ui';

interface PieChartCardProps {
  title: string;
  data: { name: string; value: number; color?: string }[];
  height?: number;
}

const COLORS = ['#22C55E', '#EF4444', '#EAB308', '#3B82F6', '#8B5CF6', '#F97316'];

export function PieChartCard({ title, data, height = 300 }: PieChartCardProps) {
  return (
    <Card title={title}>
      <ResponsiveContainer width="100%" height={height}>
        <PieChart>
          <Pie
            data={data}
            cx="50%"
            cy="50%"
            innerRadius={60}
            outerRadius={100}
            paddingAngle={3}
            dataKey="value"
          >
            {data.map((entry, index) => (
              <Cell key={index} fill={entry.color || COLORS[index % COLORS.length]} />
            ))}
          </Pie>
          <Tooltip
            contentStyle={{ borderRadius: '8px', border: '1px solid #e5e7eb', fontSize: '13px' }}
          />
          <Legend />
        </PieChart>
      </ResponsiveContainer>
    </Card>
  );
}
