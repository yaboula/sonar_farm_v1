import {
  COVER_TARGET,
  COVER_TARGET_RADIUS,
  PLACE_TARGET,
  PLACE_TARGET_RADIUS,
  PREPARE_ACTIVE_RADIUS,
  PREPARE_CENTER,
  clamp,
  distance,
  radialSector,
  waterCellIndex,
} from './geometry'
import { STEPS, type GameAction, type GameState, type HelpMode, type Point } from './types'

const HELP_KEY = 'sonar-farm:tomato-plant:help'

export function readHelpMode(storage: Pick<Storage, 'getItem'> | undefined): HelpMode {
  try {
    return storage?.getItem(HELP_KEY) === 'minimal' ? 'minimal' : 'full'
  } catch {
    return 'full'
  }
}

export function persistHelpMode(
  mode: HelpMode,
  storage: Pick<Storage, 'setItem'> | undefined,
): void {
  try {
    storage?.setItem(HELP_KEY, mode)
  } catch {
    // Private browser modes can reject writes; help still works for this session.
  }
}

export function createInitialState(
  sessionId = 'browser-preview',
  helpMode: HelpMode = 'full',
): GameState {
  return {
    sessionId,
    visible: false,
    step: 'prepare',
    completedSteps: [],
    helpMode,
    pointer: {
      x: PREPARE_CENTER.x,
      y: PREPARE_CENTER.y,
      active: false,
      tilt: 0,
      pressure: 0,
      keyboard: false,
      error: false,
    },
    prepare: {
      depthProgress: 0,
      sectors: Array.from({ length: 12 }, () => false),
      overdig: 0,
      strokes: 0,
    },
    place: {
      position: { x: 1570, y: 742 },
      dragging: false,
      placed: false,
      tilt: 0,
      dropDistance: PLACE_TARGET_RADIUS * 3,
      rootRelaxation: 0,
    },
    cover: {
      leftContribution: 0,
      rightContribution: 0,
      compaction: 0,
      draggingFrom: null,
      dragPosition: null,
      presses: 0,
    },
    water: {
      canPosition: { x: 1480, y: 430 },
      canTilt: 0,
      pouring: false,
      moisture: Array.from({ length: 40 }, () => 0),
      puddleExposure: 0,
    },
    statusMessage: 'Dig evenly around the marked center.',
    result: null,
  }
}

function nextStep(state: GameState): GameState {
  const currentIndex = STEPS.indexOf(state.step)
  const next = STEPS[currentIndex + 1]
  if (!next) return state
  const messages: Record<(typeof STEPS)[number], string> = {
    prepare: 'Dig evenly around the marked center.',
    place: 'Set the seedling upright and relax its roots.',
    cover: 'Draw loose soil from both sides. Press gently.',
    water: 'Move the can while pouring for even moisture.',
  }
  return {
    ...state,
    step: next,
    completedSteps: state.completedSteps.includes(state.step)
      ? state.completedSteps
      : [...state.completedSteps, state.step],
    statusMessage: messages[next],
    pointer: { ...state.pointer, active: false },
  }
}

function applyPrepareStroke(state: GameState, point: Point, pressure: number): GameState {
  const radius = distance(point, PREPARE_CENTER)
  const inWorkZone = radius <= PREPARE_ACTIVE_RADIUS && radius >= 32
  if (!inWorkZone) {
    return {
      ...state,
      prepare: {
        ...state.prepare,
        overdig: clamp(state.prepare.overdig + 0.012),
        strokes: state.prepare.strokes + 1,
      },
      statusMessage: 'Keep the shovel inside the circular work area.',
    }
  }
  const sectors = [...state.prepare.sectors]
  sectors[radialSector(point)] = true
  const sectorCoverage = sectors.filter(Boolean).length / sectors.length
  const increment = 0.013 + pressure * 0.009
  const nextDepth = state.prepare.depthProgress + increment
  return {
    ...state,
    prepare: {
      sectors,
      strokes: state.prepare.strokes + 1,
      depthProgress: clamp(nextDepth, 0, 1.2),
      overdig:
        nextDepth > 0.86
          ? clamp(state.prepare.overdig + (nextDepth - 0.86) * 0.035)
          : state.prepare.overdig,
    },
    statusMessage:
      sectorCoverage >= 0.7
        ? 'The hole is taking shape. Keep the depth controlled.'
        : 'Work around the full circle, not just one side.',
  }
}

export function gameReducer(state: GameState, action: GameAction): GameState {
  switch (action.type) {
    case 'OPEN': {
      const fresh = createInitialState(action.sessionId, state.helpMode)
      return { ...fresh, ...action.restore, sessionId: action.sessionId, visible: true }
    }
    case 'CLOSE':
      return { ...state, visible: false, water: { ...state.water, pouring: false } }
    case 'SET_HELP':
      return { ...state, helpMode: action.mode }
    case 'POINTER':
      return { ...state, pointer: action.frame }
    case 'PREPARE_STROKE':
      return applyPrepareStroke(state, action.point, action.pressure)
    case 'PLACE_PICKUP':
      return {
        ...state,
        place: { ...state.place, dragging: true },
        statusMessage: 'Lower the root ball into the center of the hole.',
      }
    case 'PLACE_MOVE':
      return {
        ...state,
        place: {
          ...state.place,
          position: action.point,
          tilt: clamp(action.tilt, -32, 32),
        },
      }
    case 'PLACE_DROP': {
      const dropDistance = distance(action.point, PLACE_TARGET)
      return {
        ...state,
        place: {
          ...state.place,
          position: action.point,
          dragging: false,
          placed: dropDistance <= PLACE_TARGET_RADIUS * 1.8,
          dropDistance,
        },
        statusMessage:
          dropDistance <= PLACE_TARGET_RADIUS
            ? 'Good placement. Relax the roots before covering.'
            : 'The seedling is off center. Reposition it gently.',
      }
    }
    case 'RELAX_ROOTS':
      return {
        ...state,
        place: {
          ...state.place,
          rootRelaxation: clamp(state.place.rootRelaxation + 0.34),
        },
        statusMessage: 'Roots loosened. Keep the stem upright.',
      }
    case 'COVER_PICKUP':
      return {
        ...state,
        cover: {
          ...state.cover,
          draggingFrom: action.side,
          dragPosition: action.point,
        },
      }
    case 'COVER_MOVE':
      return {
        ...state,
        cover: { ...state.cover, dragPosition: action.point },
      }
    case 'COVER_DROP': {
      const inside = distance(action.point, COVER_TARGET) <= COVER_TARGET_RADIUS
      const side = state.cover.draggingFrom
      const contribution = inside ? 0.28 : 0.06
      return {
        ...state,
        cover: {
          ...state.cover,
          leftContribution:
            side === 'left'
              ? clamp(state.cover.leftContribution + contribution)
              : state.cover.leftContribution,
          rightContribution:
            side === 'right'
              ? clamp(state.cover.rightContribution + contribution)
              : state.cover.rightContribution,
          draggingFrom: null,
          dragPosition: null,
        },
        statusMessage: inside
          ? 'Loose soil settled around the root ball.'
          : 'Some soil missed the planting area.',
      }
    }
    case 'COVER_PRESS': {
      const inside = distance(action.point, COVER_TARGET) <= COVER_TARGET_RADIUS
      return {
        ...state,
        cover: {
          ...state.cover,
          presses: state.cover.presses + 1,
          compaction: clamp(state.cover.compaction + (inside ? 0.16 : 0.04)),
        },
        statusMessage:
          state.cover.compaction > 0.62
            ? 'That is firm enough. Avoid packing the soil tighter.'
            : 'Press lightly to remove large air pockets.',
      }
    }
    case 'WATER_MOVE':
      return {
        ...state,
        water: {
          ...state.water,
          canPosition: action.point,
          canTilt: clamp(action.tilt, -50, 50),
        },
      }
    case 'WATER_POUR':
      return {
        ...state,
        water: { ...state.water, pouring: action.active },
        statusMessage: action.active
          ? 'Sweep slowly across the root zone.'
          : 'Pour paused. Check for dry patches.',
      }
    case 'WATER_TICK': {
      const moisture = state.water.moisture.map((value) =>
        clamp(value - 0.008 * action.dt, 0, 1.4),
      )
      const cell = waterCellIndex(action.point)
      let puddleExposure = state.water.puddleExposure
      if (cell !== null) {
        moisture[cell] = clamp(moisture[cell] + 0.9 * action.dt, 0, 1.4)
        const left = cell % 8 > 0 ? cell - 1 : null
        const right = cell % 8 < 7 ? cell + 1 : null
        for (const neighbor of [left, right]) {
          if (neighbor !== null) {
            moisture[neighbor] = clamp(moisture[neighbor] + 0.16 * action.dt, 0, 1.4)
          }
        }
        if (moisture[cell] > 1.15) puddleExposure += action.dt
      }
      return {
        ...state,
        water: { ...state.water, moisture, puddleExposure },
      }
    }
    case 'ADVANCE':
      return nextStep(state)
    case 'SET_RESULT':
      return {
        ...state,
        completedSteps: STEPS.slice(),
        result: action.result,
        statusMessage: 'Planting complete.',
      }
    case 'MESSAGE':
      return { ...state, statusMessage: action.message }
  }
}
