// STUB — replaced by the 3D rig pass. Keep this exported API stable (see AGENTS.md "Mannequin API").
import * as THREE from "three"

export class Mannequin {
  constructor(canvas, { motion = null, mirrored = false, autoplay = true, interactive = true } = {}) {
    this.canvas = canvas
    this.setMotion(motion, { mirrored })
  }
  setMotion(motion, { mirrored = false } = {}) { this.motion = motion; this.mirrored = mirrored }
  play() {}
  pause() {}
  setSpeed(_x) {}
  dispose() {}
}

export function renderThumbnail(_motion, { key = 0, width = 240, height = 240, mirrored = false } = {}) {
  const c = document.createElement("canvas"); c.width = width; c.height = height
  return c.toDataURL()
}
export { THREE }
