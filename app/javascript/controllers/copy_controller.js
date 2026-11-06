import { Controller } from "@hotwired/stimulus"

// Copies a code block's text: <div data-controller="copy"><pre data-copy-target="source">…
export default class extends Controller {
  static targets = ["source", "button"]

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.textContent.trim()).then(() => {
      const label = this.buttonTarget.textContent
      this.buttonTarget.textContent = "Copied"
      setTimeout(() => { this.buttonTarget.textContent = label }, 1500)
    })
  }
}
