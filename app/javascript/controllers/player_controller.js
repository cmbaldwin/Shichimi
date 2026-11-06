import { Controller } from "@hotwired/stimulus"
import { Mannequin } from "mannequin"

const mmss = s => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`

export default class extends Controller {
  static targets = ["canvas", "form", "slugs", "duration", "startedAt", "station", "kind", "name", "count", "ring", "next", "bar", "elapsed", "remaining", "toggle", "ready"]
  static values = { timeline: Array, exercises: Object, voice: Boolean, name: String, autostart: Boolean, seek: Number }

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
    this.mannequin = new Mannequin(this.canvasTarget, { motion: this.motionFor(this.steps[0].slug), autoplay: true, interactive: false })
    this.keys = e => this.onKey(e)
    this.vis = () => this.onVisibility()
    document.addEventListener("keydown", this.keys)
    document.addEventListener("visibilitychange", this.vis)
    this.enter(0, { silent: true })
    if (this.autostartValue) this.start()
  }

  disconnect() {
    clearInterval(this.timer)
    document.removeEventListener("keydown", this.keys)
    document.removeEventListener("visibilitychange", this.vis)
    this.releaseWake()
    speechSynthesis?.cancel()
    this.audio?.close().catch(() => {})
    this.mannequin?.dispose()
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
    this.mannequin.pause()
    this.releaseWake()
    this.toggleTarget.textContent = "Resume"
    speechSynthesis?.cancel()
  }

  resume() {
    if (!this.started) return
    this.running = true
    this.last = performance.now()
    clearInterval(this.timer)
    this.timer = setInterval(() => this.tick(), 100)
    this.mannequin.play()
    this.acquireWake()
    this.toggleTarget.textContent = "Pause"
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
    this.mannequin.setMotion(ex.motion, { mirrored: false })
    this.mannequin.setSpeed(s.kind === "work" ? 1 : 0.35)
    this.kindTarget.textContent = { prep: "GET READY", work: "WORK", rest: "REST" }[s.kind]
    this.nameTarget.textContent = ex.name
    const nx = this.steps.find((x, j) => j > (s.kind === "work" ? i : i + 1) && x.kind === "work")
    this.nextTarget.textContent = nx ? this.exercises(nx.slug).name : "Finish"
    const n = this.steps.slice(0, i + 1).filter(x => x.kind === "work").length
    const upcoming = s.kind === "work" ? n : n + 1
    this.stationTarget.textContent = `station ${Math.min(upcoming, this.stations)}/${this.stations} · round ${s.round}/${this.rounds}`
    if (silent || !this.started) return
    if (s.kind === "work") {
      this.sfx("go")
      if (this.stepIsLast(i)) this.say("Last one")
    } else {
      if (s.kind === "rest") this.sfx("rest")
      this.say(s.kind === "prep" ? `Get ready: ${ex.name}` : `Rest. Next: ${ex.name}`)
    }
  }

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
      this.mannequin.setMotion(this.exercises(s.slug).motion, { mirrored: true })
      this.sfx("switch")
      this.say("Switch sides")
    }
    if (s.kind === "work" && inStep > 5000 && this.elapsed >= this.total / 2 && !this.said.has("half")) {
      this.said.add("half")
      this.sfx("half")
      this.say("Halfway")
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
    clearInterval(this.timer)
    this.releaseWake()
    if (natural && this.steps[this.idx]?.kind === "work") this.done.add(this.idx)
    if (!early) { this.sfx("done"); this.say("Done") }
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
  motionFor(slug) { return this.exercises(slug).motion }

  unlockAudio() {
    try {
      this.audio = new (window.AudioContext || window.webkitAudioContext)()
      this.audio.resume().catch(() => {})
      this.bell(440, 0.03, 0.001) // silent-ish blip to fully unlock iOS
    } catch { /* no audio */ }
  }

  // Cue palette: [frequency Hz, delay s, decay s] per note. ponytail: synthesized, no audio files to ship.
  static SFX = {
    tick:   [[1568, 0, 0.18]],                                   // dink (G6)
    go:     [[2093, 0, 0.7], [1047, 0, 0.7]],                    // bright C7 + C6 on GO
    rest:   [[1319, 0, 0.35], [988, 0.14, 0.5]],                 // falling E6-B5
    switch: [[1568, 0, 0.2], [1568, 0.12, 0.3]],                 // double dink
    half:   [[1175, 0, 0.3], [1568, 0.12, 0.4]],                 // rising D6-G6
    done:   [[1047, 0, 0.4], [1319, 0.12, 0.4], [1568, 0.24, 0.4], [2093, 0.36, 1.2]] // C-E-G-C arpeggio
  }

  sfx(name) { for (const [f, at, d] of this.constructor.SFX[name]) this.bell(f, d, 0.22, at) }

  // Small bell: sine fundamental + inharmonic partial, fast attack, exponential decay.
  bell(freq, dur, gain = 0.22, at = 0) {
    const a = this.audio
    if (!a) return
    const t = a.currentTime + at
    const g = a.createGain()
    g.gain.setValueAtTime(0.0001, t)
    g.gain.exponentialRampToValueAtTime(gain, t + 0.004)
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur)
    g.connect(a.destination)
    for (const [mult, level] of [[1, 1], [2.76, 0.25]]) {
      const o = a.createOscillator(), og = a.createGain()
      o.frequency.value = freq * mult
      og.gain.value = level
      o.connect(og).connect(g)
      o.start(t)
      o.stop(t + dur + 0.05)
    }
  }

  say(text) {
    if (!this.voiceValue || !("speechSynthesis" in window)) return
    speechSynthesis.cancel()
    speechSynthesis.speak(new SpeechSynthesisUtterance(text))
  }

  async acquireWake() {
    try { this.wake = await navigator.wakeLock?.request("screen") } catch { /* denied */ }
  }
  releaseWake() { this.wake?.release().catch(() => {}); this.wake = null }
  onVisibility() { if (document.visibilityState === "visible" && this.running) this.acquireWake() }
}
