import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button"]

  toggle() {
    const open = this.menuTarget.classList.toggle("is-open")
    this.buttonTarget.classList.toggle("is-open", open)
    this.buttonTarget.setAttribute("aria-expanded", String(open))
    this.menuTarget.setAttribute("aria-hidden", String(!open))
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.remove("is-open")
      this.buttonTarget.classList.remove("is-open")
      this.buttonTarget.setAttribute("aria-expanded", "false")
      this.menuTarget.setAttribute("aria-hidden", "true")
    }
  }
}
