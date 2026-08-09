import {
  COVER_TARGET,
  PREPARE_ACTIVE_RADIUS,
  PREPARE_CENTER,
  SCENE_HEIGHT,
  SCENE_WIDTH,
  WATER_TARGET,
  clamp,
  computeLetterbox,
} from '../game/geometry'
import type { GameState, Point } from '../game/types'

const ASSET_ROOT = './assets/planting/'

const FILES = [
  'soil_block_01_dry_intact.png',
  'soil_block_02_hole_shallow.png',
  'soil_block_03_hole_medium.png',
  'soil_block_04_hole_correct.png',
  'soil_block_05_hole_overdug.png',
  'soil_block_06_covered_dry.png',
  'soil_block_07_wet_partial.png',
  'soil_block_08_wet_even.png',
  'soil_block_09_overwatered.png',
  'overlay_hole_cavity_shadow.png',
  'overlay_loose_soil_left.png',
  'overlay_loose_soil_right.png',
  'overlay_soil_compacted_patch.png',
  'overlay_moisture_patch.png',
  'overlay_dry_zone.png',
  'overlay_small_puddle.png',
  'tomato_seedling_complete.png',
  'tomato_seedling_stem_leaves.png',
  'tomato_roots_relaxed.png',
  'tool_hand_shovel.png',
  'material_loose_soil_mound.png',
  'tool_watering_can.png',
] as const

type AssetFile = (typeof FILES)[number]
export type AssetMap = Map<AssetFile, HTMLImageElement>

export function loadAssets(): Promise<AssetMap> {
  const assets: AssetMap = new Map()
  return Promise.all(
    FILES.map(
      (file) =>
        new Promise<void>((resolve) => {
          const image = new Image()
          image.onload = () => resolve()
          image.onerror = () => resolve()
          image.src = `${ASSET_ROOT}${file}`
          assets.set(file, image)
        }),
    ),
  ).then(() => assets)
}

function seeded(index: number, salt: number): number {
  const value = Math.sin(index * 91.731 + salt * 17.133) * 43758.5453
  return value - Math.floor(value)
}

function drawImage(
  context: CanvasRenderingContext2D,
  assets: AssetMap,
  file: AssetFile,
  alpha = 1,
): void {
  const image = assets.get(file)
  if (!image?.complete || !image.naturalWidth) return
  context.save()
  context.globalAlpha = clamp(alpha)
  context.drawImage(image, 0, 0, SCENE_WIDTH, SCENE_HEIGHT)
  context.restore()
}

function drawProp(
  context: CanvasRenderingContext2D,
  assets: AssetMap,
  file: AssetFile,
  position: Point,
  scale: number,
  rotationDegrees = 0,
  alpha = 1,
): void {
  const image = assets.get(file)
  if (!image?.complete || !image.naturalWidth) return
  context.save()
  context.translate(position.x, position.y)
  context.rotate((rotationDegrees * Math.PI) / 180)
  context.scale(scale, scale)
  context.globalAlpha = clamp(alpha)
  context.drawImage(image, -512, -760)
  context.restore()
}

function drawGuideArrow(
  context: CanvasRenderingContext2D,
  from: Point,
  to: Point,
  bend = 0,
): void {
  const middle = {
    x: (from.x + to.x) / 2,
    y: (from.y + to.y) / 2 + bend,
  }
  context.save()
  context.strokeStyle = 'rgba(245, 199, 69, .86)'
  context.fillStyle = 'rgba(245, 199, 69, .9)'
  context.lineWidth = 7
  context.lineCap = 'round'
  context.shadowColor = 'rgba(245, 199, 69, .28)'
  context.shadowBlur = 14
  context.beginPath()
  context.moveTo(from.x, from.y)
  context.quadraticCurveTo(middle.x, middle.y, to.x, to.y)
  context.stroke()
  const angle = Math.atan2(to.y - middle.y, to.x - middle.x)
  context.beginPath()
  context.moveTo(to.x, to.y)
  context.lineTo(to.x - Math.cos(angle - 0.55) * 28, to.y - Math.sin(angle - 0.55) * 28)
  context.lineTo(to.x - Math.cos(angle + 0.55) * 28, to.y - Math.sin(angle + 0.55) * 28)
  context.closePath()
  context.fill()
  context.restore()
}

function drawPrepare(
  context: CanvasRenderingContext2D,
  assets: AssetMap,
  state: GameState,
  time: number,
  reducedMotion: boolean,
): void {
  const progress = state.prepare.depthProgress
  const stage = clamp(progress / 0.24, 0, 4)
  const current = Math.floor(stage)
  const fraction = stage - current
  const soil = [
    'soil_block_01_dry_intact.png',
    'soil_block_02_hole_shallow.png',
    'soil_block_03_hole_medium.png',
    'soil_block_04_hole_correct.png',
    'soil_block_05_hole_overdug.png',
  ] as const
  drawImage(context, assets, soil[current] ?? soil[4])
  if (fraction > 0 && soil[current + 1]) drawImage(context, assets, soil[current + 1], fraction)

  context.save()
  context.strokeStyle = 'rgba(245, 199, 69, .88)'
  context.shadowColor = 'rgba(245, 199, 69, .34)'
  context.shadowBlur = 18
  context.lineCap = 'round'
  context.lineWidth = 8
  for (let segment = 0; segment < 4; segment += 1) {
    const start = segment * Math.PI * 0.5 + 0.12
    context.beginPath()
    context.arc(
      PREPARE_CENTER.x,
      PREPARE_CENTER.y,
      PREPARE_ACTIVE_RADIUS * 0.72,
      start,
      start + Math.PI * 0.34,
    )
    context.stroke()
  }
  context.restore()

  drawProp(context, assets, 'tool_hand_shovel.png', state.pointer, 0.34, -16)

  const particleCount = reducedMotion ? 5 : 18
  for (let index = 0; index < particleCount; index += 1) {
    const lifetime = ((time / 900 + seeded(index, state.prepare.strokes)) % 1)
    const angle = seeded(index, 2) * Math.PI * 2
    const radius = 30 + lifetime * (reducedMotion ? 24 : 86)
    const x = state.pointer.x + Math.cos(angle) * radius
    const y = state.pointer.y + Math.sin(angle) * radius - lifetime * 28
    context.fillStyle = `rgba(116, 69, 38, ${0.65 * (1 - lifetime)})`
    context.fillRect(x, y, 8 + seeded(index, 3) * 8, 6 + seeded(index, 4) * 6)
  }
}

function drawPlace(
  context: CanvasRenderingContext2D,
  assets: AssetMap,
  state: GameState,
  time: number,
  reducedMotion: boolean,
): void {
  drawImage(context, assets, 'soil_block_04_hole_correct.png')
  drawImage(context, assets, 'overlay_hole_cavity_shadow.png')
  context.save()
  context.strokeStyle = 'rgba(245, 199, 69, .62)'
  context.lineWidth = 4
  context.beginPath()
  context.moveTo(350, 720)
  context.lineTo(1698, 720)
  context.stroke()
  context.beginPath()
  context.moveTo(PREPARE_CENTER.x, 310)
  context.lineTo(PREPARE_CENTER.x, 965)
  context.stroke()
  context.restore()
  drawProp(
    context,
    assets,
    state.place.rootRelaxation >= 0.65
      ? 'tomato_roots_relaxed.png'
      : 'tomato_seedling_complete.png',
    state.place.position,
    0.72,
    state.place.tilt,
  )
  if (state.place.rootRelaxation >= 0.65) {
    drawProp(
      context,
      assets,
      'tomato_seedling_stem_leaves.png',
      state.place.position,
      0.72,
      state.place.tilt,
    )
    drawMotes(context, state.place.position, time, reducedMotion)
  }
}

function drawCover(
  context: CanvasRenderingContext2D,
  assets: AssetMap,
  state: GameState,
  time: number,
  reducedMotion: boolean,
): void {
  const coverProgress = clamp(
    (state.cover.leftContribution + state.cover.rightContribution) / 1.4,
  )
  drawImage(context, assets, 'soil_block_04_hole_correct.png')
  drawImage(context, assets, 'soil_block_06_covered_dry.png', coverProgress)
  drawImage(context, assets, 'overlay_loose_soil_left.png', 1 - state.cover.leftContribution * 0.8)
  drawImage(
    context,
    assets,
    'overlay_loose_soil_right.png',
    1 - state.cover.rightContribution * 0.8,
  )
  if (state.cover.leftContribution < 0.8) {
    drawGuideArrow(context, { x: 705, y: 645 }, { x: 930, y: 705 }, -48)
  }
  if (state.cover.rightContribution < 0.8) {
    drawGuideArrow(context, { x: 1345, y: 645 }, { x: 1115, y: 705 }, -48)
  }
  drawProp(context, assets, 'tomato_seedling_stem_leaves.png', { x: 1024, y: 720 }, 0.72)
  if (state.cover.compaction > 0.58) {
    drawImage(context, assets, 'overlay_soil_compacted_patch.png', state.cover.compaction)
  }
  if (state.cover.dragPosition) {
    drawProp(
      context,
      assets,
      'material_loose_soil_mound.png',
      state.cover.dragPosition,
      0.24,
    )
  }
  if (coverProgress > 0.7) drawMotes(context, COVER_TARGET, time, reducedMotion)
}

function drawWater(
  context: CanvasRenderingContext2D,
  assets: AssetMap,
  state: GameState,
  time: number,
  reducedMotion: boolean,
): void {
  const mean = state.water.moisture.reduce((sum, value) => sum + value, 0) / 40
  drawImage(context, assets, 'soil_block_06_covered_dry.png')
  drawImage(context, assets, 'soil_block_07_wet_partial.png', clamp(mean / 0.42))
  drawImage(context, assets, 'soil_block_08_wet_even.png', clamp((mean - 0.38) / 0.35))
  if (state.water.puddleExposure > 0.5) {
    drawImage(
      context,
      assets,
      'soil_block_09_overwatered.png',
      clamp(state.water.puddleExposure / 8),
    )
    drawImage(context, assets, 'overlay_small_puddle.png', clamp(state.water.puddleExposure / 5))
  } else {
    drawImage(context, assets, 'overlay_moisture_patch.png', clamp(mean / 0.7))
    drawImage(context, assets, 'overlay_dry_zone.png', clamp(1 - mean / 0.6))
  }
  drawProp(context, assets, 'tomato_seedling_stem_leaves.png', { x: 1024, y: 720 }, 0.72)
  if (state.result) {
    drawMotes(context, { x: 1024, y: 640 }, time, reducedMotion)
    return
  }
  drawProp(
    context,
    assets,
    'tool_watering_can.png',
    state.water.canPosition,
    0.46,
    state.water.canTilt,
  )

  if (state.water.pouring) {
    const origin = {
      x: state.water.canPosition.x - 120,
      y: state.water.canPosition.y - 132,
    }
    const target = state.pointer
    context.save()
    context.strokeStyle = 'rgba(128, 203, 217, .7)'
    context.lineWidth = 12
    context.beginPath()
    context.moveTo(origin.x, origin.y)
    context.bezierCurveTo(origin.x - 50, origin.y + 120, target.x + 60, target.y - 80, target.x, target.y)
    context.stroke()
    context.restore()

    const dropletCount = reducedMotion ? 4 : 13
    for (let index = 0; index < dropletCount; index += 1) {
      const phase = (time / 520 + seeded(index, 5)) % 1
      const x = origin.x + (target.x - origin.x) * phase + (seeded(index, 6) - 0.5) * 28
      const y = origin.y + (target.y - origin.y) * phase + Math.sin(phase * Math.PI) * -60
      context.fillStyle = `rgba(151, 218, 230, ${0.4 + phase * 0.45})`
      context.beginPath()
      context.ellipse(x, y, 5, 12, 0, 0, Math.PI * 2)
      context.fill()
    }
    const ripplePhase = (time / 1000) % 1
    context.strokeStyle = `rgba(148, 207, 209, ${0.55 * (1 - ripplePhase)})`
    context.lineWidth = 5
    context.beginPath()
    context.ellipse(
      target.x,
      target.y,
      24 + ripplePhase * (reducedMotion ? 36 : 90),
      10 + ripplePhase * (reducedMotion ? 15 : 38),
      0,
      0,
      Math.PI * 2,
    )
    context.stroke()
  }

  context.save()
  context.strokeStyle = 'rgba(245, 199, 69, .66)'
  context.lineWidth = 5
  context.beginPath()
  context.ellipse(
    WATER_TARGET.x + WATER_TARGET.width / 2,
    WATER_TARGET.y + WATER_TARGET.height / 2,
    WATER_TARGET.width * 0.64,
    WATER_TARGET.height * 0.68,
    0,
    0.18,
    Math.PI * 1.82,
  )
  context.stroke()
  context.restore()
  drawGuideArrow(
    context,
    { x: WATER_TARGET.x + 30, y: WATER_TARGET.y + WATER_TARGET.height * 0.7 },
    {
      x: WATER_TARGET.x + WATER_TARGET.width + 34,
      y: WATER_TARGET.y + WATER_TARGET.height * 0.63,
    },
    105,
  )
}

function drawMotes(
  context: CanvasRenderingContext2D,
  center: Point,
  time: number,
  reducedMotion: boolean,
): void {
  const count = reducedMotion ? 3 : 11
  for (let index = 0; index < count; index += 1) {
    const phase = (time / 1600 + seeded(index, 9)) % 1
    const angle = seeded(index, 10) * Math.PI * 2
    const radius = 34 + seeded(index, 11) * 150
    const x = center.x + Math.cos(angle) * radius
    const y = center.y + Math.sin(angle) * radius - phase * 70
    context.fillStyle = `rgba(245, 194, 66, ${Math.sin(phase * Math.PI) * 0.7})`
    context.beginPath()
    context.arc(x, y, 4 + seeded(index, 12) * 5, 0, Math.PI * 2)
    context.fill()
  }
}

export function renderScene(
  canvas: HTMLCanvasElement,
  context: CanvasRenderingContext2D,
  assets: AssetMap,
  state: GameState,
  time: number,
  reducedMotion: boolean,
): void {
  const dpr = Math.min(window.devicePixelRatio || 1, 2)
  const displayWidth = Math.max(1, Math.floor(canvas.clientWidth * dpr))
  const displayHeight = Math.max(1, Math.floor(canvas.clientHeight * dpr))
  if (canvas.width !== displayWidth || canvas.height !== displayHeight) {
    canvas.width = displayWidth
    canvas.height = displayHeight
  }

  context.setTransform(1, 0, 0, 1, 0, 0)
  context.clearRect(0, 0, canvas.width, canvas.height)
  const letterbox = computeLetterbox(canvas.width, canvas.height)
  context.setTransform(
    letterbox.scale,
    0,
    0,
    letterbox.scale,
    letterbox.offsetX,
    letterbox.offsetY,
  )

  switch (state.step) {
    case 'prepare':
      drawPrepare(context, assets, state, time, reducedMotion)
      break
    case 'place':
      drawPlace(context, assets, state, time, reducedMotion)
      break
    case 'cover':
      drawCover(context, assets, state, time, reducedMotion)
      break
    case 'water':
      drawWater(context, assets, state, time, reducedMotion)
      break
  }
}
