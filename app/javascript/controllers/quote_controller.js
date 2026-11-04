import { Controller } from "@hotwired/stimulus"

// Remembers the text last selected in the article so a new comment can quote it.
export default class extends Controller {
  static targets = ["field", "preview"]

  connect() {
    this.onSelection = () => {
      const selection = document.getSelection()
      const node = selection?.anchorNode
      const inEditor = node && (node.nodeType === 1 ? node : node.parentElement)?.closest(".lexxy-editor__content")
      const text = selection?.toString().trim()
      if (inEditor && text) {
        this.fieldTarget.value = text.slice(0, 300)
        this.previewTarget.textContent = `Quoting "${text.slice(0, 80)}${text.length > 80 ? "…" : ""}"`
        this.previewTarget.hidden = false
      }
    }
    document.addEventListener("selectionchange", this.onSelection)
  }

  disconnect() { document.removeEventListener("selectionchange", this.onSelection) }
}
