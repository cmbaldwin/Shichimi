import { Controller } from "@hotwired/stimulus"

// Shows "already installed" in standalone mode, and a one-tap Install button where the
// browser supports beforeinstallprompt (Chrome/Edge on Android and desktop).
export default class extends Controller {
  static targets = ["installed", "offer"]

  connect() {
    if (matchMedia("(display-mode: standalone)").matches || navigator.standalone) {
      this.installedTarget.hidden = false
      return
    }
    this.onPrompt = e => { e.preventDefault(); this.deferred = e; this.offerTarget.hidden = false }
    addEventListener("beforeinstallprompt", this.onPrompt)
  }

  disconnect() { removeEventListener("beforeinstallprompt", this.onPrompt) }

  async prompt() {
    if (!this.deferred) return
    this.deferred.prompt()
    await this.deferred.userChoice.catch(() => {})
    this.deferred = null
    this.offerTarget.hidden = true
  }
}
