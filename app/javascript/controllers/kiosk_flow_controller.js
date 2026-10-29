import { Controller } from "@hotwired/stimulus"
import { showPanelImmediate, transitionPanels } from "kiosk/panel_transitions"

// Two-panel kiosk home: touch-start → home menu
export default class extends Controller {
  static targets = ["touchPanel", "homePanel"]

  connect() {
    this.#showImmediate(this.touchPanelTarget)
  }

  start() {
    this.#transition(this.touchPanelTarget, this.homePanelTarget, "forward")
  }

  ignoreStart(event) {
    event.stopPropagation()
  }

  #showImmediate(panel) {
    showPanelImmediate(this.#allPanels(), panel)
  }

  #transition(from, to, direction) {
    transitionPanels(from, to, direction)
  }

  #allPanels() {
    return [this.touchPanelTarget, this.homePanelTarget]
  }
}
