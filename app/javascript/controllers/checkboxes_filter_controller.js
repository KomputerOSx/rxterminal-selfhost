import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "item", "checkbox"]

  connect() {
    this.filter()
  }

  filter() {
    const query = this.searchTarget.value.toLowerCase()

    this.itemTargets.forEach(item => {
      const matchesSearch = item.dataset.label.toLowerCase().includes(query)
      item.classList.toggle("hidden", !matchesSearch)
    })
  }

  selectAll() {
    this.itemTargets.forEach(item => {
      if (!item.classList.contains("hidden")) {
        item.querySelector("input[type=checkbox]").checked = true
      }
    })
  }

  clear() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    this.searchTarget.value = ""
    this.filter()
  }
}
