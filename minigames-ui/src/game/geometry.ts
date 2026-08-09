import type { Point } from './types'

export const SCENE_WIDTH = 2048
export const SCENE_HEIGHT = 1536
export const PREPARE_CENTER: Point = { x: 1024, y: 750 }
export const PREPARE_ACTIVE_RADIUS = 246
export const PLACE_TARGET: Point = { x: 1024, y: 720 }
export const PLACE_TARGET_RADIUS = 128
export const COVER_TARGET: Point = { x: 1024, y: 686 }
export const COVER_TARGET_RADIUS = 196
export const WATER_TARGET = { x: 804, y: 520, width: 440, height: 250 }
export const WATER_GRID = { columns: 8, rows: 5 }

export interface LetterboxTransform {
  scale: number
  offsetX: number
  offsetY: number
  width: number
  height: number
}

export function clamp(value: number, min = 0, max = 1): number {
  return Math.min(max, Math.max(min, value))
}

export function distance(a: Point, b: Point): number {
  return Math.hypot(a.x - b.x, a.y - b.y)
}

export function insideCircle(point: Point, center: Point, radius: number): boolean {
  return distance(point, center) <= radius
}

export function insideRect(
  point: Point,
  rect: { x: number; y: number; width: number; height: number },
): boolean {
  return (
    point.x >= rect.x &&
    point.x <= rect.x + rect.width &&
    point.y >= rect.y &&
    point.y <= rect.y + rect.height
  )
}

export function radialSector(point: Point, center = PREPARE_CENTER, count = 12): number {
  const angle = Math.atan2(point.y - center.y, point.x - center.x)
  const normalized = (angle + Math.PI * 2) % (Math.PI * 2)
  return Math.min(count - 1, Math.floor((normalized / (Math.PI * 2)) * count))
}

export function computeLetterbox(
  viewportWidth: number,
  viewportHeight: number,
): LetterboxTransform {
  const scale = Math.min(viewportWidth / SCENE_WIDTH, viewportHeight / SCENE_HEIGHT)
  const width = SCENE_WIDTH * scale
  const height = SCENE_HEIGHT * scale
  return {
    scale,
    width,
    height,
    offsetX: (viewportWidth - width) / 2,
    offsetY: (viewportHeight - height) / 2,
  }
}

export function clientToScene(
  client: Point,
  rect: Pick<DOMRect, 'left' | 'top' | 'width' | 'height'>,
): Point {
  const transform = computeLetterbox(rect.width, rect.height)
  return {
    x: clamp(
      (client.x - rect.left - transform.offsetX) / transform.scale,
      0,
      SCENE_WIDTH,
    ),
    y: clamp(
      (client.y - rect.top - transform.offsetY) / transform.scale,
      0,
      SCENE_HEIGHT,
    ),
  }
}

export function waterCellIndex(point: Point): number | null {
  if (!insideRect(point, WATER_TARGET)) return null
  const column = Math.min(
    WATER_GRID.columns - 1,
    Math.floor(((point.x - WATER_TARGET.x) / WATER_TARGET.width) * WATER_GRID.columns),
  )
  const row = Math.min(
    WATER_GRID.rows - 1,
    Math.floor(((point.y - WATER_TARGET.y) / WATER_TARGET.height) * WATER_GRID.rows),
  )
  return row * WATER_GRID.columns + column
}
