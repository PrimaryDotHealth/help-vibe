import { Controller } from "@hotwired/stimulus"

// A message that floats over the page. Confirmations fade out on their own;
// errors stay until dismissed.
export default class extends Controller {
  static values = { sticky: Boolean }

  connect() {
    if (!this.stickyValue) this.timer = setTimeout(() => this.dismiss(), 3500)
  }

  disconnect() { clearTimeout(this.timer) }

  dismiss() {
    this.element.classList.add("leaving")
    setTimeout(() => this.element.remove(), 200)
  }
}
