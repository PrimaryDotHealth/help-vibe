import { Controller } from "@hotwired/stimulus"

// Inside an embedded-article iframe: tell the host page how tall the article
// is, so it can size the frame to fit. Height only; nothing private.
export default class extends Controller {
  static values = { slug: String }

  connect() {
    if (window.parent === window) return
    this.observer = new ResizeObserver(() => this.post())
    this.observer.observe(this.element)
    this.element.addEventListener("toggle", () => this.post(), true)   // FAQ questions opening
  }

  disconnect() { this.observer?.disconnect() }

  post() {
    const height = Math.ceil(this.element.getBoundingClientRect().height)
    window.parent.postMessage({ helpvibe: "embed-height", slug: this.slugValue, height }, "*")
  }
}
