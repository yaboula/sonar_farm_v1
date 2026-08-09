type SoundName = 'dig' | 'soil' | 'roots' | 'water' | 'confirm'

export class AudioEngine {
  #context: AudioContext | null = null
  #gain: GainNode | null = null
  readonly #buffers = new Map<SoundName, AudioBuffer>()
  readonly #sources = new Set<AudioBufferSourceNode>()

  async register(name: SoundName, url?: string): Promise<boolean> {
    if (!url) return false
    try {
      const context = this.#ensureContext()
      if (!context) return false
      const response = await fetch(url)
      if (!response.ok) return false
      const buffer = await context.decodeAudioData(await response.arrayBuffer())
      this.#buffers.set(name, buffer)
      return true
    } catch {
      return false
    }
  }

  async unlock(): Promise<void> {
    try {
      const context = this.#ensureContext()
      if (context?.state === 'suspended') await context.resume()
    } catch {
      // NUI browser may expose WebAudio before its output device is ready.
    }
  }

  play(name: SoundName, volume = 0.5): void {
    const context = this.#ensureContext()
    const buffer = this.#buffers.get(name)
    if (!context || !this.#gain || !buffer) return
    try {
      const source = context.createBufferSource()
      const gain = context.createGain()
      gain.gain.value = Math.min(1, Math.max(0, volume))
      source.buffer = buffer
      source.connect(gain).connect(this.#gain)
      source.addEventListener('ended', () => this.#sources.delete(source), { once: true })
      this.#sources.add(source)
      source.start()
    } catch {
      // Missing/blocked audio is non-fatal by design.
    }
  }

  stopAll(): void {
    for (const source of this.#sources) {
      try {
        source.stop()
      } catch {
        // A source may already have ended.
      }
    }
    this.#sources.clear()
  }

  #ensureContext(): AudioContext | null {
    if (this.#context) return this.#context
    try {
      this.#context = new AudioContext()
      this.#gain = this.#context.createGain()
      this.#gain.gain.value = 0.72
      this.#gain.connect(this.#context.destination)
      return this.#context
    } catch {
      return null
    }
  }
}

export const audioEngine = new AudioEngine()
