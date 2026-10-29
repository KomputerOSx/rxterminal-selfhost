import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="voice-announcement"
// Observes #in-progress-cards for new cards added via Turbo Streams
// and announces the queue number using the Web Speech API.
export default class extends Controller {
  static targets = ["toggleBtn", "toggleIcon", "toggleLabel"]
  static values = {
    announce: String,
    enabledByDefault: Boolean,
    observeMutations: { type: Boolean, default: true },
  }

  static STORAGE_KEY = "rxterm_voice_enabled"

  connect() {
    const storedPreference = localStorage.getItem(this.constructor.STORAGE_KEY)
    this.enabled = storedPreference ? storedPreference === "true" : this.enabledByDefaultValue
    this.preferredVoice = null
    this.loadVoice()
    this.updateToggleUI()
    this.setupObserver()

    if (this.enabled && this.hasAnnounceValue) {
      setTimeout(() => this.announce(this.announceValue), 150)
    }
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  loadVoice() {
    if (!window.speechSynthesis) return

    const pickBest = () => {
      const voices = window.speechSynthesis.getVoices()
      if (!voices.length) return

      const ranked = [
        (v) => v.name === "Google UK English Female",
        (v) => v.name === "Google UK English Male",
        (v) => v.name.includes("Google") && v.lang.startsWith("en"),
        (v) => v.name.includes("Microsoft") && v.name.includes("Online") && v.lang.startsWith("en-GB"),
        (v) => v.name.includes("Microsoft") && v.name.includes("Online") && v.lang.startsWith("en"),
        (v) => v.lang.startsWith("en-GB") && !v.localService,
        (v) => v.lang.startsWith("en-GB"),
        (v) => v.lang.startsWith("en") && !v.localService,
        (v) => v.lang.startsWith("en"),
      ]

      for (const test of ranked) {
        const match = voices.find(test)
        if (match) {
          this.preferredVoice = match
          return
        }
      }
    }

    pickBest()

    if (!this.preferredVoice) {
      window.speechSynthesis.onvoiceschanged = () => pickBest()
    }
  }

  setupObserver() {
    if (!this.observeMutationsValue) return

    const container = document.getElementById("in-progress-cards")
    if (!container) return

    this.observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          this.handleAddedNode(node)
        }
      }
    })

    this.observer.observe(container, { childList: true })
  }

  handleAddedNode(node) {
    if (!this.enabled) return
    if (node.nodeType !== Node.ELEMENT_NODE) return

    const frame = node.matches?.("turbo-frame") ? node : node.querySelector?.("turbo-frame")
    if (frame?.getAttribute("data-skeleton") === "true") return

    const card = node.querySelector?.("[data-request-id]") || node
    const visibleTarget = card.closest?.("turbo-frame") || card
    if (visibleTarget.style.display === "none") return

    const queueNumber = this.extractQueueNumber(node)
    if (queueNumber) {
      this.announce(queueNumber)
    }
  }

  extractQueueNumber(node) {
    const el = node.querySelector?.("[data-queue-number]")
    if (el) return el.getAttribute("data-queue-number")

    if (node.getAttribute?.("data-queue-number")) {
      return node.getAttribute("data-queue-number")
    }

    return null
  }

  announce(queueNumber) {
    this.playChime().then(() => {
      this.speak(`Now calling, number ${queueNumber}`)
    })
  }

  recall(event) {
    const queueNumber = event.currentTarget.dataset.queueNumber
    if (!queueNumber) return

    // Always announce on manual recall, even when auto-announce is off.
    this.playChime().then(() => {
      this.speak(`Now calling, number ${queueNumber}.`)
    })
  }

  playChime() {
    return new Promise((resolve) => {
      try {
        const ctx = new (window.AudioContext || window.webkitAudioContext)()
        const now = ctx.currentTime

        const osc1 = ctx.createOscillator()
        const gain1 = ctx.createGain()
        osc1.type = "sine"
        osc1.frequency.value = 880
        gain1.gain.setValueAtTime(0.3, now)
        gain1.gain.exponentialRampToValueAtTime(0.01, now + 0.6)
        osc1.connect(gain1)
        gain1.connect(ctx.destination)
        osc1.start(now)
        osc1.stop(now + 0.6)

        const osc2 = ctx.createOscillator()
        const gain2 = ctx.createGain()
        osc2.type = "sine"
        osc2.frequency.value = 660
        gain2.gain.setValueAtTime(0.3, now + 0.3)
        gain2.gain.exponentialRampToValueAtTime(0.01, now + 1.0)
        osc2.connect(gain2)
        gain2.connect(ctx.destination)
        osc2.start(now + 0.3)
        osc2.stop(now + 1.0)

        setTimeout(() => {
          ctx.close()
          resolve()
        }, 1000)
      } catch {
        resolve()
      }
    })
  }

  speak(text) {
    if (!window.speechSynthesis) return

    window.speechSynthesis.cancel()

    const utterance = new SpeechSynthesisUtterance(text)
    if (this.preferredVoice) {
      utterance.voice = this.preferredVoice
    }
    utterance.lang = "en-GB"
    utterance.rate = 0.85
    utterance.pitch = 1.0
    utterance.volume = 1.0
    window.speechSynthesis.speak(utterance)
  }

  toggle() {
    this.enabled = !this.enabled
    localStorage.setItem(this.constructor.STORAGE_KEY, this.enabled.toString())
    this.updateToggleUI()
  }

  updateToggleUI() {
    if (!this.hasToggleBtnTarget) return

    if (this.enabled) {
      this.toggleBtnTarget.classList.remove("btn-error", "btn-outline")
      this.toggleBtnTarget.classList.add("btn-info")
      this.toggleBtnTarget.title = "Voice announcements on"
      if (this.hasToggleIconTarget) this.toggleIconTarget.textContent = "volume_up"
      if (this.hasToggleLabelTarget) this.toggleLabelTarget.textContent = "Voice on"
    } else {
      this.toggleBtnTarget.classList.remove("btn-info")
      this.toggleBtnTarget.classList.add("btn-outline", "btn-error")
      this.toggleBtnTarget.title = "Voice announcements off"
      if (this.hasToggleIconTarget) this.toggleIconTarget.textContent = "volume_off"
      if (this.hasToggleLabelTarget) this.toggleLabelTarget.textContent = "Voice off"
    }
  }
}
