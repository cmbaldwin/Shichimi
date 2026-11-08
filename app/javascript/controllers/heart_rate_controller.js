import { Controller } from "@hotwired/stimulus"

// Live BPM from a Bluetooth HR strap (Web Bluetooth, GATT 0x180D / 0x2A37). Chromium on Android/desktop only:
// the whole UI stays hidden when navigator.bluetooth is missing (iOS). Sits on the same element as the player.
// Samples are kept only while the workout runs (ready overlay hidden); avg/max go into hidden form fields on every sample.
export default class extends Controller {
  static targets = ["ui", "bpm", "button", "avg", "max"]

  connect() {
    this.samples = []
    if (navigator.bluetooth) this.uiTarget.hidden = false
  }

  disconnect() { this.device?.gatt?.disconnect() }

  async connectStrap() {
    try {
      this.device ||= await navigator.bluetooth.requestDevice({ filters: [{ services: ["heart_rate"] }] })
      this.device.addEventListener("gattserverdisconnected", () => this.lost())
      const server = await this.device.gatt.connect()
      const chr = await (await server.getPrimaryService("heart_rate")).getCharacteristic("heart_rate_measurement")
      chr.addEventListener("characteristicvaluechanged", e => this.sample(e.target.value))
      await chr.startNotifications()
      this.buttonTarget.hidden = true
      this.bpmTarget.textContent = "…"
    } catch (e) {
      if (e.name !== "NotFoundError") this.lost() // NotFoundError = user dismissed the chooser
    }
  }

  sample(dv) {
    const bpm = dv.getUint8(0) & 1 ? dv.getUint16(1, true) : dv.getUint8(1)
    if (bpm < 30 || bpm > 240) return
    this.bpmTarget.textContent = bpm
    if (this.element.querySelector("[data-player-target=ready]")?.hidden) this.samples.push(bpm)
    if (!this.samples.length) return
    this.avgTarget.value = Math.round(this.samples.reduce((a, b) => a + b, 0) / this.samples.length)
    this.maxTarget.value = Math.max(...this.samples)
  }

  lost() {
    this.bpmTarget.textContent = "—"
    this.buttonTarget.textContent = "Reconnect"
    this.buttonTarget.hidden = false
  }
}
