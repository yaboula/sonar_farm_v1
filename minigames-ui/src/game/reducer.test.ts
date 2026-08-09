import { describe, expect, it } from 'vitest'
import { calculateMetrics, qualitativeMetrics } from './metrics'
import { createInitialState, gameReducer, persistHelpMode, readHelpMode } from './reducer'

describe('planting reducer and metrics', () => {
  it('builds prepare depth and radial coverage without resetting on an error', () => {
    let state = createInitialState()
    for (let sector = 0; sector < 12; sector += 1) {
      const angle = ((sector + 0.5) / 12) * Math.PI * 2
      const point = {
        x: 1024 + Math.cos(angle) * 170,
        y: 750 + Math.sin(angle) * 170,
      }
      for (let stroke = 0; stroke < 4; stroke += 1) {
        state = gameReducer(state, {
          type: 'PREPARE_STROKE',
          point,
          pressure: 0.7,
        })
      }
    }
    const beforeError = state.prepare.depthProgress
    state = gameReducer(state, {
      type: 'PREPARE_STROKE',
      point: { x: 220, y: 300 },
      pressure: 1,
    })

    expect(state.prepare.sectors.every(Boolean)).toBe(true)
    expect(state.prepare.depthProgress).toBe(beforeError)
    expect(state.prepare.overdig).toBeGreaterThan(0)
  })

  it('penalizes overdig and compaction while preserving qualitative output', () => {
    const healthy = createInitialState()
    healthy.prepare.depthProgress = 0.68
    healthy.prepare.sectors.fill(true)
    healthy.place.dropDistance = 12
    healthy.place.tilt = 2
    healthy.place.rootRelaxation = 1
    healthy.cover.leftContribution = 0.8
    healthy.cover.rightContribution = 0.8
    healthy.cover.compaction = 0.46
    healthy.cover.presses = 3
    healthy.water.moisture.fill(0.72)

    const damaged = structuredClone(healthy)
    damaged.prepare.overdig = 0.9
    damaged.cover.compaction = 1
    damaged.cover.presses = 11

    const healthyMetrics = calculateMetrics(healthy)
    const damagedMetrics = calculateMetrics(damaged)
    expect(damagedMetrics.depth).toBeLessThan(healthyMetrics.depth)
    expect(damagedMetrics.aeration).toBeLessThan(healthyMetrics.aeration)
    expect(Object.values(qualitativeMetrics(healthyMetrics))).toEqual([
      'excellent',
      'excellent',
      'excellent',
      'excellent',
    ])
  })
})

describe('help preference', () => {
  it('persists minimal help and falls back safely', () => {
    const values = new Map<string, string>()
    const storage = {
      getItem: (key: string) => values.get(key) ?? null,
      setItem: (key: string, value: string) => values.set(key, value),
    }
    persistHelpMode('minimal', storage)
    expect(readHelpMode(storage)).toBe('minimal')
    expect(readHelpMode(undefined)).toBe('full')
  })
})
