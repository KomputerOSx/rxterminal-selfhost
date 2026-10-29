import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list"]

  change(event) {
    this.listTarget.classList.toggle("hidden", event.target.value !== "selected")
  }
}
