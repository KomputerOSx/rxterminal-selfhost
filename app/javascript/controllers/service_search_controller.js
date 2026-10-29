import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "form", "display", "clearBtn"]

  connect() {
    this.timer = null
    this._syncDisplay()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  pressKey(event) {
    const key = event.currentTarget.dataset.key
    const cur = this.inputTarget.value
    if (key === "⌫") {
      this.inputTarget.value = cur.slice(0, -1)
    } else if (key === "SPACE") {
      if (cur.length > 0) this.inputTarget.value = cur + " "
    } else {
      this.inputTarget.value = cur + key.toLowerCase()
    }
    this._syncDisplay()
    this.scheduleSearch()
  }

  clearSearch(event) {
    this.inputTarget.value = ""
    this._syncDisplay()
    this.scheduleSearch()
  }

  scheduleSearch() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.formTarget.requestSubmit(), 280)
  }

  _syncDisplay() {
    const val = this.inputTarget.value
    if (this.hasDisplayTarget) {
      this.displayTarget.textContent = val || "·"
      this.displayTarget.classList.toggle("kiosk-search-display-text--empty", !val)
      this.displayTarget.classList.toggle("kiosk-search-display-text--filled", !!val)
    }
    if (this.hasClearBtnTarget) {
      this.clearBtnTarget.classList.toggle("hidden", !val)
    }
  }
}
