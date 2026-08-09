import type { InspectionMetric, InspectionSample } from "./types";

const COLORS = {
  water: "#5f9cd8",
  nutrients: "#96a950",
  weeds: "#f2b72d",
  pests: "#73964c",
} as const;

type Point = { x: number; y: number };

function monotonePath(points: Point[]) {
  if (points.length < 2) return "";
  const slopes = points.slice(0, -1).map((point, index) => {
    const next = points[index + 1];
    return (next.y - point.y) / Math.max(0.001, next.x - point.x);
  });
  const tangents = points.map((_, index) => {
    if (index === 0) return slopes[0];
    if (index === points.length - 1) return slopes[slopes.length - 1];
    if (slopes[index - 1] * slopes[index] <= 0) return 0;
    return (slopes[index - 1] + slopes[index]) / 2;
  });
  slopes.forEach((slope, index) => {
    if (slope === 0) {
      tangents[index] = 0;
      tangents[index + 1] = 0;
      return;
    }
    const a = tangents[index] / slope;
    const b = tangents[index + 1] / slope;
    const magnitude = Math.hypot(a, b);
    if (magnitude > 3) {
      const scale = 3 / magnitude;
      tangents[index] = scale * a * slope;
      tangents[index + 1] = scale * b * slope;
    }
  });
  let path = `M ${points[0].x.toFixed(2)} ${points[0].y.toFixed(2)}`;
  for (let index = 0; index < points.length - 1; index += 1) {
    const point = points[index];
    const next = points[index + 1];
    const dx = next.x - point.x;
    path += ` C ${(point.x + dx / 3).toFixed(2)} ${(point.y + tangents[index] * dx / 3).toFixed(2)},`;
    path += ` ${(next.x - dx / 3).toFixed(2)} ${(next.y - tangents[index + 1] * dx / 3).toFixed(2)},`;
    path += ` ${next.x.toFixed(2)} ${next.y.toFixed(2)}`;
  }
  return path;
}

export function MetricChart({ metric, samples, start, now, end, lastCareAt }: {
  metric: InspectionMetric;
  samples: InspectionSample[];
  start: number;
  now: number;
  end: number;
  lastCareAt: number;
}) {
  const width = 180;
  const height = 40;
  const duration = Math.max(1, end - start);
  const points = (items: InspectionSample[]) => items.map((sample) => ({
    x: ((sample.at - start) / duration) * width,
    y: height - Math.max(0, Math.min(100, sample[metric.key])) / 100 * (height - 4) - 2,
  }));
  const current = samples.find((sample) => sample.phase === "now") ?? samples[0];
  const history = points(samples.filter((sample) => sample.phase !== "forecast"));
  const forecast = points(current ? [current, ...samples.filter((sample) => sample.phase === "forecast")] : []);
  const nowX = ((now - start) / duration) * width;
  const currentY = current ? height - Math.max(0, Math.min(100, current[metric.key])) / 100 * (height - 4) - 2 : height / 2;
  const protectionX = metric.protectionUntil && metric.protectionUntil > now && metric.protectionUntil < end
    ? ((metric.protectionUntil - start) / duration) * width
    : undefined;
  const color = COLORS[metric.key];
  const careX = lastCareAt >= start && lastCareAt <= now
    ? ((lastCareAt - start) / duration) * width
    : undefined;

  return <svg className="metric-chart" viewBox={`0 0 ${width} ${height}`} role="img" aria-label={`${metric.label} trend`}>
    <title>{`${metric.label}: solid history, current marker, dashed no-care forecast`}</title>
    <line className="chart-baseline" x1="0" y1={height - 1} x2={width} y2={height - 1} />
    {careX !== undefined ? <line className="chart-care" x1={careX} y1="0" x2={careX} y2={height} /> : null}
    <line className="chart-now" x1={nowX} y1="0" x2={nowX} y2={height} />
    {protectionX !== undefined ? <line className="chart-protection" x1={protectionX} y1="0" x2={protectionX} y2={height} /> : null}
    {history.length > 1 ? <path d={monotonePath(history)} fill="none" stroke={color} strokeWidth="2.2" /> : null}
    {forecast.length > 1 ? <path d={monotonePath(forecast)} fill="none" stroke={color} strokeWidth="1.7" strokeDasharray="4 4" opacity=".68" /> : null}
    <circle cx={nowX} cy={currentY} r="3.4" fill="#12150f" stroke={color} strokeWidth="2" />
  </svg>;
}
