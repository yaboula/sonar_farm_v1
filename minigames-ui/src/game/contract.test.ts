import { readFileSync, readdirSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import {
  COVER_TARGET,
  PLACE_TARGET,
  PREPARE_CENTER,
  SCENE_HEIGHT,
  SCENE_WIDTH,
  WATER_GRID,
  WATER_TARGET,
} from './geometry'
import { TRACE_INTERVAL_MS, TRACE_MAX_SAMPLES } from './trace'
import { STEPS } from './types'

interface AssetEntry {
  file: string
  width: number
  height: number
  status?: string
}

function readJson<T>(relativePath: string): T {
  return JSON.parse(readFileSync(new URL(relativePath, import.meta.url), 'utf8')) as T
}

function pngDimensions(relativePath: string): { width: number; height: number } {
  const buffer = readFileSync(new URL(relativePath, import.meta.url))
  expect(buffer.subarray(1, 4).toString('ascii')).toBe('PNG')
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
  }
}

describe('runtime contract', () => {
  it('matches the constants used by the deterministic simulation', () => {
    const contract = readJson<{
      contractVersion: string
      scene: { width: number; height: number }
      steps: string[]
      sampling: { intervalMs: number; maxSamplesPerStep: number }
      weights: Record<string, number>
      geometry: {
        prepare: { targetCenter: typeof PREPARE_CENTER }
        place: { targetCenter: typeof PLACE_TARGET }
        cover: { targetCenter: typeof COVER_TARGET }
        water: {
          target: typeof WATER_TARGET
          gridColumns: number
          gridRows: number
        }
      }
    }>('../../public/contracts/tomato-plant-v1.json')

    expect(contract.contractVersion).toBe('1.0.0')
    expect(contract.scene).toEqual({ width: SCENE_WIDTH, height: SCENE_HEIGHT, coordinateOrigin: 'top-left', letterbox: true })
    expect(contract.steps).toEqual(STEPS)
    expect(contract.sampling.intervalMs).toBe(TRACE_INTERVAL_MS)
    expect(contract.sampling.maxSamplesPerStep).toBe(TRACE_MAX_SAMPLES)
    expect(Object.values(contract.weights).reduce((sum, weight) => sum + weight, 0)).toBe(100)
    expect(contract.geometry.prepare.targetCenter).toEqual(PREPARE_CENTER)
    expect(contract.geometry.place.targetCenter).toEqual(PLACE_TARGET)
    expect(contract.geometry.cover.targetCenter).toEqual(COVER_TARGET)
    expect(contract.geometry.water).toMatchObject({
      target: WATER_TARGET,
      gridColumns: WATER_GRID.columns,
      gridRows: WATER_GRID.rows,
    })
  })

  it('contains exactly the manifested, dimension-checked runtime PNGs', () => {
    const manifest = readJson<{ assets: AssetEntry[] }>(
      '../../public/assets/planting/manifest.json',
    )
    const directory = new URL('../../public/assets/planting/', import.meta.url)
    const pngFiles = readdirSync(directory).filter((file) => file.endsWith('.png')).sort()
    const manifested = manifest.assets.map((asset) => asset.file).sort()

    expect(manifest.assets).toHaveLength(24)
    expect(new Set(manifested).size).toBe(24)
    expect(pngFiles).toEqual(manifested)

    for (const asset of manifest.assets) {
      expect(pngDimensions(`../../public/assets/planting/${asset.file}`)).toEqual({
        width: asset.width,
        height: asset.height,
      })
    }

    const provisionalLogo = manifest.assets.find(
      (asset) => asset.file === 'logo_tomato_seedling_mark.png',
    )
    expect(provisionalLogo?.status).toBe('provisional')
  })
})
