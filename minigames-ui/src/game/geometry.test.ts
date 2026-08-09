import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'
import {
  SCENE_HEIGHT,
  SCENE_WIDTH,
  computeLetterbox,
  radialSector,
  waterCellIndex,
} from './geometry'

describe('scene geometry', () => {
  it('letterboxes the 4:3 scene at 16:9 and 16:10', () => {
    const wide = computeLetterbox(1920, 1080)
    expect(wide.height).toBe(1080)
    expect(wide.width).toBe(1440)
    expect(wide.offsetX).toBe(240)

    const tall = computeLetterbox(1600, 1000)
    expect(tall.width).toBeCloseTo(1333.333, 2)
    expect(tall.offsetX).toBeCloseTo(133.333, 2)
  })

  it('maps radial sectors and water cells deterministically', () => {
    expect(radialSector({ x: 1200, y: 750 })).toBe(0)
    expect(waterCellIndex({ x: 805, y: 521 })).toBe(0)
    expect(waterCellIndex({ x: 1243, y: 769 })).toBe(39)
    expect(waterCellIndex({ x: 300, y: 300 })).toBeNull()
  })
})

describe('versioned runtime contract', () => {
  it('matches renderer geometry and blocks direct quality fields', () => {
    const path = resolve(process.cwd(), 'public/contracts/tomato-plant-v1.json')
    const contract = JSON.parse(readFileSync(path, 'utf8')) as {
      contractVersion: string
      scene: { width: number; height: number }
      sampling: { intervalMs: number; maxSamplesPerStep: number }
      weights: Record<string, number>
      checkpoint: { forbidden: string[] }
    }

    expect(contract.contractVersion).toBe('1.0.0')
    expect(contract.scene).toEqual({ width: SCENE_WIDTH, height: SCENE_HEIGHT, coordinateOrigin: 'top-left', letterbox: true })
    expect(contract.sampling).toMatchObject({ intervalMs: 50, maxSamplesPerStep: 400 })
    expect(Object.values(contract.weights).reduce((sum, weight) => sum + weight, 0)).toBe(100)
    expect(contract.checkpoint.forbidden).toContain('quality')
  })
})
