import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    pollUrl: String,
    pollInterval: { type: Number, default: 4000 }
  }

  connect() {
    this.#watchCableConnection()
    this._onVisibilityChange = () => this.#handleVisibilityChange()
    document.addEventListener("visibilitychange", this._onVisibilityChange)
  }

  disconnect() {
    clearTimeout(this._cableTimeout)
    this._cableObserver?.disconnect()
    this.#stopPolling()
    document.removeEventListener("visibilitychange", this._onVisibilityChange)
  }

  #watchCableConnection() {
    const el = document.querySelector("turbo-cable-stream-source")
    if (!el) {
      this.#startPolling()
      return
    }

    this._cableTimeout = window.setTimeout(() => {
      if (!el.hasAttribute("connected")) this.#startPolling()
    }, 3000)

    this._cableObserver = new MutationObserver(() => {
      if (el.hasAttribute("connected")) {
        clearTimeout(this._cableTimeout)
        this.#stopPolling()
      } else {
        this.#startPolling()
      }
    })
    this._cableObserver.observe(el, { attributes: true, attributeFilter: ["connected"] })
  }

  #handleVisibilityChange() {
    if (document.hidden) {
      this.#stopPolling()
    } else if (document.querySelector("turbo-cable-stream-source")?.hasAttribute("connected")) {
      this.#stopPolling()
    } else {
      this.#startPolling()
      this.#fetchPoll()
    }
  }

  #startPolling() {
    if (this._pollTimer || !this.hasPollUrlValue || document.hidden) return
    this._pollTimer = window.setInterval(() => this.#fetchPoll(), this.pollIntervalValue)
    this.#fetchPoll()
  }

  #stopPolling() {
    if (!this._pollTimer) return
    window.clearInterval(this._pollTimer)
    this._pollTimer = null
  }

  async #fetchPoll() {
    const currentUrl = new URL(window.location.href)
    const serviceIds = currentUrl.searchParams.getAll("service_ids[]")
    const pollUrl = new URL(this.pollUrlValue, window.location.origin)
    serviceIds.forEach((id) => pollUrl.searchParams.append("service_ids[]", id))

    try {
      const response = await fetch(pollUrl.toString(), {
        headers: { Accept: "text/vnd.turbo-stream.html" }
      })
      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (_error) {
      // retry on next tick
    }
  }
}
