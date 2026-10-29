import { Controller } from "@hotwired/stimulus"

const EXTRA_LABELS = ["Variant B", "Variant C", "Variant D"]

export default class extends Controller {
  static targets = [
    "toggle",
    "extraSection",
    "addButton",
    "abHint",
    "primaryLabel",
    "container",
    "blueprint",
    "variant",
    "label",
    "destroyFlag"
  ]

  connect() {
    this.syncAbState()
  }

  toggleAb() {
    if (this.toggleTarget.checked) {
      this.enableAb()
    } else {
      this.disableAb()
    }
  }

  add() {
    if (!this.toggleTarget.checked) return

    const visibleCount = this.visibleExtraVariants().length
    if (visibleCount >= 3) return

    const timestamp = new Date().getTime()
    const html = this.blueprintTarget.innerHTML.replace(/NEW_RECORD/g, timestamp)

    const wrapper = document.createElement("div")
    wrapper.innerHTML = html
    const node = wrapper.firstElementChild
    this.containerTarget.appendChild(node)

    this.relabelAll()
  }

  remove(event) {
    const variant = event.target.closest("[data-upsell-variants-target='variant']")
    if (!variant) return

    const destroyFlag = variant.querySelector("[data-upsell-variants-target='destroyFlag']")
    if (destroyFlag) {
      destroyFlag.value = "1"
      variant.style.display = "none"
    } else {
      variant.remove()
    }

    this.relabelAll()
  }

  syncAbState() {
    if (this.toggleTarget.checked) {
      this.enableAb()
    } else {
      this.disableAb()
    }
  }

  enableAb() {
    this.extraSectionTarget.classList.remove("hidden")
    if (this.hasAddButtonTarget) this.addButtonTarget.classList.remove("hidden")
    if (this.hasAbHintTarget) this.abHintTarget.classList.remove("hidden")
    if (this.hasPrimaryLabelTarget) this.primaryLabelTarget.classList.remove("hidden")
    this.relabelAll()
  }

  disableAb() {
    this.extraSectionTarget.classList.add("hidden")
    if (this.hasAddButtonTarget) this.addButtonTarget.classList.add("hidden")
    if (this.hasAbHintTarget) this.abHintTarget.classList.add("hidden")
    if (this.hasPrimaryLabelTarget) this.primaryLabelTarget.classList.add("hidden")

    this.visibleExtraVariants().forEach((variant) => {
      const destroyFlag = variant.querySelector("[data-upsell-variants-target='destroyFlag']")
      if (destroyFlag) {
        destroyFlag.value = "1"
        variant.style.display = "none"
      } else {
        variant.remove()
      }
    })
  }

  relabelAll() {
    if (!this.toggleTarget.checked) return

    this.visibleExtraVariants().forEach((variant, index) => {
      const label = variant.querySelector("[data-upsell-variants-target='label']")
      if (label) label.textContent = EXTRA_LABELS[index] || `Variant ${index + 2}`
    })
  }

  visibleExtraVariants() {
    return this.containerTarget.querySelectorAll(
      "[data-upsell-variants-target='variant']:not([style*='display: none'])"
    )
  }
}
