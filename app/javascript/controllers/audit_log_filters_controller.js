import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { minFrom: String }

  applyRange(event) {
    let { from, to } = event.params
    if (this.hasMinFromValue && from && from < this.minFromValue) {
      from = this.minFromValue
    }
    this.updateField('[name="date_from"]', from)
    this.updateField('[name="date_to"]', to)
  }

  updateField(selector, value) {
    const field = this.element.querySelector(selector)
    if (!field) return

    field.value = value
    field.dispatchEvent(new Event("input", { bubbles: true }))
    field.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
