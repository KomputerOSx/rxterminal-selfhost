import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "popover", "results"]
  static values = { url: String }

  connect() {
    this.boundCloseOnOutside = this.closeOnOutsideClick.bind(this)
    this.boundCloseOnEscape = this.closeOnEscape.bind(this)
  }

  disconnect() {
    this.#removeListeners()
  }

  open() {
    this.popoverTarget.classList.remove("hidden")
    document.addEventListener("click", this.boundCloseOnOutside, true)
    document.addEventListener("keydown", this.boundCloseOnEscape, true)
  }

  close() {
    this.popoverTarget.classList.add("hidden")
    this.#removeListeners()
  }

  query() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.performSearch(), 250)
  }

  async performSearch() {
    const query = this.inputTarget.value.trim()
    if (query.length < 2) {
      this.resultsTarget.innerHTML = ""
      this.close()
      return
    }

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)

    const response = await fetch(url, { headers: { Accept: "text/html" } })
    if (response.ok) {
      this.resultsTarget.innerHTML = await response.text()
      this.open()
    }
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
      this.inputTarget.blur()
    }
  }

  #removeListeners() {
    document.removeEventListener("click", this.boundCloseOnOutside, true)
    document.removeEventListener("keydown", this.boundCloseOnEscape, true)
  }
}
