import { Controller } from "@hotwired/stimulus"

// Switches between two panels (e.g. list vs. card layout) and remembers the
// choice in localStorage per storageKey so it persists across visits.
export default class extends Controller {
  static targets = ["panel", "button"]
  static values = { storageKey: String, default: { type: String, default: "list" } }

  connect() {
    const stored = this.storageKeyValue ? localStorage.getItem(this.storageKeyValue) : null
    this.show(stored || this.defaultValue)
  }

  select(event) {
    this.show(event.currentTarget.dataset.viewToggleModeParam)
  }

  show(mode) {
    this.panelTargets.forEach(panel => {
      panel.classList.toggle("hidden", panel.dataset.viewToggleMode !== mode)
    })

    this.buttonTargets.forEach(button => {
      const active = button.dataset.viewToggleModeParam === mode
      button.classList.toggle("btn-active", active)
      button.setAttribute("aria-pressed", active ? "true" : "false")
    })

    if (this.storageKeyValue) {
      localStorage.setItem(this.storageKeyValue, mode)
    }
  }
}
