import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.#days().forEach((day) => {
      const checkbox = this.#activeCheckbox(day)
      if (checkbox) this.#toggleDay(checkbox)
    })
  }

  openChanged(event) {
    const checkbox = event.target
    const day = checkbox.dataset.bookableDay
    const bookable = checkbox.checked

    this.#checkboxes(day).forEach((input) => {
      input.checked = bookable
    })

    this.#toggleDay(checkbox)
  }

  #days() {
    return [ ...new Set([ ...this.element.querySelectorAll("[data-day]") ].map((row) => row.dataset.day)) ]
  }

  #checkboxes(day) {
    return this.element.querySelectorAll(`[data-bookable-day='${day}']`)
  }

  #activeCheckbox(day) {
    const bookable = this.#checkboxes(day)[0]?.checked
    const role = bookable ? "interval" : "no-booking"
    return this.element.querySelector(`[data-day='${day}'][data-bookable-times-role='${role}'] [data-bookable-day='${day}']`)
  }

  #toggleDay(checkbox) {
    const day = checkbox.dataset.bookableDay
    const bookable = checkbox.checked

    this.element.querySelectorAll(`[data-day='${day}'][data-bookable-times-role='no-booking']`).forEach((row) => {
      row.classList.toggle("hidden", bookable)
    })
    this.element.querySelectorAll(`[data-day='${day}'][data-bookable-times-role='interval']`).forEach((row) => {
      row.classList.toggle("hidden", !bookable)
    })
    this.element.querySelectorAll(`[data-day='${day}'] input[type='time']`).forEach((input) => {
      input.disabled = !bookable
    })

    this.#checkboxes(day).forEach((input) => {
      const onNoBookingRow = input.closest("[data-bookable-times-role='no-booking']")
      input.disabled = bookable ? onNoBookingRow !== null : onNoBookingRow === null
    })
  }
}
