import { Controller } from "@hotwired/stimulus"

// Runs inside the widget iframe. The host page (our app) sends the signed
// token with postMessage; we exchange it for a widget cookie and reload once
// so staff-only articles appear.
export default class extends Controller {
  static values = { kind: String, url: String }

  connect() {
    this.onMessage = (event) => this.received(event)
    window.addEventListener("message", this.onMessage)
    window.parent?.postMessage({ helpvibe: "ready" }, "*")
  }

  disconnect() { window.removeEventListener("message", this.onMessage) }

  async received(event) {
    const data = event.data || {}
    if (data.helpvibe !== "identify" || !data.token || this.busy) return
    this.busy = true
    try {
      const response = await fetch(this.urlValue, {
        method: "POST", credentials: "include",
        headers: { "Content-Type": "application/json", "Accept": "application/json" },
        body: JSON.stringify({ token: data.token })
      })
      if (!response.ok) return
      const { kind } = await response.json()
      if (kind !== this.kindValue) location.reload()
    } finally { this.busy = false }
  }
}
