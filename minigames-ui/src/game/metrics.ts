import { PLACE_TARGET_RADIUS, clamp } from './geometry'
import type { GameMetrics, GameState, MetricLabel, Step, StepSignals } from './types'

function mean(values: number[]): number {
  return values.length ? values.reduce((sum, value) => sum + value, 0) / values.length : 0
}

function variance(values: number[], average = mean(values)): number {
  return values.length
    ? values.reduce((sum, value) => sum + (value - average) ** 2, 0) / values.length
    : 0
}

export function calculateMetrics(state: GameState): GameMetrics {
  const coverage = state.prepare.sectors.filter(Boolean).length / state.prepare.sectors.length
  const depthAccuracy = 1 - Math.abs(state.prepare.depthProgress - 0.68) / 0.68
  const depth = clamp(depthAccuracy * 0.7 + coverage * 0.3 - state.prepare.overdig * 0.45)

  const distanceAccuracy = 1 - state.place.dropDistance / (PLACE_TARGET_RADIUS * 2)
  const tiltAccuracy = 1 - Math.abs(state.place.tilt) / 28
  const alignment = clamp(
    distanceAccuracy * 0.67 + tiltAccuracy * 0.23 + state.place.rootRelaxation * 0.1,
  )

  const coverBalance =
    1 - Math.abs(state.cover.leftContribution - state.cover.rightContribution)
  const coverAmount = Math.min(state.cover.leftContribution, state.cover.rightContribution)
  const idealCompaction = 1 - Math.abs(state.cover.compaction - 0.46) / 0.46
  const overPressPenalty = Math.max(0, state.cover.presses - 5) * 0.06
  const aeration = clamp(
    coverBalance * 0.25 +
      coverAmount * 0.25 +
      clamp(idealCompaction) * 0.25 +
      state.place.rootRelaxation * 0.25 -
      overPressPenalty,
  )

  const waterMean = mean(state.water.moisture)
  const waterVariance = variance(state.water.moisture, waterMean)
  const targetMeanAccuracy = 1 - Math.abs(waterMean - 0.72) / 0.72
  const hydration = clamp(
    targetMeanAccuracy * 0.58 +
      clamp(1 - waterVariance / 0.18) * 0.42 -
      Math.min(0.35, state.water.puddleExposure * 0.025),
  )

  return { depth, alignment, aeration, hydration }
}

const LABEL_THRESHOLDS: Record<keyof GameMetrics, [number, number]> = {
  depth: [0.78, 0.58],
  alignment: [0.82, 0.62],
  aeration: [0.76, 0.55],
  hydration: [0.78, 0.57],
}

export function qualitativeMetrics(
  metrics: GameMetrics,
): Record<keyof GameMetrics, MetricLabel> {
  return Object.fromEntries(
    Object.entries(metrics).map(([key, value]) => {
      const [excellent, good] = LABEL_THRESHOLDS[key as keyof GameMetrics]
      const label: MetricLabel =
        value >= excellent ? 'excellent' : value >= good ? 'good' : 'needs-attention'
      return [key, label]
    }),
  ) as Record<keyof GameMetrics, MetricLabel>
}

export function signalsForStep(state: GameState, step: Step): StepSignals {
  switch (step) {
    case 'prepare':
      return {
        depthProgress: state.prepare.depthProgress,
        radialCoverage:
          state.prepare.sectors.filter(Boolean).length / state.prepare.sectors.length,
        overdig: state.prepare.overdig,
      }
    case 'place':
      return {
        dropDistance: state.place.dropDistance,
        tiltDegrees: state.place.tilt,
        rootRelaxation: state.place.rootRelaxation,
      }
    case 'cover':
      return {
        leftContribution: state.cover.leftContribution,
        rightContribution: state.cover.rightContribution,
        compaction: state.cover.compaction,
      }
    case 'water': {
      const moistureMean = mean(state.water.moisture)
      return {
        meanMoisture: moistureMean,
        moistureVariance: variance(state.water.moisture, moistureMean),
        puddleExposure: state.water.puddleExposure,
      }
    }
  }
}

export function canAdvance(state: GameState): boolean {
  switch (state.step) {
    case 'prepare':
      return (
        state.prepare.depthProgress >= 0.5 &&
        state.prepare.sectors.filter(Boolean).length >= 7
      )
    case 'place':
      return state.place.placed && state.place.rootRelaxation >= 0.65
    case 'cover':
      return (
        state.cover.leftContribution >= 0.5 &&
        state.cover.rightContribution >= 0.5 &&
        state.cover.compaction >= 0.24
      )
    case 'water':
      return mean(state.water.moisture) >= 0.42
  }
}
