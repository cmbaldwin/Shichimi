import { Controller } from "@hotwired/stimulus"
import { Mannequin } from "mannequin"

// <canvas data-controller="figure" data-figure-motion-value="<json>"> : the one live 3D figure on a page
export default class extends Controller {
  static values = { motion: Object, mirrored: Boolean }

  connect() {
    this.figure = new Mannequin(this.element, { motion: this.motionValue, mirrored: this.mirroredValue })
  }

  disconnect() { this.figure?.dispose(); this.figure = null }

  motionValueChanged() { this.figure?.setMotion(this.motionValue, { mirrored: this.mirroredValue }) }
  mirroredValueChanged() { this.motionValueChanged() }
}
