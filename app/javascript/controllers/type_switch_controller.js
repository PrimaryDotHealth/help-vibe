import { Controller } from "@hotwired/stimulus"

// Changing the ticket type reloads the form for that type's fields,
// keeping everything already typed.
export default class extends Controller {
  static values = { url: String }

  reload() {
    const params = new URLSearchParams(new FormData(this.element))
    params.delete("authenticity_token")
    window.location = `${this.urlValue}?${params}`
  }
}
