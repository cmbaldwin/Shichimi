import { Controller } from "@hotwired/stimulus"
import { renderThumbnail } from "mannequin"

// <img data-controller="thumb" data-thumb-motion-value="<json>" data-thumb-key-value="0">
// Rendered by the shared offscreen renderer, one per tick so long lists don't block the page.
let queue = Promise.resolve()

export default class extends Controller {
  static values = { motion: Object, key: Number, mirrored: Boolean, size: { type: Number, default: 240 } }

  connect() {
    queue = queue.then(() => new Promise((done) => setTimeout(() => {
      if (this.element.isConnected) {
        const size = this.sizeValue
        this.element.src = renderThumbnail(this.motionValue, { key: this.keyValue, width: size, height: size, mirrored: this.mirroredValue })
      }
      done()
    })))
  }
}
