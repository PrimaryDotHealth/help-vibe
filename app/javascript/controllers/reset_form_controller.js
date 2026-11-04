import { Controller } from "@hotwired/stimulus"

// Clears a message box after it's sent, with a fresh idempotency key.
export default class extends Controller {
  reset(event) {
    if (!event.detail.success) return
    this.element.reset()
    const key = this.element.querySelector("[name=client_id]")
    if (key) key.value = crypto.randomUUID()
  }
}
