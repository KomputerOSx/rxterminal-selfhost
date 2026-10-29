import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "error", "submit" ]
  static values = { remaining: Number }

  validate() {
    const count = this.inputTarget.files?.length || 0

    if (count > this.remainingValue) {
      this.errorTarget.textContent = `You can only upload ${this.remainingValue} more logo${this.remainingValue === 1 ? "" : "s"} right now.`
      this.errorTarget.classList.remove("hidden")
      this.submitTarget.disabled = true
    } else {
      this.errorTarget.classList.add("hidden")
      this.submitTarget.disabled = false
    }
  }
}
