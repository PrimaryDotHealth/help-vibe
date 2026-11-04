import { Controller } from "@hotwired/stimulus"

// While someone types a question in the widget, show matching articles
// (most questions are answered before they're sent).
export default class extends Controller {
  static targets = ["input", "frame", "query"]
  static values = { url: String }

  changed() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      const q = this.inputTarget.value.trim().split(/\s+/).slice(0, 12).join(" ")
      if (q.length < 6) return
      this.queryTarget.value = q
      this.frameTarget.src = `${this.urlValue}?q=${encodeURIComponent(q)}&suggest=1`
    }, 500)
  }
}
