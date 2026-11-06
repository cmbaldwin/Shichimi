import { Controller } from "@hotwired/stimulus"

// Web Push toggle. States: unsupported | ios (needs Add to Home Screen) | denied | off | on.
export default class extends Controller {
  static targets = ["unsupported", "ios", "denied", "off", "on", "message"]
  static values = { key: String, url: String, testUrl: String }

  connect() { this.refresh() }

  async refresh() {
    let state
    if (!("serviceWorker" in navigator && "PushManager" in window && "Notification" in window)) {
      state = /iPad|iPhone|iPod/.test(navigator.userAgent) ? "ios" : "unsupported"
    } else if (Notification.permission === "denied") {
      state = "denied"
    } else {
      const sub = await this.subscription()
      state = sub && Notification.permission === "granted" ? "on" : "off"
    }
    for (const s of ["unsupported", "ios", "denied", "off", "on"]) this[`${s}Target`].hidden = s !== state
  }

  async subscription() {
    const reg = await this.registration()
    return reg.pushManager.getSubscription()
  }

  async registration() {
    return (await navigator.serviceWorker.getRegistration()) || navigator.serviceWorker.register("/service-worker")
      .then(() => navigator.serviceWorker.ready)
  }

  async subscribe() {
    this.say("")
    if (await Notification.requestPermission() !== "granted") return this.refresh()
    try {
      const reg = await this.registration()
      const sub = (await reg.pushManager.getSubscription()) || await reg.pushManager.subscribe({
        userVisibleOnly: true, applicationServerKey: this.keyBytes()
      })
      const res = await this.send("POST", this.urlValue, { subscription: sub.toJSON() })
      if (!res.ok) throw new Error(res.status)
    } catch (e) {
      this.say("Couldn't turn on notifications. Try again.")
    }
    this.refresh()
  }

  async unsubscribe() {
    const sub = await this.subscription()
    if (sub) {
      await this.send("DELETE", this.urlValue, { endpoint: sub.endpoint })
      await sub.unsubscribe()
    }
    this.refresh()
  }

  async test() {
    const res = await this.send("POST", this.testUrlValue)
    this.say(res.ok && (await res.json()).sent > 0 ? "Sent. It should arrive in a moment." : "Nothing was sent. Try turning notifications off and on again.")
  }

  send(method, url, body) {
    return fetch(url, {
      method,
      headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
      body: body && JSON.stringify(body)
    })
  }

  say(text) { this.messageTarget.textContent = text }

  keyBytes() {
    const b64 = (this.keyValue + "=".repeat((4 - this.keyValue.length % 4) % 4)).replace(/-/g, "+").replace(/_/g, "/")
    return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
  }
}
