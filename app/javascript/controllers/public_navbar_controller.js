import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "button", "icon", "menu"]

  connect() {
    this.sync()
  }

  toggle(event) {
    event.preventDefault()

    if (this.element.open) {
      this.animateClose()
    } else {
      this.element.open = true
      this.sync()
      this.animateOpen()
    }
  }

  sync() {
    const open = this.element.open

    this.iconTarget.textContent = open ? "close" : "menu"
    this.buttonTarget.setAttribute("aria-expanded", String(open))
    this.buttonTarget.setAttribute("aria-label", open ? "Close menu" : "Open menu")
  }

  close(event) {
    if (this.element.open && !this.element.contains(event.target)) {
      this.animateClose()
    }
  }

  dismiss() {
    this.animateClose()
  }

  animateOpen() {
    if (this.reducedMotion) return

    this.cancelAnimations()
    this.backdropTarget.animate(
      [{ opacity: 0 }, { opacity: 1 }],
      { duration: 180, easing: "ease-out" }
    )
    this.menuTarget.animate(
      [
        { opacity: 0, transform: "translateY(-8px) scaleY(0.97)" },
        { opacity: 1, transform: "translateY(0) scaleY(1)" }
      ],
      { duration: 180, easing: "ease-out" }
    )
  }

  async animateClose() {
    if (this.closing) return

    if (this.reducedMotion) {
      this.finishClose()
      return
    }

    this.closing = true
    this.cancelAnimations()

    this.backdropTarget.animate(
      [{ opacity: 1 }, { opacity: 0 }],
      { duration: 140, easing: "ease-in" }
    )
    const animation = this.menuTarget.animate(
      [
        { opacity: 1, transform: "translateY(0) scaleY(1)" },
        { opacity: 0, transform: "translateY(-8px) scaleY(0.97)" }
      ],
      { duration: 140, easing: "ease-in" }
    )

    try {
      await animation.finished
      this.finishClose()
    } catch {
      this.closing = false
    }
  }

  finishClose() {
    this.element.open = false
    this.closing = false
    this.sync()
  }

  cancelAnimations() {
    this.menuTarget.getAnimations().forEach((animation) => animation.cancel())
    this.backdropTarget.getAnimations().forEach((animation) => animation.cancel())
  }

  get reducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
