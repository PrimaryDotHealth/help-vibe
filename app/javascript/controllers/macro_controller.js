import { Controller } from "@hotwired/stimulus"

// Inserts a saved reply (already filled in for this contact) into the reply box.
export default class extends Controller {
  static targets = ["body", "id"]

  insert(event) {
    const option = event.target.selectedOptions[0]
    if (!option?.value) return
    const text = option.dataset.body
    const box = this.bodyTarget
    box.value = box.value.trim() ? `${box.value.trimEnd()}\n\n${text}` : text
    this.idTarget.value = option.value
    event.target.value = ""
    box.focus()
  }
}
