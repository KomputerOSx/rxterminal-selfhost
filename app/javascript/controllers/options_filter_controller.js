import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "item", "checkbox"]

  connect() {
    this.filter()
  }

  filter() {
    const query = this.hasSearchTarget ? this.searchTarget.value.trim().toLowerCase() : ""

    this.itemTargets.forEach((item) => {
      const label = (item.dataset.label || item.textContent).toLowerCase()
      const matches = !query || label.includes(query)
      item.classList.toggle("hidden", !matches)
    })
  }

  selectAll() {
    if (!this.hasCheckboxTarget) return

    this.itemTargets.forEach((item) => {
      if (item.classList.contains("hidden")) return

      const checkbox = item.querySelector('input[type="checkbox"]')
      if (checkbox) checkbox.checked = true
    })
  }

  clear() {
    if (this.hasCheckboxTarget) {
      this.checkboxTargets.forEach((checkbox) => {
        checkbox.checked = false
      })
    }

    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
    }

    this.filter()
  }
}
