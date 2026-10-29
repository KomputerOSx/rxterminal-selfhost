import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "rxterminal_sound_alerts_enabled"

// Beeps when a brand-new service request joins the waiting queue.
// IDs seen on page load (or moved back from in progress / completed / cancelled) are ignored.
export default class extends Controller {
  static targets = ["toggleBtn", "toggleIcon", "toggleLabel"]

  connect() {
    this._enabled = localStorage.getItem(STORAGE_KEY) !== "false"
    this._updateButton()
    this._observeWaitingQueue()
  }

  disconnect() {
    this._observer?.disconnect()
  }

  toggle() {
    this._enabled = !this._enabled
    localStorage.setItem(STORAGE_KEY, this._enabled)
    this._updateButton()
    if (this._enabled) this._bleep()
  }

  _updateButton() {
    if (!this.hasToggleBtnTarget) return

    if (this._enabled) {
      this.toggleBtnTarget.classList.remove("btn-outline")
      this.toggleBtnTarget.classList.add("btn-success")
      this.toggleBtnTarget.title = "New customer sound on"
      if (this.hasToggleIconTarget) this.toggleIconTarget.textContent = "notifications"
      if (this.hasToggleLabelTarget) this.toggleLabelTarget.textContent = "Sound on"
    } else {
      this.toggleBtnTarget.classList.add("btn-outline")
      this.toggleBtnTarget.classList.remove("btn-success")
      this.toggleBtnTarget.title = "New customer sound off"
      if (this.hasToggleIconTarget) this.toggleIconTarget.textContent = "notifications_off"
      if (this.hasToggleLabelTarget) this.toggleLabelTarget.textContent = "Sound off"
    }
  }

  _observeWaitingQueue() {
    const container = document.getElementById("waiting-cards")
    if (!container) return

    this._knownIds = new Set(
      Array.from(document.querySelectorAll("[data-request-id]"))
        .map((el) => el.dataset.requestId)
        .filter(Boolean)
    )

    this._observer = new MutationObserver((mutations) => {
      if (!this._enabled) return

      for (const mutation of mutations) {
        if (mutation.type !== "childList") continue

        for (const node of mutation.addedNodes) {
          if (node.nodeType !== Node.ELEMENT_NODE) continue

          const frame = node.matches?.("turbo-frame") ? node : node.querySelector?.("turbo-frame")
          if (frame?.getAttribute("data-skeleton") === "true") continue

          const el = node.querySelector?.("[data-request-id]") || node
          const id = el.dataset?.requestId
          if (!id || this._knownIds.has(id)) continue

          this._knownIds.add(id)
          this._bleep()
          return
        }
      }
    })

    this._observer.observe(container, { childList: true })
  }

  _bleep() {
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)()
      ctx.resume().then(() => {
        const t = ctx.currentTime
        const oscillator = ctx.createOscillator()
        const gain = ctx.createGain()

        oscillator.connect(gain)
        gain.connect(ctx.destination)

        oscillator.type = "sine"
        oscillator.frequency.setValueAtTime(880, t)
        oscillator.frequency.setValueAtTime(1100, t + 0.4)

        gain.gain.setValueAtTime(0.4, t)
        gain.gain.exponentialRampToValueAtTime(0.001, t + 1)

        oscillator.start(t)
        oscillator.stop(t + 1)
        oscillator.onended = () => ctx.close()
      })
    } catch (_error) {
      // AudioContext not available
    }
  }
}
