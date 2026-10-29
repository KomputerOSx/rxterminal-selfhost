import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["acceptBtn", "declineBtn", "bookLaterBtn"]

  press(event) {
    const btn = event.currentTarget
    btn.classList.remove("kiosk-upsell-pressing")
    void btn.offsetWidth
    btn.classList.add("kiosk-upsell-pressing")
  }

  confirmAccept() {
    this.#lockUI(this.acceptBtnTarget, "Confirming…")
  }

  confirmDecline() {
    this.#lockUI(this.declineBtnTarget, "Please wait…")
  }

  confirmBookLater() {
    if (this.hasBookLaterBtnTarget) {
      this.#lockUI(this.bookLaterBtnTarget, "Opening booking…")
    }
  }

  #lockUI(activeBtn, label) {
    this.#allButtons().forEach((btn) => {
      btn.disabled = true
      btn.classList.remove("kiosk-upsell-cta-btn--pulse", "kiosk-upsell-pressing")
    })

    this.#allButtons().forEach((btn) => {
      if (btn !== activeBtn) btn.classList.add("kiosk-upsell-btn--dimmed")
    })

    activeBtn.innerHTML =
      `<span class="material-symbols-outlined kiosk-upsell-spinner animate-spin">progress_activity</span> ${label}`
  }

  #allButtons() {
    return [
      this.acceptBtnTarget,
      this.declineBtnTarget,
      this.hasBookLaterBtnTarget ? this.bookLaterBtnTarget : null
    ].filter(Boolean)
  }
}
