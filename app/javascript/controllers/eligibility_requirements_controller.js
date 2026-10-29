import { Controller } from "@hotwired/stimulus"

// Dynamic eligibility requirement rows for service forms.
export default class extends Controller {
  static targets = ["eligibleList", "notEligibleList", "additionalList"]
  static values = { paramRoot: { type: String, default: "service" } }

  addEligible() { this.#addRow(this.eligibleListTarget, "eligible") }
  addNotEligible() { this.#addRow(this.notEligibleListTarget, "not_eligible") }
  addAdditional() { this.#addRow(this.additionalListTarget, "additional") }

  remove(event) {
    event.currentTarget.closest("[data-eligibility-row]")?.remove()
  }

  #addRow(list, section) {
    const row = this.#buildRow(section)
    list.appendChild(row)
    row.querySelector("input")?.focus()
  }

  #buildRow(section) {
    const div = document.createElement("div")
    div.dataset.eligibilityRow = ""
    div.className = "flex items-center gap-2"

    const input = document.createElement("input")
    input.type = "text"
    input.name = `${this.paramRootValue}[eligibility_requirements][${section}][]`
    input.className = "input-field flex-1"

    const btn = document.createElement("button")
    btn.type = "button"
    btn.dataset.action = "eligibility-requirements#remove"
    btn.className = "btn btn-ghost btn-xs btn-square shrink-0 text-error"
    btn.title = "Remove"
    btn.innerHTML = `<span class="material-symbols-outlined" style="font-size:18px">close</span>`

    div.appendChild(input)
    div.appendChild(btn)
    return div
  }
}
