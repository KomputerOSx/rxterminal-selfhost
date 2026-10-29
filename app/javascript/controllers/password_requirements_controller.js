import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["password", "confirmation", "item"]
  static values = {
    minLength: { type: Number, default: 8 }
  }

  connect() {
    this.check()
  }

  check() {
    const password = this.passwordTarget.value
    const confirmation = this.hasConfirmationTarget ? this.confirmationTarget.value : ""
    const checks = this.#checks(password, confirmation)
    const passwordActive = password.length > 0
    const confirmationActive = confirmation.length > 0

    this.itemTargets.forEach((item) => {
      const key = item.dataset.requirement
      const met = checks[key]
      let state = "neutral"

      if (key === "confirmation_match") {
        if (passwordActive && confirmationActive) {
          state = met ? "met" : "failed"
        }
      } else if (passwordActive) {
        state = met ? "met" : "failed"
      }

      item.classList.remove(
        "border-success/40", "bg-success/10", "text-success",
        "border-error/40", "bg-error/10", "text-error",
        "border-base-300/70", "bg-transparent", "text-base-content/45"
      )

      if (state === "met") {
        item.classList.add("border-success/40", "bg-success/10", "text-success")
      } else if (state === "failed") {
        item.classList.add("border-error/40", "bg-error/10", "text-error")
      } else {
        item.classList.add("border-base-300/70", "bg-transparent", "text-base-content/45")
      }

      const icon = item.querySelector("[data-icon]")
      if (icon) {
        icon.textContent = state === "met" ? "check_circle" : state === "failed" ? "cancel" : "radio_button_unchecked"
      }
    })
  }

  #checks(password, confirmation) {
    const lower = password.toLowerCase()

    return {
      min_length: password.length >= this.minLengthValue,
      lowercase: /[a-z]/.test(password),
      uppercase: /[A-Z]/.test(password),
      digit: /\d/.test(password),
      no_common: password.length > 0 && !this.#commonPassword(password) && !this.#commonWord(lower),
      no_sequential: password.length > 0 && !this.#sequential(lower),
      no_repeated: password.length > 0 && !this.#repeated(password),
      no_keyboard: password.length > 0 && !this.#keyboard(lower),
      confirmation_match: password.length > 0 && confirmation.length > 0 && password === confirmation
    }
  }

  #commonPassword(password) {
    return [
      "password", "password123", "12345678", "qwerty123", "admin123",
      "welcome1", "letmein1", "Password1", "Qwerty123", "Admin123",
      "pass123", "passw0rd", "Passw0rd", "Welcome123"
    ].some((candidate) => password.toLowerCase() === candidate.toLowerCase())
  }

  #commonWord(lower) {
    return ["password", "pass", "admin", "welcome", "letmein"].some((word) => lower.includes(word))
  }

  #sequential(lower) {
    return /012|123|234|345|456|567|678|789|890/.test(lower) ||
      /abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz/.test(lower) ||
      /987|876|765|654|543|432|321|210/.test(lower)
  }

  #repeated(password) {
    return /(.)\1{2,}/.test(password)
  }

  #keyboard(lower) {
    return [
      "qwerty", "qwertyui", "asdfgh", "asdfghjk", "zxcvbn", "zxcvbnm",
      "qwert", "asdf", "zxcv", "1qaz", "2wsx",
      "!qaz", "@wsx"
    ].some((pattern) => lower.includes(pattern))
  }
}
