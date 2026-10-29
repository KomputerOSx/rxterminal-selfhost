import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dayRow", "openCheckbox", "timeFields", "closedNote", "openInput", "closeInput"]

  connect() {
    this.openCheckboxTargets.forEach((checkbox) => this.#toggleRow(checkbox))
  }

  openChanged(event) {
    this.#toggleRow(event.target)
  }

  #toggleRow(checkbox) {
    const row = checkbox.closest("[data-opening-hours-target='dayRow']")
    if (!row) return

    const open = checkbox.checked
    row.querySelectorAll("[data-opening-hours-target='timeFields']").forEach((element) => {
      element.classList.toggle("hidden", !open)
    })
    row.querySelectorAll("[data-opening-hours-target='closedNote']").forEach((element) => {
      element.classList.toggle("hidden", open)
    })
    row.querySelectorAll("input[type='time']").forEach((input) => {
      input.disabled = !open
    })
  }
}
