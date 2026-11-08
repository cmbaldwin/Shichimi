import { Mannequin } from "mannequin"

// The exercise figure for the player and workout preview: the pre-rendered video loop when the exercise
// has one (`ex.video`, from Exercise#to_player), else the live three.js Mannequin, created only if needed.
export class StageFigure {
  constructor(video, canvas, { interactive = false } = {}) {
    Object.assign(this, { video, canvas, interactive, speed: 1, playing: true })
  }

  show(ex, { mirrored = false } = {}) {
    const live = !ex.video
    this.video.hidden = live
    this.canvas.hidden = !live
    if (live) {
      this.video.pause()
      this.mannequin ??= new Mannequin(this.canvas, { motion: ex.motion, autoplay: this.playing, interactive: this.interactive })
      this.mannequin.setMotion(ex.motion, { mirrored })
      this.mannequin.setSpeed(this.speed)
    } else {
      this.mannequin?.pause()
      const src = `${ex.video}.mp4`
      if (!this.video.src.endsWith(src)) { this.video.src = src; this.video.poster = `${ex.video}.webp` }
      this.video.style.transform = mirrored ? "scaleX(-1)" : ""
      this.video.playbackRate = this.speed
      if (this.playing) this.video.play().catch(() => {}) // autoplay of muted video can still be refused; poster shows
    }
    this.live = live
  }

  setSpeed(s) { this.speed = s; this.video.playbackRate = s; this.mannequin?.setSpeed(s) }
  play() { this.playing = true; this.live ? this.mannequin?.play() : this.video.play().catch(() => {}) }
  pause() { this.playing = false; this.video.pause(); this.mannequin?.pause() }
  dispose() { this.video.removeAttribute("src"); this.mannequin?.dispose() }
}
