import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "featuredToggle",
    "featuredPicker",
    "featuredSelect"
  ]

  connect() {
    this.syncFeaturedPicker()
  }

  toggleFeatured() {
    this.syncFeaturedPicker()
  }

  syncFeaturedPicker() {
    const enabled = this.featuredToggleTarget.checked
    this.featuredPickerTarget.classList.toggle("opacity-50", !enabled)
    this.featuredPickerTarget.classList.toggle("pointer-events-none", !enabled)
    this.featuredSelectTarget.disabled = !enabled
  }
}
