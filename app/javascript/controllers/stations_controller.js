import { Controller } from "@hotwired/stimulus"

// Ordered station list. Rows are plain <select name="workout[exercise_slugs][]">, so it submits without JS.
export default class extends Controller {
  static targets = ["list", "template", "count"]

  connect() { this.update() }
  add() { this.listTarget.append(this.templateTarget.content.cloneNode(true)); this.update() }
  remove({ target }) { target.closest("li").remove(); this.update() }
  up({ target }) { const li = target.closest("li"); li.previousElementSibling?.before(li); this.update() }
  down({ target }) { const li = target.closest("li"); li.nextElementSibling?.after(li); this.update() }
  update() {
    const rows = [...this.listTarget.children]
    rows.forEach((li, i) => (li.querySelector("[data-n]").textContent = i + 1))
    if (this.hasCountTarget) this.countTarget.textContent = rows.length
  }
}
