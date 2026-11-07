import { Controller } from "@hotwired/stimulus"

// Plays the "Get ready" clip for the selected voice on the settings page.
export default class extends Controller {
  static targets = ["choice"]

  play() {
    const voice = this.choiceTargets.find(c => c.checked)?.value
    if (voice && voice !== "off") new Audio(`/audio/voice/${voice}/get_ready.m4a`).play().catch(() => {})
  }
}
