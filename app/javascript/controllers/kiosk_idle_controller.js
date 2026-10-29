import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    timeout:       { type: Number, default: 30000 },
    countdown:     { type: Number, default: 5 },
    mode:          { type: String, default: "overlay" },
    formSelector:  { type: String, default: "" },
    redirectUrl:   { type: String, default: "/kiosk" },
    interruptible: { type: Boolean, default: true },
  }

  static targets = ["countdownText"]

  connect() {
    if (document.body.dataset.kioskPreview === "true") return

    this._idleTimer = null
    this._countdownInterval = null
    this._countdownRemaining = 0
    this._prefetchDone = false
    this._boundReset = this._resetIdleTimer.bind(this)

    this._events = ["touchstart", "touchmove", "click", "keypress", "mousemove", "scroll", "input", "change"]
    if (this.interruptibleValue) {
      this._events.forEach(ev => document.addEventListener(ev, this._boundReset, true))
    }

    this._boundCancel = this.cancel.bind(this)
    if (this.interruptibleValue) {
      document.addEventListener("idle:cancel", this._boundCancel)
    }

    if (this.timeoutValue === 0) {
      this._onIdle()
    } else {
      this._resetIdleTimer()
    }
  }

  disconnect() {
    this._clearAll()
    this._events.forEach(ev => document.removeEventListener(ev, this._boundReset, true))
    document.removeEventListener("idle:cancel", this._boundCancel)
  }

  cancel() {
    this._cancelCountdown()
    this._resetIdleTimer()
  }

  _resetIdleTimer() {
    clearTimeout(this._idleTimer)
    this._cancelCountdown()
    this._idleTimer = setTimeout(() => this._onIdle(), this.timeoutValue)
  }

  _onIdle() {
    this._prefetch()

    switch (this.modeValue) {
      case "overlay":
        this._startOverlayCountdown()
        break
      case "auto-submit":
        this._autoSubmit()
        break
      case "auto-redirect":
        this._startInlineCountdown()
        break
    }
  }

  _startOverlayCountdown() {
    const overlay = document.getElementById("idle-countdown-overlay")
    const numberEl = document.getElementById("idle-countdown-number")
    if (!overlay || !numberEl) return

    this._countdownRemaining = this.countdownValue
    numberEl.textContent = this._countdownRemaining
    overlay.classList.remove("hidden")
    overlay.style.display = "flex"

    this._countdownInterval = setInterval(() => {
      this._countdownRemaining -= 1
      numberEl.textContent = this._countdownRemaining
      if (this._countdownRemaining <= 0) {
        this._clearAll()
        Turbo.visit(this.redirectUrlValue)
      }
    }, 1000)
  }

  _startInlineCountdown() {
    this._countdownRemaining = this.countdownValue

    this._countdownInterval = setInterval(() => {
      this._countdownRemaining -= 1
      if (this._countdownRemaining <= 0) {
        this._clearAll()
        Turbo.visit(this.redirectUrlValue)
      } else if (this.hasCountdownTextTarget) {
        const s = this._countdownRemaining === 1 ? "" : "s"
        this.countdownTextTarget.textContent =
          `Returning to home screen in ${this._countdownRemaining} second${s}\u2026`
      }
    }, 1000)
  }

  _autoSubmit() {
    const form = document.querySelector(this.formSelectorValue)
    if (form) form.requestSubmit()
  }

  _cancelCountdown() {
    clearInterval(this._countdownInterval)
    this._countdownInterval = null

    const overlay = document.getElementById("idle-countdown-overlay")
    if (overlay) {
      overlay.style.display = "none"
      overlay.classList.add("hidden")
    }
  }

  _clearAll() {
    clearTimeout(this._idleTimer)
    clearInterval(this._countdownInterval)
    this._idleTimer = null
    this._countdownInterval = null
  }

  _prefetch() {
    if (this._prefetchDone) return
    this._prefetchDone = true
    fetch(this.redirectUrlValue, { credentials: "same-origin" }).catch(() => {})
  }
}
