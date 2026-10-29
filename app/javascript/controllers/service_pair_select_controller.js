import { Controller } from "@hotwired/stimulus"

// Keeps the "trigger service" and "suggested service" selects on the upsell
// rule form mutually exclusive: whichever service is picked in one is
// disabled as an option in the other, so the two selects can no longer be
// used to pick the same service (previously only caught by a server-side
// validation after submit).
export default class extends Controller {
  static targets = ["trigger", "suggested"]

  connect() {
    this.sync()
  }

  sync() {
    this.#exclude(this.triggerTarget, this.suggestedTarget)
    this.#exclude(this.suggestedTarget, this.triggerTarget)
  }

  #exclude(source, target) {
    const value = source.value

    Array.from(target.options).forEach((option) => {
      if (!option.value) return
      option.disabled = value !== "" && option.value === value
    })

    this.#refreshTomSelect(target)
  }

  #refreshTomSelect(selectEl) {
    const controller = this.application.getControllerForElementAndIdentifier(selectEl, "searchable-select")
    const tomSelect = controller?.tomSelect
    if (!tomSelect) return

    Object.keys(tomSelect.options).forEach((value) => {
      const optionEl = Array.from(selectEl.options).find((option) => option.value === value)
      if (!optionEl) return
      tomSelect.updateOption(value, { ...tomSelect.options[value], disabled: optionEl.disabled })
    })

    tomSelect.refreshOptions(false)
  }
}
