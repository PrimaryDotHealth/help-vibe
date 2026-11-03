import { Controller } from "@hotwired/stimulus"

// Saves the editor a couple of seconds after typing stops, as an autosave
// revision. Handles "a newer copy exists" (409) by stopping and saying so.
export default class extends Controller {
  static targets = ["base", "version", "saved", "status"]
  static values = { url: String, delay: { type: Number, default: 2500 } }

  connect() { this.dirty = false; this.conflict = false }
  disconnect() { clearTimeout(this.timer) }

  changed() {
    if (this.conflict) return
    this.dirty = true
    this.show("Unsaved changes", "")
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), this.delayValue)
  }

  async save() {
    if (!this.dirty) return
    this.dirty = false
    const form = new FormData(this.element)
    const body = new FormData()
    body.append("autosave", "1")
    body.append("base_revision_id", this.baseTarget.value)
    for (const key of ["title", "subtitle", "body"]) body.append(key, form.get(`editor[${key}]`) || "")
    this.show("Saving…", "saving")
    try {
      const response = await fetch(this.urlValue, {
        method: "POST", body, credentials: "same-origin",
        headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content || "", "Accept": "application/json" }
      })
      if (response.status === 409) {
        this.conflict = true
        return this.show("Someone saved a newer copy. Reload to see it.", "error")
      }
      if (!response.ok) throw new Error(response.status)
      const data = await response.json()
      this.baseTarget.value = data.revision_id
      if (String(data.version_id) !== this.versionTarget.value) {
        this.versionTarget.value = data.version_id
        this.urlValue = this.urlValue.replace(/versions\/\d+/, `versions/${data.version_id}`)
      }
      this.statusTarget.textContent = data.status
      this.show(`Saved ${data.saved_at}`, "")
    } catch (e) {
      this.dirty = true
      this.show("Offline, retrying", "error")
      this.timer = setTimeout(() => this.save(), 5000)
    }
  }

  show(text, state) {
    this.savedTarget.textContent = text
    this.savedTarget.className = `saved ${state}`.trim()
  }
}
