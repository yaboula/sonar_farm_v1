import {
  type Dispatch,
  type KeyboardEvent as ReactKeyboardEvent,
  type PointerEvent as ReactPointerEvent,
  useEffect,
  useRef,
} from 'react'
import { audioEngine } from '../audio/audioEngine'
import {
  COVER_TARGET,
  PREPARE_CENTER,
  clientToScene,
  distance,
  insideRect,
} from '../game/geometry'
import type { GameAction, GameState, Point, PointerFrame } from '../game/types'
import { loadAssets, renderScene, type AssetMap } from './renderScene'

interface PlantingCanvasProps {
  state: GameState
  dispatch: Dispatch<GameAction>
  onTrace: (frame: PointerFrame, primaryAction?: boolean) => void
}

const LEFT_SOIL = { x: 550, y: 610, width: 240, height: 150 }
const RIGHT_SOIL = { x: 1215, y: 610, width: 275, height: 150 }

export function PlantingCanvas({
  state,
  dispatch,
  onTrace,
}: PlantingCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const stateRef = useRef(state)
  const assetsRef = useRef<AssetMap>(new Map())
  const draggingRef = useRef(false)
  const lastPointRef = useRef<Point>(state.pointer)
  const reducedMotionRef = useRef(false)

  stateRef.current = state

  useEffect(() => {
    let active = true
    void loadAssets().then((assets) => {
      if (active) assetsRef.current = assets
    })
    const media = window.matchMedia('(prefers-reduced-motion: reduce)')
    const updateMotion = () => {
      reducedMotionRef.current = media.matches
    }
    updateMotion()
    media.addEventListener('change', updateMotion)
    return () => {
      active = false
      media.removeEventListener('change', updateMotion)
    }
  }, [])

  useEffect(() => {
    if (!state.visible) return
    let frameId = 0
    let previousWaterTick = performance.now()
    const draw = (time: number) => {
      const canvas = canvasRef.current
      const context = canvas?.getContext('2d')
      if (canvas && context) {
        renderScene(
          canvas,
          context,
          assetsRef.current,
          stateRef.current,
          time,
          reducedMotionRef.current,
        )
      }
      if (
        stateRef.current.step === 'water' &&
        stateRef.current.water.pouring &&
        time - previousWaterTick >= 50
      ) {
        const dt = Math.min(0.15, (time - previousWaterTick) / 1000)
        previousWaterTick = time
        dispatch({
          type: 'WATER_TICK',
          dt,
          point: stateRef.current.pointer,
        })
        onTrace(stateRef.current.pointer, true)
      }
      frameId = requestAnimationFrame(draw)
    }
    frameId = requestAnimationFrame(draw)
    return () => cancelAnimationFrame(frameId)
  }, [dispatch, onTrace, state.visible])

  const updateFrame = (
    point: Point,
    active: boolean,
    primaryAction = false,
    keyboard = false,
    tilt = stateRef.current.pointer.tilt,
    error = false,
  ) => {
    const frame: PointerFrame = {
      ...point,
      active,
      tilt,
      pressure: active ? 0.72 : 0,
      keyboard,
      error,
    }
    dispatch({ type: 'POINTER', frame })
    onTrace(frame, primaryAction)
    lastPointRef.current = point
  }

  const scenePoint = (event: ReactPointerEvent<HTMLCanvasElement>) =>
    clientToScene(
      { x: event.clientX, y: event.clientY },
      event.currentTarget.getBoundingClientRect(),
    )

  const handlePointerDown = (event: ReactPointerEvent<HTMLCanvasElement>) => {
    void audioEngine.unlock()
    event.currentTarget.setPointerCapture(event.pointerId)
    const point = scenePoint(event)
    draggingRef.current = true
    updateFrame(point, true, true)
    switch (stateRef.current.step) {
      case 'prepare':
        audioEngine.play('dig')
        dispatch({ type: 'PREPARE_STROKE', point, pressure: event.pressure || 0.72 })
        break
      case 'place':
        if (distance(point, stateRef.current.place.position) < 260) {
          dispatch({ type: 'PLACE_PICKUP' })
        }
        break
      case 'cover':
        if (insideRect(point, LEFT_SOIL)) {
          dispatch({ type: 'COVER_PICKUP', side: 'left', point })
        } else if (insideRect(point, RIGHT_SOIL)) {
          dispatch({ type: 'COVER_PICKUP', side: 'right', point })
        } else {
          dispatch({ type: 'COVER_PRESS', point })
          audioEngine.play('soil')
        }
        break
      case 'water':
        dispatch({
          type: 'WATER_MOVE',
          point: { x: point.x + 200, y: point.y - 80 },
          tilt: stateRef.current.water.canTilt,
        })
        break
    }
  }

  const handlePointerMove = (event: ReactPointerEvent<HTMLCanvasElement>) => {
    const point = scenePoint(event)
    const previous = lastPointRef.current
    const tiltDelta = Math.max(-28, Math.min(28, (point.x - previous.x) * 0.2))
    updateFrame(point, draggingRef.current, draggingRef.current, false, tiltDelta)
    if (!draggingRef.current) return
    switch (stateRef.current.step) {
      case 'prepare':
        dispatch({ type: 'PREPARE_STROKE', point, pressure: event.pressure || 0.72 })
        break
      case 'place':
        if (stateRef.current.place.dragging) {
          dispatch({ type: 'PLACE_MOVE', point, tilt: tiltDelta })
        }
        break
      case 'cover':
        if (stateRef.current.cover.draggingFrom) dispatch({ type: 'COVER_MOVE', point })
        break
      case 'water':
        dispatch({
          type: 'WATER_MOVE',
          point: { x: point.x + 200, y: point.y - 80 },
          tilt: tiltDelta,
        })
        break
    }
  }

  const handlePointerUp = (event: ReactPointerEvent<HTMLCanvasElement>) => {
    const point = scenePoint(event)
    draggingRef.current = false
    updateFrame(point, false)
    switch (stateRef.current.step) {
      case 'prepare':
        break
      case 'place':
        if (stateRef.current.place.dragging) dispatch({ type: 'PLACE_DROP', point })
        break
      case 'cover':
        if (stateRef.current.cover.draggingFrom) dispatch({ type: 'COVER_DROP', point })
        break
      case 'water':
        break
    }
  }

  const moveKeyboardCursor = (point: Point) => {
    updateFrame(point, false, false, true)
    switch (stateRef.current.step) {
      case 'place':
        dispatch({
          type: 'PLACE_MOVE',
          point,
          tilt: stateRef.current.place.tilt,
        })
        break
      case 'cover':
        if (stateRef.current.cover.draggingFrom) dispatch({ type: 'COVER_MOVE', point })
        break
      case 'water':
        dispatch({
          type: 'WATER_MOVE',
          point: { x: point.x + 200, y: point.y - 80 },
          tilt: stateRef.current.water.canTilt,
        })
        break
      case 'prepare':
        break
    }
  }

  const handleKeyDown = (event: ReactKeyboardEvent<HTMLCanvasElement>) => {
    const delta: Record<string, Point> = {
      ArrowUp: { x: 0, y: -32 },
      ArrowDown: { x: 0, y: 32 },
      ArrowLeft: { x: -32, y: 0 },
      ArrowRight: { x: 32, y: 0 },
    }
    if (delta[event.key]) {
      event.preventDefault()
      const movement = delta[event.key]
      moveKeyboardCursor({
        x: stateRef.current.pointer.x + movement.x,
        y: stateRef.current.pointer.y + movement.y,
      })
      return
    }
    if (event.key === 'q' || event.key === 'e') {
      const amount = event.key === 'q' ? -3 : 3
      if (stateRef.current.step === 'place') {
        dispatch({
          type: 'PLACE_MOVE',
          point: stateRef.current.place.position,
          tilt: stateRef.current.place.tilt + amount,
        })
      }
      if (stateRef.current.step === 'water') {
        dispatch({
          type: 'WATER_MOVE',
          point: stateRef.current.water.canPosition,
          tilt: stateRef.current.water.canTilt + amount,
        })
      }
      onTrace({ ...stateRef.current.pointer, keyboard: true }, true)
      return
    }
    if (event.key.toLowerCase() === 'r' && stateRef.current.step === 'place') {
      dispatch({ type: 'RELAX_ROOTS' })
      audioEngine.play('roots')
      onTrace({ ...stateRef.current.pointer, keyboard: true }, true)
      return
    }
    if (event.key === '1' && stateRef.current.step === 'cover') {
      const point = { x: 670, y: 680 }
      updateFrame(point, true, true, true)
      dispatch({ type: 'COVER_PICKUP', side: 'left', point })
      return
    }
    if (event.key === '2' && stateRef.current.step === 'cover') {
      const point = { x: 1350, y: 680 }
      updateFrame(point, true, true, true)
      dispatch({ type: 'COVER_PICKUP', side: 'right', point })
      return
    }
    if (event.key.toLowerCase() === 'p' && stateRef.current.step === 'cover') {
      dispatch({ type: 'COVER_PRESS', point: COVER_TARGET })
      onTrace({ ...stateRef.current.pointer, keyboard: true }, true)
      return
    }
    if (event.key !== ' ' || event.repeat) return
    event.preventDefault()
    const current = stateRef.current
    switch (current.step) {
      case 'prepare': {
        const angle = ((current.prepare.strokes % 12) + 0.5) / 12 * Math.PI * 2
        const keyboardPoint =
          distance(current.pointer, PREPARE_CENTER) < 32
            ? {
                x: PREPARE_CENTER.x + Math.cos(angle) * 170,
                y: PREPARE_CENTER.y + Math.sin(angle) * 170,
              }
            : current.pointer
        dispatch({
          type: 'PREPARE_STROKE',
          point: keyboardPoint,
          pressure: 0.72,
        })
        break
      }
      case 'place':
        if (current.place.dragging) {
          dispatch({ type: 'PLACE_DROP', point: current.place.position })
        } else {
          dispatch({ type: 'PLACE_PICKUP' })
        }
        break
      case 'cover':
        if (current.cover.draggingFrom) {
          dispatch({ type: 'COVER_DROP', point: current.pointer })
        }
        break
      case 'water':
        dispatch({ type: 'WATER_POUR', active: true })
        break
    }
    onTrace({ ...current.pointer, active: true, keyboard: true }, true)
  }

  const handleKeyUp = (event: ReactKeyboardEvent<HTMLCanvasElement>) => {
    if (event.key === ' ' && stateRef.current.step === 'water') {
      dispatch({ type: 'WATER_POUR', active: false })
      onTrace({ ...stateRef.current.pointer, active: false, keyboard: true })
    }
  }

  return (
    <canvas
      ref={canvasRef}
      className="planting-canvas"
      aria-label={`Interactive planting area. Current step: ${state.step}`}
      role="application"
      tabIndex={0}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onPointerCancel={handlePointerUp}
      onKeyDown={handleKeyDown}
      onKeyUp={handleKeyUp}
    />
  )
}
