import { describe, expect, it } from 'vitest'
import type { PointerFrame } from './types'
import { TRACE_MAX_SAMPLES, TraceEncoder, encodeTraceSample } from './trace'

const frame: PointerFrame = {
  x: 1024.49,
  y: 750.51,
  active: true,
  tilt: 7.6,
  pressure: 0.5,
  keyboard: false,
  error: false,
}

describe('trace encoder', () => {
  it('quantizes deterministic tuples at 20Hz', () => {
    const first = new TraceEncoder(1000)
    const second = new TraceEncoder(1000)
    for (const timestamp of [1000, 1012, 1050, 1099, 1100]) {
      first.record(timestamp, frame, true)
      second.record(timestamp, frame, true)
    }
    expect(first.values()).toEqual(second.values())
    expect(first.values()).toEqual([
      [0, 1024, 751, 3, 8, 128],
      [1, 1024, 751, 3, 8, 128],
      [2, 1024, 751, 3, 8, 128],
    ])
  })

  it('caps each step at 400 samples', () => {
    const trace = new TraceEncoder(0)
    for (let index = 0; index < 600; index += 1) {
      trace.record(index * 50, frame)
    }
    expect(trace.values()).toHaveLength(TRACE_MAX_SAMPLES)
  })

  it('clamps samples to contract-safe integer ranges', () => {
    expect(
      encodeTraceSample({
        elapsed50ms: 999999,
        x: -50,
        y: 9000,
        flags: 80,
        tilt: -200,
        pressure: 400,
      }),
    ).toEqual([65535, 0, 1536, 15, -90, 255])
  })
})
