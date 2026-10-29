import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { services: Array }
  static targets = ["serviceSelect", "eligibilitySection", "eligibilityContent", "privacySection"]

  connect() {
    this.updateServiceInfo()
  }

  serviceChanged() {
    this.updateServiceInfo()
  }

  selectRecent(event) {
    this.serviceSelectTarget.value = event.params.id
    this.updateServiceInfo()
  }

  updateServiceInfo() {
    const id = parseInt(this.serviceSelectTarget.value, 10)
    const service = this.servicesValue.find((entry) => entry.id === id)

    if (!service) {
      this.eligibilitySectionTarget.classList.add("hidden")
      if (this.hasPrivacySectionTarget) this.privacySectionTarget.classList.add("hidden")
      return
    }

    if (service.has_eligibility) {
      this.#renderEligibility(service.eligibility)
      this.eligibilitySectionTarget.classList.remove("hidden")
    } else {
      this.eligibilitySectionTarget.classList.add("hidden")
    }

    if (this.hasPrivacySectionTarget) {
      this.privacySectionTarget.classList.toggle("hidden", !service.allows_private)
    }
  }

  uppercase(event) {
    const element = event.target
    const position = element.selectionStart
    element.value = element.value.toUpperCase()
    element.setSelectionRange(position, position)
  }

  #renderEligibility(requirements) {
    const sections = [
      {
        label: "Eligible if:",
        cardClass: "border border-success/30 bg-success/10",
        labelClass: "text-success",
        items: (requirements.eligible || []).filter(Boolean)
      },
      {
        label: "Not eligible if:",
        cardClass: "border border-error/30 bg-error/10",
        labelClass: "text-error",
        items: (requirements.not_eligible || []).filter(Boolean)
      },
      {
        label: "Additional information:",
        cardClass: "border border-info/30 bg-info/10",
        labelClass: "text-info",
        items: (requirements.additional || []).filter(Boolean)
      }
    ].filter((section) => section.items.length > 0)

    this.eligibilityContentTarget.className = "mt-1 grid grid-cols-1 gap-4"
    this.eligibilityContentTarget.innerHTML = sections.map((section) => `
      <div class="rounded-lg p-4 ${section.cardClass}">
        <p class="text-xs font-semibold uppercase tracking-wide ${section.labelClass}">${section.label}</p>
        <ul class="mt-2 list-disc space-y-1 pl-4 text-sm text-base-content/80">
          ${section.items.map((item) => `<li>${this.#escapeHtml(item)}</li>`).join("")}
        </ul>
      </div>
    `).join("")
  }

  #escapeHtml(value) {
    return value
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
  }
}
