import { Controller } from "@hotwired/stimulus"
import { StageFigure } from "stage_figure"

// One figure (video loop, or live 3D fallback) on the workout overview; tapping a list row swaps it.
export default class extends Controller {
  static targets = ["video", "canvas", "name"]
  static values = { motions: Object, slug: String }

  connect() {
    this.figure = new StageFigure(this.videoTarget, this.canvasTarget, { interactive: true })
    this.figure.show(this.motionsValue[this.slugValue])
    this.mark(this.slugValue)
  }

  disconnect() { this.figure?.dispose() }

  show({ params: { slug } }) {
    this.figure.show(this.motionsValue[slug])
    this.mark(slug)
  }

  mark(slug) {
    this.element.querySelectorAll(".wo-ex").forEach(b => {
      const on = b.dataset.slug === slug
      b.classList.toggle("on", on)
      if (on) this.nameTarget.textContent = b.dataset.name
    })
  }
}
