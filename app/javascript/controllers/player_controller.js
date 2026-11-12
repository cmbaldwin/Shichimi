import { Controller } from "@hotwired/stimulus"
import { StageFigure } from "stage_figure"

const mmss = s => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`

export default class extends Controller {
  static targets = ["video", "canvas", "form", "slugs", "duration", "startedAt", "station", "kind", "name", "count", "ring", "next", "bar", "elapsed", "remaining", "toggle", "ready", "muted"]
  static values = { timeline: Array, exercises: Object, voice: String, name: String, autostart: Boolean, seek: Number }

  connect() {
    const steps = this.timelineValue
    let t = 0
    this.steps = steps.map(s => ({ ...s, start: t * 1000, end: (t += s.seconds) * 1000 }))
    this.total = t * 1000
    this.stations = steps.filter(s => s.kind === "work").length
    this.rounds = Math.max(...steps.map(s => s.round))
    this.perRound = this.stations / this.rounds
    this.idx = -1
    this.elapsed = 0
    this.running = false
    this.started = false
    this.done = new Set()
    this.said = new Set()
    this.figure = new StageFigure(this.videoTarget, this.canvasTarget)
    this.keys = e => this.onKey(e)
    this.vis = () => this.onVisibility()
    document.addEventListener("keydown", this.keys)
    document.addEventListener("visibilitychange", this.vis)
    this.enter(0, { silent: true })
    this.preload()
    if (this.autostartValue) this.start()
  }

  disconnect() {
    clearInterval(this.timer)
    document.removeEventListener("keydown", this.keys)
    document.removeEventListener("visibilitychange", this.vis)
    this.releaseWake()
    // After a finished workout the chime and "Done" ring out across the Turbo visit to the summary.
    const audio = this.audio
    if (this.finished && !this.early) setTimeout(() => audio?.close().catch(() => {}), 4000)
    else { this.hush(); audio?.close().catch(() => {}) }
    this.figure?.dispose()
  }

  // --- controls ---------------------------------------------------------
  start() {
    this.startedAt = new Date()
    this.started = true
    this.unlockAudio() // must run inside the tap
    this.readyTarget.hidden = true
    if (this.seekValue > 0) this.elapsed = Math.min(this.seekValue * 1000, this.total - 1)
    this.idx = -1
    this.resume()
    this.tick(true)
  }

  toggle() { this.running ? this.pause() : this.resume() }

  pause() {
    this.running = false
    clearInterval(this.timer)
    this.figure.pause()
    this.releaseWake()
    this.toggleTarget.textContent = "Resume"
    this.kindTarget.textContent = "PAUSED"
    this.hush()
  }

  resume() {
    if (!this.started) return
    this.running = true
    this.last = performance.now()
    clearInterval(this.timer)
    this.timer = setInterval(() => this.tick(), 100)
    this.wakeAudio() // Resume is a tap too: revive a context iOS interrupted
    this.figure.play()
    this.acquireWake()
    this.toggleTarget.textContent = "Pause"
    if (this.idx >= 0) this.kindTarget.textContent = this.constructor.KINDS[this.steps[this.idx].kind]
  }

  skip() { this.jump(this.idx + 1) }
  back() {
    // restart the current step if more than 2s in, otherwise go to the previous one
    const s = this.steps[this.idx]
    this.jump(this.elapsed - s.start > 2000 ? this.idx : this.idx - 1)
  }

  jump(i) {
    if (!this.started) return
    if (i >= this.steps.length) return this.finish()
    i = Math.max(0, i)
    this.elapsed = this.steps[i].start
    this.steps.forEach((s, n) => { if (n >= i) this.done.delete(n) })
    this.last = performance.now()
    this.idx = -1 // force re-entry
    this.tick(true)
  }

  end() {
    if (!this.started) return
    this.pause()
    if (this.done.size === 0) { window.Turbo.visit(location.pathname.replace(/\/play$/, "")); return }
    this.finish({ early: true })
  }

  onKey(e) {
    if (e.target.closest("input, textarea")) return
    if (e.code === "Space") { e.preventDefault(); this.started ? this.toggle() : this.start() }
    else if (e.code === "ArrowRight") this.skip()
    else if (e.code === "ArrowLeft") this.back()
  }

  // --- clock ------------------------------------------------------------
  tick(force = false) {
    if (this.running) {
      const now = performance.now()
      this.elapsed += now - this.last
      this.last = now
    }
    if (this.elapsed >= this.total) return this.finish({ natural: true })
    const i = this.steps.findIndex(s => this.elapsed < s.end)
    if (i !== this.idx) {
      // natural advance: mark finished work steps
      if (this.idx >= 0 && !force) for (let n = this.idx; n < i; n++) if (this.steps[n].kind === "work") this.done.add(n)
      this.enter(i)
    }
    this.cues()
    this.render()
  }

  enter(i, { silent = false } = {}) {
    this.idx = i
    const s = this.steps[i]
    const ex = this.exercises(s.slug)
    this.sideDone = false
    this.lastBeep = null
    this.element.dataset.category = ex.category
    this.element.dataset.kind = s.kind
    this.figure.setSpeed(s.kind === "work" ? 1 : 0.35)
    this.figure.show(ex, { mirrored: false })
    this.kindTarget.textContent = this.constructor.KINDS[s.kind]
    this.nameTarget.textContent = ex.name
    const nx = this.steps.find((x, j) => j > (s.kind === "work" ? i : i + 1) && x.kind === "work")
    this.nextTarget.textContent = nx ? this.exercises(nx.slug).name : "Finish"
    const n = this.steps.slice(0, i + 1).filter(x => x.kind === "work").length
    const upcoming = s.kind === "work" ? n : n + 1
    this.stationTarget.textContent = `${Math.min(upcoming, this.stations)} of ${this.stations}` + (this.rounds > 1 ? ` · round ${s.round}/${this.rounds}` : "")
    if (silent || !this.started) return
    this.wakeAudio()
    // the chime first, the voice just after it (never on top of each other)
    if (s.kind === "work") {
      this.sfx("go")
      if (this.stepIsLast(i)) this.say(["last_one"], "Last one", 0.5)
    } else if (s.kind === "rest") {
      this.sfx("rest")
      this.say(["rest", "next", s.slug], `Rest. Next: ${ex.name}`, 0.45)
    } else this.say(["get_ready", s.slug], `Get ready: ${ex.name}`)
  }

  static KINDS = { prep: "GET READY", work: "WORK", rest: "REST" }

  stepIsLast(i) { return this.steps.findLastIndex(x => x.kind === "work") === i }

  cues() {
    const s = this.steps[this.idx]
    const inStep = this.elapsed - s.start
    const left = Math.ceil((s.end - this.elapsed) / 1000)
    // dink-dink-dink on the last 3 seconds of every step (work and rest)
    if (left <= 3 && left >= 1 && this.lastBeep !== left && s.end - s.start > 4000) {
      this.lastBeep = left
      this.sfx("tick")
    }
    if (s.kind === "work" && s.switch_at && !this.sideDone && inStep >= s.switch_at * 1000) {
      this.sideDone = true
      this.figure.show(this.exercises(s.slug), { mirrored: true })
      this.sfx("switch")
      this.say(["switch_sides"], "Switch sides", 0.4)
    }
    if (s.kind === "work" && inStep > 5000 && this.elapsed >= this.total / 2 && !this.said.has("half")) {
      this.said.add("half")
      this.sfx("half")
      this.say(["halfway"], "Halfway", 0.5)
    }
  }

  render() {
    const s = this.steps[this.idx]
    const left = Math.max(0, Math.ceil((s.end - this.elapsed) / 1000))
    const frac = (this.elapsed - s.start) / (s.end - s.start)
    this.countTarget.textContent = left
    this.ringTarget.style.strokeDashoffset = Math.min(1, Math.max(0, frac))
    this.barTarget.style.width = `${(this.elapsed / this.total) * 100}%`
    this.elapsedTarget.textContent = mmss(this.elapsed / 1000)
    this.remainingTarget.textContent = `-${mmss(Math.ceil((this.total - this.elapsed) / 1000))}`
  }

  finish({ early = false, natural = false } = {}) {
    if (this.finished) return
    this.finished = true
    this.early = early
    clearInterval(this.timer)
    this.releaseWake()
    if (natural && this.steps[this.idx]?.kind === "work") this.done.add(this.idx)
    if (!early) { this.sfx("done"); this.say(["done"], "Done", 0.9) }
    const slugs = [...this.done].sort((a, b) => a - b).map(n => this.steps[n].slug)
    this.slugsTarget.replaceChildren(...slugs.map(v => {
      const el = document.createElement("input")
      el.type = "hidden"; el.name = "completed_slugs[]"; el.value = v
      return el
    }))
    this.durationTarget.value = Math.round(Math.min(this.elapsed, this.total) / 1000)
    this.startedAtTarget.value = this.startedAt.toISOString()
    this.formTarget.requestSubmit()
  }

  // --- helpers ----------------------------------------------------------
  exercises(slug) { return this.exercisesValue[slug] }

  // Voice clips (public/audio/voice, see script/voices). The bytes download while the Start screen is up and
  // are decoded inside the Start tap, so the very first cue already speaks in the chosen voice.
  preload() {
    this.bytes = {}
    if (this.voiceValue === "off") return
    const keys = ["get_ready", "rest", "next", "last_one", "switch_sides", "halfway", "done", ...new Set(this.steps.map(s => s.slug))]
    this.fetched = Promise.all(keys.map(k => fetch(`/audio/voice/${this.voiceValue}/${k}.m4a`)
      .then(r => r.ok ? r.arrayBuffer() : Promise.reject(r.status))
      .then(b => { this.bytes[k] = b })
      .catch(() => {})))
  }

  unlockAudio() {
    try {
      // iOS binds the session category when the context is created, so set "playback" (play through the
      // ring/silent switch) BEFORE new AudioContext; set afterwards, Web Audio stays muted on silent.
      if (navigator.audioSession) navigator.audioSession.type = "playback"
      const a = this.audio = new (window.AudioContext || window.webkitAudioContext)()
      // Everything plays through one limiter, so a chime under the voice never clips.
      this.out = a.createDynamicsCompressor()
      this.out.threshold.value = -6; this.out.knee.value = 6; this.out.ratio.value = 12
      this.out.attack.value = 0.003; this.out.release.value = 0.1
      this.out.connect(a.destination)
      a.onstatechange = () => this.soundState()
      a.resume().catch(() => {})
      this.bell(440, 0.03, 0.001) // silent-ish blip to fully unlock iOS
      this.clips = {}
      this.decoded = (this.fetched || Promise.resolve()).then(() => Promise.all(Object.entries(this.bytes).map(([k, b]) =>
        a.decodeAudioData(b).then(buf => { this.clips[k] = buf }).catch(() => {}))))
    } catch { /* no audio */ }
  }

  playClip(buf, at = 0, gain = 0.9) {
    const src = this.audio.createBufferSource(), g = this.audio.createGain()
    src.buffer = buf
    g.gain.value = gain
    src.connect(g).connect(this.out)
    src.start(this.audio.currentTime + at)
    return src
  }

  // Cue palette, synthesized (no files to load, so a cue can never go missing): [frequency Hz, delay s, decay s] per note.
  static SFX = {
    tick:   [[1568, 0, 0.32]],                                   // dink (G6)
    go:     [[2093, 0, 0.8], [1047, 0, 0.8]],                    // bright C7 + C6 on GO
    rest:   [[1319, 0, 0.4], [988, 0.15, 0.6]],                  // falling E6-B5
    switch: [[1568, 0, 0.2], [1568, 0.13, 0.35]],                // double dink
    half:   [[1175, 0, 0.3], [1568, 0.13, 0.5]],                 // rising D6-G6
    done:   [[1047, 0, 0.4], [1319, 0.13, 0.4], [1568, 0.26, 0.4], [2093, 0.39, 1.4]] // C-E-G-C arpeggio
  }

  sfx(name) { for (const [f, at, d] of this.constructor.SFX[name]) this.bell(f, d, 0.34, at) }

  // Small bell: sine fundamental + a quieter inharmonic partial that dies sooner, fast attack, exponential decay.
  bell(freq, dur, gain = 0.34, at = 0) {
    const a = this.audio
    if (!a) return
    const t = a.currentTime + at
    for (const [mult, level, len] of [[1, 1, dur], [2.76, 0.3, dur * 0.45]]) {
      const o = a.createOscillator(), g = a.createGain()
      o.frequency.value = freq * mult
      g.gain.setValueAtTime(0.0001, t)
      g.gain.exponentialRampToValueAtTime(gain * level, t + 0.004)
      g.gain.exponentialRampToValueAtTime(0.001, t + len) // -50 dB: a tail you can hear, not a blip
      o.connect(g).connect(this.out)
      o.start(t)
      o.stop(t + len + 0.05)
    }
  }

  // Queue voice clips back to back ("Rest", "Next up:", "<exercise>"), `delay` s from now. Waits for the clips
  // to finish decoding; speechSynthesis only if one is really missing (or there is no Web Audio at all).
  say(keys, text, delay = 0.05) {
    if (this.voiceValue === "off") return
    this.hush()
    const speak = () => { if ("speechSynthesis" in window) speechSynthesis.speak(new SpeechSynthesisUtterance(text)) }
    if (!this.audio) return speak()
    const turn = this.turn
    this.decoded.then(() => {
      if (turn !== this.turn) return // a newer cue, or a pause, replaced this one
      const bufs = keys.map(k => this.clips[k])
      if (!bufs.every(Boolean)) return speak()
      let at = delay
      this.voices = bufs.map(b => { const src = this.playClip(b, at); at += b.duration + 0.08; return src })
    })
  }

  hush() {
    this.turn = (this.turn || 0) + 1
    for (const v of this.voices || []) try { v.stop() } catch { /* already done */ }
    this.voices = []
    if ("speechSynthesis" in window) speechSynthesis.cancel()
  }

  async acquireWake() {
    try { this.wake = await navigator.wakeLock?.request("screen") } catch { /* denied */ }
  }
  releaseWake() { this.wake?.release().catch(() => {}); this.wake = null }
  // iOS parks the context ("interrupted"/"suspended") after a screen lock, call, Siri or app switch, and may
  // ignore resume() outside a tap. So: retry on every step and on any tap in the player (click->player#wakeAudio),
  // and while it is down show the "Tap for sound" pill instead of running on in silence.
  wakeAudio() { if (this.audio && this.audio.state !== "running") this.audio.resume().catch(() => {}) }
  soundState() { this.mutedTarget.hidden = !this.audio || this.audio.state === "running" || this.finished }

  // Leaving the page (lock, call, app switch) pauses the workout: the clock must not run on unseen and unheard,
  // and the Resume tap is the user gesture iOS needs to bring the sound back.
  onVisibility() {
    if (document.visibilityState === "hidden") { if (this.running) this.pause() }
    else this.wakeAudio()
  }
}
