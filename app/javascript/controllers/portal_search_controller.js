import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "item", "empty"]

  filter() {
    const query = this.inputTarget.value.toLowerCase().trim()
    let visible = 0

    this.itemTargets.forEach(item => {
      const match = !query || item.dataset.name.toLowerCase().includes(query)
      item.classList.toggle("hidden", !match)
      if (match) visible++
    })

    if (this.hasEmptyTarget) {
      this.emptyTarget.classList.toggle("hidden", visible > 0)
    }
  }
}
