import { Controller } from "@hotwired/stimulus"

// Live queue updates via ActionCable with poll fallback when the cable drops.
export default class extends Controller {
  static targets = ["statusIndicator", "refreshBtn", "completedOverlay", "completedPanel"]
  static values = {
    pollUrl: String,
    refreshUrl: String,
    pollInterval: { type: Number, default: 4000 }
  }

  connect() {
    this.updateConnectionStatus("connected")
    this._closeCompletedPanel = (event) => this.closeCompletedPanel(event)
    this.#bindCompletedPanelHandlers()
    this.#watchCableConnection()
    this._onVisibilityChange = () => this.#handleVisibilityChange()
    document.addEventListener("visibilitychange", this._onVisibilityChange)
  }

  disconnect() {
    this.#unbindCompletedPanelHandlers()
    clearTimeout(this._cableTimeout)
    this._cableObserver?.disconnect()
    this.#stopPolling()
    document.removeEventListener("visibilitychange", this._onVisibilityChange)
  }

  openCompletedPanel(event) {
    event?.preventDefault()
    const overlay = this.#completedOverlay()
    const panel = this.#completedPanel()
    if (!overlay || !panel) return

    overlay.classList.remove("hidden")
    requestAnimationFrame(() => {
      overlay.classList.remove("opacity-0")
      overlay.classList.add("opacity-100")
      panel.classList.remove("translate-x-full")
      panel.classList.add("translate-x-0")
    })
  }

  closeCompletedPanel(event) {
    event?.preventDefault()
    const overlay = this.#completedOverlay()
    const panel = this.#completedPanel()
    if (!overlay || !panel) return

    overlay.classList.remove("opacity-100")
    overlay.classList.add("opacity-0")
    panel.classList.remove("translate-x-0")
    panel.classList.add("translate-x-full")

    window.setTimeout(() => overlay.classList.add("hidden"), 300)
  }

  async refresh(event) {
    event.preventDefault()
    const refreshBtn = this.hasRefreshBtnTarget ? this.refreshBtnTarget : event.currentTarget
    const originalHTML = refreshBtn.innerHTML

    refreshBtn.disabled = true
    refreshBtn.innerHTML = '<span class="loading loading-spinner loading-sm"></span>'

    try {
      if (this.hasRefreshUrlValue) {
        await this.#postRefresh()
      } else {
        await this.#fetchPoll()
      }
    } finally {
      refreshBtn.disabled = false
      refreshBtn.innerHTML = originalHTML
    }
  }

  updateConnectionStatus(status) {
    if (!this.hasStatusIndicatorTarget) return

    if (status === "connected") {
      this.statusIndicatorTarget.textContent = "Connected"
      this.statusIndicatorTarget.className = "badge badge-success badge-sm"
    } else if (status === "reconnecting") {
      this.statusIndicatorTarget.textContent = "Auto-refreshing"
      this.statusIndicatorTarget.className = "badge badge-warning badge-sm"
    } else {
      this.statusIndicatorTarget.textContent = "Paused"
      this.statusIndicatorTarget.className = "badge badge-ghost badge-sm"
    }
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
        this.updateConnectionStatus("connected")
      } else {
        this.#startPolling()
      }
    })
    this._cableObserver.observe(el, { attributes: true, attributeFilter: ["connected"] })
  }

  #completedOverlay() {
    return this.hasCompletedOverlayTarget ? this.completedOverlayTarget : document.getElementById("completed-overlay")
  }

  #completedPanel() {
    return this.hasCompletedPanelTarget ? this.completedPanelTarget : document.getElementById("completed-panel")
  }

  #bindCompletedPanelHandlers() {
    const overlay = this.#completedOverlay()
    const panel = this.#completedPanel()
    const closeButton = panel?.querySelector("[data-completed-panel-close]")

    overlay?.addEventListener("click", this._closeCompletedPanel)
    closeButton?.addEventListener("click", this._closeCompletedPanel)
  }

  #unbindCompletedPanelHandlers() {
    const overlay = this.#completedOverlay()
    const panel = this.#completedPanel()
    const closeButton = panel?.querySelector("[data-completed-panel-close]")

    overlay?.removeEventListener("click", this._closeCompletedPanel)
    closeButton?.removeEventListener("click", this._closeCompletedPanel)
  }

  #handleVisibilityChange() {
    if (document.hidden) {
      this.#stopPolling()
      this.updateConnectionStatus("paused")
    } else if (document.querySelector("turbo-cable-stream-source")?.hasAttribute("connected")) {
      this.updateConnectionStatus("connected")
    } else {
      this.#startPolling()
    }
  }

  #startPolling() {
    if (this._pollTimer || !this.hasPollUrlValue || document.hidden) return
    this.updateConnectionStatus("reconnecting")
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

  async #postRefresh() {
    const currentUrl = new URL(window.location.href)
    const serviceIds = currentUrl.searchParams.getAll("service_ids[]")
    const refreshUrl = new URL(this.refreshUrlValue, window.location.origin)
    serviceIds.forEach((id) => refreshUrl.searchParams.append("service_ids[]", id))

    const response = await fetch(refreshUrl.toString(), {
      method: "POST",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      }
    })

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`)
    }

    const html = await response.text()
    if (html.trim()) Turbo.renderStreamMessage(html)
  }
}
