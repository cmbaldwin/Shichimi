// Reveals the element on iOS/iPadOS only (Apple Health hand-off via Shortcuts).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const ua = navigator.userAgent
    if (/iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1)) this.element.hidden = false
  }
}
