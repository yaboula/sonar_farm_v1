import { SCENE_HEIGHT, SCENE_WIDTH, clamp } from './geometry'
import type { EncodedTraceSample, PointerFrame, TraceSample } from './types'

export const TRACE_INTERVAL_MS = 50
export const TRACE_MAX_SAMPLES = 400

function quantize(value: number, min: number, max: number): number {
  return Math.round(clamp(value, min, max))
}

export function encodeTraceSample(sample: TraceSample): EncodedTraceSample {
  return [
    quantize(sample.elapsed50ms, 0, 65535),
    quantize(sample.x, 0, SCENE_WIDTH),
    quantize(sample.y, 0, SCENE_HEIGHT),
    quantize(sample.flags, 0, 15),
    quantize(sample.tilt, -90, 90),
    quantize(sample.pressure, 0, 255),
  ]
}

export function pointerFlags(frame: PointerFrame, primaryAction = false): number {
  return (
    (frame.active ? 1 : 0) |
    (primaryAction ? 2 : 0) |
    (frame.keyboard ? 4 : 0) |
    (frame.error ? 8 : 0)
  )
}

export class TraceEncoder {
  readonly #startedAt: number
  #lastBucket = -1
  #samples: EncodedTraceSample[] = []

  constructor(startedAt = 0) {
    this.#startedAt = startedAt
  }

  record(timestampMs: number, frame: PointerFrame, primaryAction = false): boolean {
    if (this.#samples.length >= TRACE_MAX_SAMPLES) return false
    const bucket = Math.max(0, Math.floor((timestampMs - this.#startedAt) / TRACE_INTERVAL_MS))
    if (bucket <= this.#lastBucket) return false
    this.#lastBucket = bucket
    this.#samples.push(
      encodeTraceSample({
        elapsed50ms: bucket,
        x: frame.x,
        y: frame.y,
        flags: pointerFlags(frame, primaryAction),
        tilt: frame.tilt,
        pressure: frame.pressure * 255,
      }),
    )
    return true
  }

  values(): EncodedTraceSample[] {
    return this.#samples.map((sample) => [...sample])
  }

  clear(startedAt = this.#startedAt): TraceEncoder {
    return new TraceEncoder(startedAt)
  }
}
