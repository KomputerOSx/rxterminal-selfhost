import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rolling", "openings"]

  change(event) {
    const openings = event.target.value === "openings"
    this.rollingTargets.forEach((element) => element.classList.toggle("hidden", openings))
    this.openingsTargets.forEach((element) => element.classList.toggle("hidden", !openings))
  }
}
