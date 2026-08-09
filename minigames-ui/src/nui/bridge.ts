import type { NuiInboundMessage, NuiOpenPayload } from '../game/types'

declare global {
  interface Window {
    GetParentResourceName?: () => string
  }
}

export interface CallbackResult<T = unknown> {
  ok: boolean
  data?: T
  complete?: boolean
  reason?: string
  detail?: string
  error?: string
}

export type BridgeEvent =
  | { type: 'open'; payload: Required<Pick<NuiOpenPayload, 'sessionId'>> & NuiOpenPayload }
  | { type: 'restore'; payload: Required<Pick<NuiOpenPayload, 'sessionId'>> & NuiOpenPayload }
  | { type: 'close' }

type BridgeListener = (event: BridgeEvent) => void

function isInboundMessage(value: unknown): value is NuiInboundMessage {
  if (!value || typeof value !== 'object') return false
  const type = (value as { type?: unknown }).type
  return (
    type === 'tomatoPlant:open' ||
    type === 'tomatoPlant:restore' ||
    type === 'tomatoPlant:close'
  )
}

function safeSessionId(payload?: NuiOpenPayload): string {
  return payload?.sessionId?.slice(0, 128) || `session-${Date.now().toString(36)}`
}

export class NuiBridge {
  readonly #listeners = new Set<BridgeListener>()
  readonly #resourceName: string | null
  #started = false

  constructor() {
    try {
      this.#resourceName = window.GetParentResourceName?.() ?? window.parent?.GetParentResourceName?.() ?? null
    } catch {
      this.#resourceName = null
    }
  }

  get isFiveM(): boolean {
    return this.#resourceName !== null
  }

  start(): () => void {
    if (!this.#started) {
      window.addEventListener('message', this.#onMessage)
      this.#started = true
      if (!this.isFiveM) {
        queueMicrotask(() => {
          this.#emit({
            type: 'open',
            payload: { sessionId: 'browser-preview' },
          })
        })
      }
    }
    return () => this.stop()
  }

  stop(): void {
    if (!this.#started) return
    window.removeEventListener('message', this.#onMessage)
    this.#started = false
  }

  subscribe(listener: BridgeListener): () => void {
    this.#listeners.add(listener)
    return () => this.#listeners.delete(listener)
  }

  async callback<T = unknown>(
    callbackName: string,
    payload: unknown,
  ): Promise<CallbackResult<T>> {
    if (!this.#resourceName) {
      console.info(`[browser callback] ${callbackName}`, payload)
      return { ok: true }
    }

    const controller = new AbortController()
    const timeout = window.setTimeout(() => controller.abort(), 5000)
    try {
      const response = await fetch(`https://${this.#resourceName}/${callbackName}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
        signal: controller.signal,
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const text = await response.text()
      if (!text) return { ok: true }
      const parsed = JSON.parse(text) as unknown
      if (
        parsed &&
        typeof parsed === 'object' &&
        typeof (parsed as { ok?: unknown }).ok === 'boolean'
      ) {
        return parsed as CallbackResult<T>
      }
      return { ok: true, data: parsed as T }
    } catch (error) {
      const message = error instanceof Error ? error.message.slice(0, 256) : 'Unknown NUI error'
      if (callbackName !== 'tomatoPlant:error') {
        await this.#reportError(callbackName, message)
      }
      return { ok: false, error: message }
    } finally {
      window.clearTimeout(timeout)
    }
  }

  readonly #onMessage = (event: MessageEvent<unknown>): void => {
    if (!isInboundMessage(event.data)) return
    if (event.data.type === 'tomatoPlant:close') {
      this.#emit({ type: 'close' })
      return
    }
    const payload = event.data.payload
    const normalized = { ...payload, sessionId: safeSessionId(payload) }
    this.#emit({
      type: event.data.type === 'tomatoPlant:restore' ? 'restore' : 'open',
      payload: normalized,
    })
  }

  #emit(event: BridgeEvent): void {
    for (const listener of this.#listeners) listener(event)
  }

  async #reportError(callbackName: string, error: string): Promise<void> {
    try {
      await fetch(`https://${this.#resourceName}/tomatoPlant:error`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callbackName, error }),
      })
    } catch {
      console.error(`NUI callback failed: ${callbackName}: ${error}`)
    }
  }
}

export const nuiBridge = new NuiBridge()
