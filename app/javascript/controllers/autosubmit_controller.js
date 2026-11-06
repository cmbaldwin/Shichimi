import { Controller } from "@hotwired/stimulus"

// Auto-submits the form on change; text inputs are debounced.
export default class extends Controller {
  submit() { this.element.requestSubmit() }
  debounced() { clearTimeout(this.t); this.t = setTimeout(() => this.submit(), 300) }
  disconnect() { clearTimeout(this.t) }
}
