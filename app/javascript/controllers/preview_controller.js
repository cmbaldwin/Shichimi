import { Controller } from "@hotwired/stimulus"
import { Mannequin } from "mannequin"

// One live figure on the workout overview; tapping a list row swaps its motion.
export default class extends Controller {
  static targets = ["canvas", "name"]
  static values = { motions: Object, slug: String }

  connect() {
    this.mannequin = new Mannequin(this.canvasTarget, { motion: this.motionsValue[this.slugValue], autoplay: true, interactive: true })
    this.mark(this.slugValue)
  }

  disconnect() { this.mannequin?.dispose() }

  show({ params: { slug } }) {
    this.mannequin.setMotion(this.motionsValue[slug])
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
