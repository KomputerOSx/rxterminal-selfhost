import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = {
    url: String,
    idAttribute: { type: String, default: "serviceId" }
  }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      handle: "[data-sortable-handle]",
      ghostClass: "sortable-ghost",
      dragClass: "sortable-drag",
      chosenClass: "sortable-chosen",
      onEnd: this.onEnd.bind(this)
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  onEnd() {
    if (!this.hasUrlValue) return

    const attr = this.idAttributeValue
    const ids = Array.from(this.element.querySelectorAll(`[data-${this.attrSelector}]`))
      .map((element) => element.dataset[attr])

    const token = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify({ ids })
    })
  }

  get attrSelector() {
    return this.idAttributeValue.replace(/([A-Z])/g, "-$1").toLowerCase()
  }
}
