import type { InspectionPayloadV1, InspectionSample } from "./types";

export function inspectionFixture(now = Math.floor(Date.now() / 1000)): InspectionPayloadV1 {
  const samples: InspectionSample[] = [];
  const historySeconds = 252;
  const addSample = (offset: number) => {
    samples.push({
      at: now + offset,
      phase: offset < 0 ? "history" : offset === 0 ? "now" : "forecast",
      progress: 68 + offset / 600 * 5,
      health: 84 - Math.max(0, offset) / 600 * 2,
      water: 42 - offset / 600 * 7,
      nutrients: 61 - offset / 600 * 4,
      weeds: 38 + offset / 600 * 10,
      pests: 12 + offset / 600 * 5,
    });
  };
  addSample(-historySeconds);
  for (let offset = -240; offset <= 600; offset += 30) {
    addSample(offset);
  }
  return {
    version: 1,
    subject: { id: "fixture-07-b", crop: "tomato", label: "Tomato", stage: "Flowering", slot: "east_field · 7", state: "growing", isMine: true },
    timing: { serverNow: now, plantedAt: now - 1440, lastCareAt: now - 252, readyAt: now + 504, readyInSeconds: 504, forecastSeconds: 600 },
    growth: 68,
    health: 84,
    spoilage: 0,
    metrics: [
      { key: "water", label: "Water", value: 42, enabled: true, status: "low" },
      { key: "nutrients", label: "Nutrients", value: 61, enabled: true, status: "stable", protectionTier: "plus", protectionUntil: now + 343 },
      { key: "weeds", label: "Weeds", value: 38, enabled: true, status: "elevated" },
      { key: "pests", label: "Pests", value: 12, enabled: true, status: "low" },
    ],
    series: { plantedAt: now - 1440, lastCare: now - 252, windowStart: now - 252, windowLen: 252, historyStart: now - 252, now, forecastEnd: now, samples },
    diagnosis: { cause: "weeds", severity: 38, headline: "WEEDS → FASTER WATER LOSS", recommendation: "REMOVE WEEDS" },
    outcome: { quality: 71, qualityTier: "fine", qualityLabel: "Fine", production: 85, dominantDefect: undefined, waterStress: 8, nutrientStress: 14, pestDamage: 2 },
    layout: { leftInset: 335, rightInset: 18 },
  };
}
