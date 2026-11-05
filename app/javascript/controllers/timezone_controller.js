import { Controller } from "@hotwired/stimulus"

// Fills a hidden time_zone field with the browser's IANA zone.
export default class extends Controller {
  connect() {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (tz) this.element.value = tz
  }
}
