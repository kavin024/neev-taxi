import { useState } from 'react';
import { money } from '../lib/format';

interface SeriesPoint {
  date: string;
  rides: number;
  gmv_paise: number;
}

const W = 760;
const H = 210;
const PAD = { left: 46, right: 16, top: 16, bottom: 28 };

export function RideChart({
  series,
  metric,
}: {
  series: SeriesPoint[];
  metric: 'rides' | 'gmv';
}) {
  const [active, setActive] = useState<number | null>(null);
  if (series.length === 0) {
    return <div className="loading-block">No ride activity in this window.</div>;
  }

  const values = series.map((point) => (metric === 'rides' ? point.rides : point.gmv_paise / 100));
  const max = Math.max(...values, metric === 'rides' ? 4 : 500);
  const roundedMax = niceMax(max);
  const plotW = W - PAD.left - PAD.right;
  const plotH = H - PAD.top - PAD.bottom;
  const step = series.length > 1 ? plotW / (series.length - 1) : 0;
  const xFor = (index: number) => PAD.left + index * step;
  const yFor = (value: number) => PAD.top + plotH - (value / roundedMax) * plotH;

  const line = series
    .map((point, index) => {
      const value = metric === 'rides' ? point.rides : point.gmv_paise / 100;
      return `${index === 0 ? 'M' : 'L'} ${xFor(index).toFixed(2)} ${yFor(value).toFixed(2)}`;
    })
    .join(' ');
  const area = `${line} L ${xFor(series.length - 1).toFixed(2)} ${PAD.top + plotH} L ${xFor(0).toFixed(2)} ${PAD.top + plotH} Z`;
  const gridLines = [0, 0.25, 0.5, 0.75, 1];

  const formatTick = (value: number) =>
    metric === 'rides' ? String(Math.round(value)) : `₹${Math.round(value).toLocaleString('en-IN')}`;

  const labelEvery = series.length > 20 ? 5 : series.length > 10 ? 3 : 2;
  const point = active !== null ? series[active] : null;
  const pointValue = point ? (metric === 'rides' ? point.rides : point.gmv_paise / 100) : 0;

  return (
    <div className="chart-wrap">
      <svg
        className="chart-svg"
        viewBox={`0 0 ${W} ${H}`}
        role="img"
        aria-label={`Ride activity for the last ${series.length} days`}
        onMouseLeave={() => setActive(null)}
      >
        <defs>
          <linearGradient id="chartFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#0E4F45" stopOpacity="0.22" />
            <stop offset="100%" stopColor="#0E4F45" stopOpacity="0.01" />
          </linearGradient>
        </defs>

        {gridLines.map((fraction) => {
          const y = PAD.top + plotH - fraction * plotH;
          return (
            <g key={fraction}>
              <line className="chart-grid" x1={PAD.left} x2={W - PAD.right} y1={y} y2={y} />
              <text className="chart-axis" x={PAD.left - 8} y={y + 3} textAnchor="end">
                {formatTick(roundedMax * fraction)}
              </text>
            </g>
          );
        })}

        <path d={area} fill="url(#chartFill)" />
        <path d={line} fill="none" stroke="#0E4F45" strokeWidth="2.4" strokeLinejoin="round" strokeLinecap="round" />

        {series.map((item, index) => (
          <g key={item.date}>
            {index % labelEvery === 0 && (
              <text className="chart-axis" x={xFor(index)} y={H - 8} textAnchor="middle">
                {new Date(item.date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })}
              </text>
            )}
            <circle
              cx={xFor(index)}
              cy={yFor(metric === 'rides' ? item.rides : item.gmv_paise / 100)}
              r={active === index ? 5 : 3}
              fill={active === index ? '#F2B544' : '#0E4F45'}
              stroke="#fff"
              strokeWidth="2"
            />
            <rect
              x={xFor(index) - Math.max(step / 2, 8)}
              y={PAD.top}
              width={Math.max(step, 16)}
              height={plotH}
              fill="transparent"
              onMouseEnter={() => setActive(index)}
            />
          </g>
        ))}
      </svg>

      {point && active !== null && (
        <div
          className="chart-tooltip"
          style={{
            left: `${(xFor(active) / W) * 100}%`,
            top: `${(yFor(pointValue) / H) * 100}%`,
          }}
        >
          {new Date(point.date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })} ·{' '}
          {metric === 'rides' ? `${point.rides} rides` : money(point.gmv_paise)}
        </div>
      )}
    </div>
  );
}

function niceMax(value: number): number {
  if (value <= 4) return 4;
  const magnitude = Math.pow(10, Math.floor(Math.log10(value)));
  const normalized = value / magnitude;
  const stepped = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10;
  return stepped * magnitude;
}
