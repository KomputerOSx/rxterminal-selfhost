import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  static values = {
    minOptions: { type: Number, default: 8 }
  }

  connect() {
    if (this.#shouldSkip()) return

    this.tomSelect = new TomSelect(this.element, {
      allowEmptyOption: true,
      create: false,
      maxOptions: null,
      hideSelected: false,
      closeAfterSelect: true
    })

    this.#syncDisabled()
    this.disabledObserver = new MutationObserver(() => this.#syncDisabled())
    this.disabledObserver.observe(this.element, { attributes: true, attributeFilter: ["disabled"] })
  }

  disconnect() {
    this.disabledObserver?.disconnect()
    this.tomSelect?.destroy()
    this.tomSelect = null
  }

  #shouldSkip() {
    if (this.element.multiple) return true

    const optionCount = this.element.options.length
    const blankCount = this.element.querySelector('option[value=""]') ? 1 : 0

    return optionCount - blankCount < this.minOptionsValue
  }

  #syncDisabled() {
    if (!this.tomSelect) return

    if (this.element.disabled) {
      this.tomSelect.disable()
    } else {
      this.tomSelect.enable()
    }
  }
}
