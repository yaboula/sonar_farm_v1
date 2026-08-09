export type MetricKey = "water" | "nutrients" | "weeds" | "pests";

export type InspectionMetric = {
  key: MetricKey;
  label: string;
  value: number;
  enabled: boolean;
  status: "unaffected" | "stable" | "low" | "elevated" | "severe" | "critical" | "high";
  protectionTier?: string;
  protectionUntil?: number;
};

export type InspectionSample = {
  at: number;
  phase: "history" | "now" | "forecast";
  progress: number;
  health: number;
  water: number;
  nutrients: number;
  weeds: number;
  pests: number;
};

export type InspectionPayloadV1 = {
  version: 1;
  subject: { id: string; crop: string; label: string; stage: string; slot: string; state: string; isMine: boolean };
  timing: {
    serverNow: number;
    lastCareAt: number;
    readyAt?: number;
    readyInSeconds?: number;
    readySinceSeconds?: number;
    forecastSeconds: number;
  };
  growth: number;
  health: number;
  spoilage: number;
  metrics: InspectionMetric[];
  series?: { historyStart: number; now: number; forecastEnd: number; samples: InspectionSample[] };
  diagnosis: { cause: string; severity: number; headline: string; recommendation: string };
  layout?: { leftInset: number; rightInset: number };
};

export type InspectionMessage =
  | { type: "inspection:open" | "inspection:update"; payload: InspectionPayloadV1 }
  | { type: "inspection:close"; payload?: { reason?: string } };
