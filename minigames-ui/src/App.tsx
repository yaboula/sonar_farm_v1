import {
  ArrowRightIcon,
  DropIcon,
  HandPalmIcon,
  PlantIcon,
  QuestionIcon,
  ShovelIcon,
  XIcon,
} from '@phosphor-icons/react'
import { useCallback, useEffect, useMemo, useReducer, useRef, useState } from 'react'
import { audioEngine } from './audio/audioEngine'
import { PlantingCanvas } from './canvas/PlantingCanvas'
import { PREPARE_CENTER } from './game/geometry'
import {
  calculateMetrics,
  canAdvance,
  qualitativeMetrics,
  signalsForStep,
} from './game/metrics'
import {
  createInitialState,
  gameReducer,
  persistHelpMode,
  readHelpMode,
} from './game/reducer'
import { TraceEncoder } from './game/trace'
import { STEPS, type PointerFrame, type Step, type StepCheckpoint } from './game/types'
import { nuiBridge } from './nui/bridge'

interface CheckpointData {
  nextStep?: Step
  outcomes?: Record<'depth' | 'alignment' | 'aeration' | 'hydration', string>
}

const STEP_COPY: Record<
  Step,
  { title: string; objective: string; fullHelp: string; minimalHelp: string }
> = {
  prepare: {
    title: 'Prepare the hole',
    objective: 'Dig a broad, even pocket for the root ball.',
    fullHelp: 'Drag the shovel in radial strokes around the yellow circle. Work all sides evenly.',
    minimalHelp: 'Drag in a circle · Arrow keys + Space',
  },
  place: {
    title: 'Place the seedling',
    objective: 'Lower it to the right depth and keep the stem upright.',
    fullHelp: 'Drag the seedling into the hole. Move slowly, correct tilt with Q / E, then relax the roots.',
    minimalHelp: 'Drag to center · Q / E tilt · R relax',
  },
  cover: {
    title: 'Cover the roots',
    objective: 'Bring loose soil from both sides without packing it tight.',
    fullHelp: 'Drag soil from left and right into the root zone. Press lightly a few times to settle it.',
    minimalHelp: 'Drag both sides · P to press',
  },
  water: {
    title: 'Water in',
    objective: 'Moisten the whole root zone without pooling.',
    fullHelp: 'Move the can across the marked bed while holding Pour or Space. Keep the stream moving.',
    minimalHelp: 'Move across bed · Hold Space to pour',
  },
}

const STEP_ICONS = {
  prepare: ShovelIcon,
  place: PlantIcon,
  cover: HandPalmIcon,
  water: DropIcon,
}

const STEP_CRITERIA: Record<Step, [string, string, string]> = {
  prepare: ['Wide enough', 'Even depth', 'Avoid overdigging'],
  place: ['Crown at soil level', 'Keep stem upright', 'Relax the roots'],
  cover: ['Roots fully covered', 'Fill both sides', 'Keep soil airy'],
  water: ['Even distribution', 'Allow absorption', 'Avoid puddles'],
}

const DEFAULT_MINIMUM_STEP_MS: Record<Step, number> = {
  prepare: 3000,
  place: 2500,
  cover: 3000,
  water: 5000,
}

function makeTraceEncoders(): Record<Step, TraceEncoder> {
  const now = performance.now()
  return {
    prepare: new TraceEncoder(now),
    place: new TraceEncoder(now),
    cover: new TraceEncoder(now),
    water: new TraceEncoder(now),
  }
}

function App() {
  const initialHelp = readHelpMode(window.localStorage)
  const [state, dispatch] = useReducer(
    gameReducer,
    createInitialState('browser-preview', initialHelp),
  )
  const stateRef = useRef(state)
  const tracesRef = useRef<Record<Step, TraceEncoder>>(makeTraceEncoders())
  const stepStartedAtRef = useRef(performance.now())
  const minimumStepMsRef = useRef<Record<Step, number>>(DEFAULT_MINIMUM_STEP_MS)
  const [submitting, setSubmitting] = useState(false)
  stateRef.current = state

  useEffect(() => {
    const unsubscribe = nuiBridge.subscribe((event) => {
      if (event.type === 'close') {
        dispatch({ type: 'CLOSE' })
        return
      }
      tracesRef.current = makeTraceEncoders()
      stepStartedAtRef.current = performance.now()
      minimumStepMsRef.current = {
        ...DEFAULT_MINIMUM_STEP_MS,
        ...event.payload.contract?.minimumStepDurationMs,
      }
      const completedSteps = STEPS.filter(
        (step) => event.payload.completed?.[step] !== undefined,
      )
      dispatch({
        type: 'OPEN',
        sessionId: event.payload.sessionId,
        restore:
          event.type === 'restore'
            ? {
                ...event.payload.restore,
                step: event.payload.nextStep ?? event.payload.restore?.step,
                completedSteps,
              }
            : undefined,
      })
      void nuiBridge.callback('tomatoPlant:ready', {
        contractVersion: '1.0.0',
        sessionId: event.payload.sessionId,
      })
    })
    const stop = nuiBridge.start()
    return () => {
      unsubscribe()
      stop()
    }
  }, [])

  useEffect(() => {
    persistHelpMode(state.helpMode, window.localStorage)
  }, [state.helpMode])

  useEffect(() => {
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key !== 'Escape' || !stateRef.current.visible) return
      event.preventDefault()
      const current = stateRef.current
      void nuiBridge
        .callback('tomatoPlant:cancel', {
          contractVersion: '1.0.0',
          sessionId: current.sessionId,
          step: current.step,
          reason: 'player-cancelled',
        })
        .then((result) => {
          if (!result.ok) {
            dispatch({ type: 'MESSAGE', message: 'Cancel callback failed; the panel was closed.' })
          }
        })
      audioEngine.stopAll()
      dispatch({ type: 'CLOSE' })
    }
    window.addEventListener('keydown', handleEscape)
    return () => window.removeEventListener('keydown', handleEscape)
  }, [])

  const recordTrace = useCallback((frame: PointerFrame, primaryAction = false) => {
    tracesRef.current[stateRef.current.step].record(performance.now(), frame, primaryAction)
  }, [])

  const sendCheckpoint = useCallback(async (step: Step) => {
    const current = stateRef.current
    tracesRef.current[step].record(performance.now(), current.pointer)
    const checkpoint: StepCheckpoint = {
      contractVersion: '1.0.0',
      sessionId: current.sessionId,
      step,
      trace: tracesRef.current[step].values(),
      signals: signalsForStep(current, step),
    }
    const result = await nuiBridge.callback<CheckpointData>(
      'tomatoPlant:checkpoint',
      checkpoint,
    )
    if (!result.ok) {
      dispatch({
        type: 'MESSAGE',
        message: result.reason
          ? `Checkpoint rejected: ${result.reason.replaceAll('_', ' ')}.`
          : 'Checkpoint delivery failed. Your local progress is preserved.',
      })
    }
    return result
  }, [])

  const completeStep = async () => {
    if (submitting) return
    const current = stateRef.current
    const elapsed = performance.now() - stepStartedAtRef.current
    const minimum = minimumStepMsRef.current[current.step]
    if (elapsed < minimum) {
      dispatch({
        type: 'MESSAGE',
        message: `Keep working for ${Math.ceil((minimum - elapsed) / 1000)} more second${minimum - elapsed > 1000 ? 's' : ''}.`,
      })
      return
    }
    setSubmitting(true)
    try {
      const checkpoint = await sendCheckpoint(current.step)
      if (!checkpoint.ok) return

      if (current.step !== 'water') {
        const next = STEPS[STEPS.indexOf(current.step) + 1]
        if (next) tracesRef.current[next] = new TraceEncoder(performance.now())
        stepStartedAtRef.current = performance.now()
        dispatch({ type: 'ADVANCE' })
        audioEngine.play('confirm')
        return
      }

      let result = qualitativeMetrics(calculateMetrics(current))
      if (nuiBridge.isFiveM) {
        const outcomes = checkpoint.data?.outcomes
        if (!checkpoint.complete || !outcomes) {
          dispatch({
            type: 'MESSAGE',
            message: 'The server did not confirm planting. Your progress is preserved.',
          })
          return
        }
        result = Object.fromEntries(
          Object.entries(outcomes).map(([metric, label]) => [
            metric,
            label === 'excellent' || label === 'good' ? label : 'needs-attention',
          ]),
        ) as typeof result
      }

      dispatch({ type: 'SET_RESULT', result })
      audioEngine.play('confirm')
    } finally {
      setSubmitting(false)
    }
  }

  const toggleHelp = () => {
    dispatch({
      type: 'SET_HELP',
      mode: state.helpMode === 'full' ? 'minimal' : 'full',
    })
  }

  const controlActions = useMemo(() => {
    switch (state.step) {
      case 'prepare':
        return (
          <button
            type="button"
            className="tool-action"
            onClick={() => {
              const angle = ((state.prepare.strokes % 12) + 0.5) / 12 * Math.PI * 2
              const point = {
                x: PREPARE_CENTER.x + Math.cos(angle) * 170,
                y: PREPARE_CENTER.y + Math.sin(angle) * 170,
              }
              dispatch({ type: 'PREPARE_STROKE', point, pressure: 0.72 })
              recordTrace(
                { ...state.pointer, ...point, active: true, keyboard: true, pressure: 0.72 },
                true,
              )
            }}
          >
            <ShovelIcon aria-hidden="true" />
            Dig stroke
          </button>
        )
      case 'place':
        return (
          <button
            type="button"
            className="tool-action"
            onClick={() => {
              dispatch({ type: 'RELAX_ROOTS' })
              recordTrace(
                {
                  ...state.pointer,
                  ...state.place.position,
                  active: true,
                  keyboard: true,
                },
                true,
              )
            }}
          >
            <PlantIcon aria-hidden="true" />
            Relax roots
          </button>
        )
      case 'cover':
        return (
          <>
            <button
              type="button"
              className="tool-action"
              onClick={() => {
                dispatch({ type: 'COVER_PICKUP', side: 'left', point: { x: 670, y: 680 } })
                dispatch({ type: 'COVER_DROP', point: { x: 1000, y: 686 } })
                recordTrace(
                  { ...state.pointer, x: 670, y: 680, active: true, keyboard: true },
                  true,
                )
              }}
            >
              Soil left
            </button>
            <button
              type="button"
              className="tool-action"
              onClick={() => {
                dispatch({ type: 'COVER_PICKUP', side: 'right', point: { x: 1350, y: 680 } })
                dispatch({ type: 'COVER_DROP', point: { x: 1048, y: 686 } })
                recordTrace(
                  { ...state.pointer, x: 1350, y: 680, active: true, keyboard: true },
                  true,
                )
              }}
            >
              Soil right
            </button>
            <button
              type="button"
              className="tool-action"
              onClick={() => {
                const point = { x: 1024, y: 686 }
                dispatch({ type: 'COVER_PRESS', point })
                recordTrace(
                  {
                    ...state.pointer,
                    ...point,
                    active: true,
                    keyboard: true,
                    pressure: 0.5,
                  },
                  true,
                )
              }}
            >
              <HandPalmIcon aria-hidden="true" />
              Press gently
            </button>
          </>
        )
      case 'water':
        return (
          <button
            type="button"
            className={`tool-action pour-action ${state.water.pouring ? 'is-active' : ''}`}
            aria-pressed={state.water.pouring}
            onPointerDown={() => dispatch({ type: 'WATER_POUR', active: true })}
            onPointerUp={() => dispatch({ type: 'WATER_POUR', active: false })}
            onPointerCancel={() => dispatch({ type: 'WATER_POUR', active: false })}
            onKeyDown={(event) => {
              if ((event.key === ' ' || event.key === 'Enter') && !event.repeat) {
                dispatch({ type: 'WATER_POUR', active: true })
              }
            }}
            onKeyUp={(event) => {
              if (event.key === ' ' || event.key === 'Enter') {
                dispatch({ type: 'WATER_POUR', active: false })
              }
            }}
          >
            <DropIcon weight="fill" aria-hidden="true" />
            Hold to pour
          </button>
        )
    }
  }, [
    recordTrace,
    state.pointer,
    state.place.position,
    state.prepare.strokes,
    state.step,
    state.water.pouring,
  ])

  if (!state.visible) return null

  const copy = STEP_COPY[state.step]
  const criteria = STEP_CRITERIA[state.step]
  const isResult = state.result !== null
  const completeIndex = isResult ? STEPS.length : STEPS.indexOf(state.step)

  return (
    <main className="world-stage">
      <div className="world-silhouette" aria-hidden="true">
        <span className="ridge ridge-a" />
        <span className="ridge ridge-b" />
        <span className="field-lines" />
      </div>

      <section
        className={`minigame-shell reference-shell ${isResult ? 'is-result' : ''}`}
        aria-label="Tomato initial planting minigame"
      >
        <div className="crop-identity">
          <span className="crop-mark">
            <PlantIcon weight="duotone" aria-hidden="true" />
          </span>
          <span>
            <strong>Tomato</strong>
            <small>Initial planting</small>
          </span>
        </div>

        <header className="game-header">
          <ol className="stepper" aria-label="Planting progress">
            {STEPS.map((step, index) => {
              const Icon = STEP_ICONS[step]
              const active = !isResult && step === state.step
              const complete = index < completeIndex || isResult
              return (
                <li
                  key={step}
                  className={`${active ? 'is-active' : ''} ${complete ? 'is-complete' : ''}`}
                  aria-current={active ? 'step' : undefined}
                >
                  <span className="step-icon">
                    {complete ? <span aria-hidden="true">✓</span> : <Icon aria-hidden="true" />}
                  </span>
                  <span>
                    <small>0{index + 1}</small>
                    {step}
                  </span>
                </li>
              )
            })}
          </ol>

          <div className="title-row">
            <div>
              <h1>{isResult ? 'Planting Complete' : copy.title}</h1>
              {isResult ? (
                <p className="completion-line">
                  <span aria-hidden="true">✓</span>
                  Tomato seedling established
                </p>
              ) : (
                <div className="criteria-row" aria-label="Step goals">
                  {criteria.map((criterion, index) => (
                    <span key={criterion} className={index === 0 ? 'is-current' : ''}>
                      <i aria-hidden="true" />
                      {criterion}
                    </span>
                  ))}
                </div>
              )}
            </div>
          </div>
        </header>

        <div className="header-actions">
          {!isResult && (
            <button
              type="button"
              className="icon-button"
              onClick={toggleHelp}
              aria-label={`Switch to ${state.helpMode === 'full' ? 'minimal' : 'full'} help`}
            >
              <QuestionIcon aria-hidden="true" />
            </button>
          )}
          <button
            type="button"
            className="icon-button"
            onClick={() => {
              window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
            }}
            aria-label="Cancel planting"
          >
            <XIcon aria-hidden="true" />
          </button>
        </div>

        {!isResult ? (
          <>
            <aside className="side-palette tool-palette" aria-label="Tools">
              <h2>Tools</h2>
              <div className="tool-visuals" aria-hidden="true">
                <span className={state.step === 'prepare' ? 'is-active' : ''}>
                  <img src="./assets/planting/tool_hand_shovel.png" alt="" />
                </span>
                <span className={state.step === 'place' || state.step === 'cover' ? 'is-active' : ''}>
                  <HandPalmIcon />
                </span>
              </div>
              <div className="tool-actions">{controlActions}</div>
            </aside>

            <aside className="side-palette material-palette" aria-label="Materials">
              <h2>Materials</h2>
              <div className="material-slots">
                <span
                  className={`${state.step === 'place' ? 'is-active' : ''} ${
                    STEPS.indexOf(state.step) > 1 ? 'is-complete' : ''
                  }`}
                >
                  <img src="./assets/planting/tomato_seedling_complete.png" alt="Tomato seedling" />
                </span>
                <span
                  className={`${state.step === 'cover' ? 'is-active' : ''} ${
                    state.step === 'water' ? 'is-complete' : ''
                  }`}
                >
                  <img src="./assets/planting/material_loose_soil_mound.png" alt="Loose soil" />
                </span>
                <span className={state.step === 'water' ? 'is-active' : ''}>
                  <img src="./assets/planting/tool_watering_can.png" alt="Watering can" />
                </span>
              </div>
            </aside>
          </>
        ) : (
          <>
            <aside className="result-rail result-placement" aria-label="Placement result">
              <h2>Placement</h2>
              {(['depth', 'alignment'] as const).map((metric) => (
                <div key={metric}>
                  <span aria-hidden="true">✓</span>
                  <small>{metric}</small>
                  <strong className={`result-${state.result?.[metric]}`}>
                    {state.result?.[metric].replace('-', ' ')}
                  </strong>
                </div>
              ))}
            </aside>
            <aside className="result-rail result-soil" aria-label="Soil condition result">
              <h2>Soil condition</h2>
              {(['aeration', 'hydration'] as const).map((metric) => (
                <div key={metric}>
                  <span aria-hidden="true">✓</span>
                  <small>{metric}</small>
                  <strong className={`result-${state.result?.[metric]}`}>
                    {state.result?.[metric].replace('-', ' ')}
                  </strong>
                </div>
              ))}
            </aside>
          </>
        )}

        <div className="canvas-frame">
          <PlantingCanvas state={state} dispatch={dispatch} onTrace={recordTrace} />
          {!isResult && (
            <div className={`help-card help-${state.helpMode}`}>
              <QuestionIcon aria-hidden="true" />
              <span>{state.helpMode === 'full' ? copy.fullHelp : copy.minimalHelp}</span>
            </div>
          )}
        </div>

        {isResult ? (
          <footer className="game-footer result-footer">
            <div>
              <strong>The seedling is established and ready to begin growth.</strong>
              <span>Initial conditions have been recorded.</span>
            </div>
            <button
              type="button"
              className="primary-button"
              onClick={() => {
                void nuiBridge
                  .callback('tomatoPlant:close', {
                    contractVersion: '1.0.0',
                    sessionId: state.sessionId,
                  })
                  .finally(() => dispatch({ type: 'CLOSE' }))
              }}
            >
              Continue
              <ArrowRightIcon aria-hidden="true" />
            </button>
          </footer>
        ) : (
          <footer className="game-footer">
            <div className="gesture-instruction">
              <span className="mouse-glyph" aria-hidden="true">◉</span>
              <div>
                <strong>
                  {state.helpMode === 'full' ? copy.fullHelp : copy.minimalHelp}
                </strong>
                <span role="status" aria-live="polite">{state.statusMessage}</span>
              </div>
            </div>
            <button
              type="button"
              className="primary-button"
              disabled={!canAdvance(state) || submitting}
              onClick={() => void completeStep()}
            >
              {state.step === 'water' ? 'Finish planting' : 'Confirm step'}
              <ArrowRightIcon aria-hidden="true" />
            </button>
          </footer>
        )}

        {!isResult && <div className="escape-hint"><kbd>ESC</kbd> Cancel</div>}
      </section>
    </main>
  )
}

export default App
