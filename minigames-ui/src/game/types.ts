export const STEPS = ['prepare', 'place', 'cover', 'water'] as const

export type Step = (typeof STEPS)[number]
export type HelpMode = 'full' | 'minimal'
export type MetricLabel = 'excellent' | 'good' | 'needs-attention'
export type SessionOutcome = 'completed' | 'cancelled' | 'failed'

export interface Point {
  x: number
  y: number
}

export interface PointerFrame extends Point {
  active: boolean
  tilt: number
  pressure: number
  keyboard: boolean
  error: boolean
}

export interface PrepareState {
  depthProgress: number
  sectors: boolean[]
  overdig: number
  strokes: number
}

export interface PlaceState {
  position: Point
  dragging: boolean
  placed: boolean
  tilt: number
  dropDistance: number
  rootRelaxation: number
}

export interface CoverState {
  leftContribution: number
  rightContribution: number
  compaction: number
  draggingFrom: 'left' | 'right' | null
  dragPosition: Point | null
  presses: number
}

export interface WaterState {
  canPosition: Point
  canTilt: number
  pouring: boolean
  moisture: number[]
  puddleExposure: number
}

export interface GameMetrics {
  depth: number
  alignment: number
  aeration: number
  hydration: number
}

export interface GameState {
  sessionId: string
  visible: boolean
  step: Step
  completedSteps: Step[]
  helpMode: HelpMode
  pointer: PointerFrame
  prepare: PrepareState
  place: PlaceState
  cover: CoverState
  water: WaterState
  statusMessage: string
  result: Record<keyof GameMetrics, MetricLabel> | null
}

export type GameAction =
  | { type: 'OPEN'; sessionId: string; restore?: Partial<GameState> }
  | { type: 'CLOSE' }
  | { type: 'SET_HELP'; mode: HelpMode }
  | { type: 'POINTER'; frame: PointerFrame }
  | { type: 'PREPARE_STROKE'; point: Point; pressure: number }
  | { type: 'PLACE_PICKUP' }
  | { type: 'PLACE_MOVE'; point: Point; tilt: number }
  | { type: 'PLACE_DROP'; point: Point }
  | { type: 'RELAX_ROOTS' }
  | { type: 'COVER_PICKUP'; side: 'left' | 'right'; point: Point }
  | { type: 'COVER_MOVE'; point: Point }
  | { type: 'COVER_DROP'; point: Point }
  | { type: 'COVER_PRESS'; point: Point }
  | { type: 'WATER_MOVE'; point: Point; tilt: number }
  | { type: 'WATER_POUR'; active: boolean }
  | { type: 'WATER_TICK'; dt: number; point: Point }
  | { type: 'ADVANCE' }
  | { type: 'SET_RESULT'; result: Record<keyof GameMetrics, MetricLabel> }
  | { type: 'MESSAGE'; message: string }

export interface TraceSample {
  elapsed50ms: number
  x: number
  y: number
  flags: number
  tilt: number
  pressure: number
}

export type EncodedTraceSample = [
  elapsed50ms: number,
  x: number,
  y: number,
  flags: number,
  tilt: number,
  pressure: number,
]

export interface StepSignals {
  [key: string]: number
}

export interface StepCheckpoint {
  contractVersion: '1.0.0'
  sessionId: string
  step: Step
  trace: EncodedTraceSample[]
  signals: StepSignals
}

export interface NuiOpenPayload {
  sessionId?: string
  nextStep?: Step
  completed?: Partial<Record<Step, unknown>>
  contract?: {
    contractVersion?: string
    minimumStepDurationMs?: Partial<Record<Step, number>>
  }
  restore?: Partial<GameState>
}

export type NuiInboundMessage =
  | { type: 'tomatoPlant:open'; payload?: NuiOpenPayload }
  | { type: 'tomatoPlant:restore'; payload: NuiOpenPayload }
  | { type: 'tomatoPlant:close' }
