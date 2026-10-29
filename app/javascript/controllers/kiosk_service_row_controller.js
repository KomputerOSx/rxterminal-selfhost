import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "featuredInput", "featuredButton", "featuredIcon", "activeInput", "activeButton", "activeIcon"]

  static values = {
    featured: Boolean,
    active: Boolean
  }

  toggleFeatured() {
    this.featuredValue = !this.featuredValue
    this.featuredInputTarget.value = this.featuredValue ? "1" : "0"
    this.syncFeaturedButton()
  }

  toggleActive() {
    this.activeValue = !this.activeValue
    this.activeInputTarget.value = this.activeValue ? "1" : "0"
    this.syncActiveButton()
  }

  featuredValueChanged() {
    this.syncFeaturedButton()
  }

  activeValueChanged() {
    this.syncActiveButton()
  }

  syncFeaturedButton() {
    const featured = this.featuredValue
    this.featuredButtonTarget.title = featured ? "Remove featured" : "Mark as featured"
    this.featuredButtonTarget.classList.toggle("text-warning", featured)
    this.featuredButtonTarget.classList.toggle("text-base-content/30", !featured)
    this.featuredButtonTarget.classList.toggle("hover:text-warning", !featured)
    this.featuredIconTarget.textContent = featured ? "star" : "star_border"
  }

  syncActiveButton() {
    const active = this.activeValue
    this.activeButtonTarget.title = active ? "Hide from kiosk" : "Show on kiosk"
    this.activeButtonTarget.classList.toggle("text-success", active)
    this.activeButtonTarget.classList.toggle("text-base-content/30", !active)
    this.activeButtonTarget.classList.toggle("hover:text-base-content/60", !active)
    this.activeIconTarget.textContent = active ? "visibility" : "visibility_off"

    this.rowTarget.classList.toggle("bg-base-100", active)
    this.rowTarget.classList.toggle("bg-base-200/40", !active)
    this.rowTarget.classList.toggle("opacity-70", !active)
  }
}
