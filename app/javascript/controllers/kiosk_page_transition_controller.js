import { Controller } from "@hotwired/stimulus"
import { consumePageDirection } from "kiosk/page_transitions"

// Fallback enter animation when View Transitions API is unavailable
export default class extends Controller {
  connect() {
    if (document.startViewTransition) return

    const direction = consumePageDirection()
    this.element.dataset.kioskEnter = direction

    requestAnimationFrame(() => {
      this.element.dataset.kioskEnterActive = "true"
    })
  }
}
