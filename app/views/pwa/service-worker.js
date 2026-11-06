// Minimal service worker: Web Push only. No offline caching or fetch handler (skipped on
// purpose: the app is server-rendered and always needs the network for the player/logging).
self.addEventListener("push", (event) => {
  const data = event.data ? event.data.json() : {}
  event.waitUntil(self.registration.showNotification(data.title || "Shichimi", {
    body: data.body,
    icon: "/icon-192.png",
    badge: "/icon-192.png",
    data: { url: data.url || "/" }
  }))
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const url = new URL(event.notification.data?.url || "/", self.location.origin).href
  event.waitUntil(clients.matchAll({ type: "window", includeUncontrolled: true }).then((list) => {
    const open = list.find((c) => "focus" in c)
    if (open) return "navigate" in open ? open.navigate(url).then((c) => (c || open).focus()) : open.focus()
    return clients.openWindow(url)
  }))
})
