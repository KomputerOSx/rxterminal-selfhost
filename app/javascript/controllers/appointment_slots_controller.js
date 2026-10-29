import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["serviceSelect", "dateInput", "timeInput", "slotsContainer", "excludeId"]
  static values = {
    slotsUrl: String
  }

  connect() {
    this.loadSlots()
  }

  serviceChanged() {
    this.loadSlots()
  }

  dateChanged() {
    this.loadSlots()
  }

  selectSlot(event) {
    event.preventDefault()
    const time = event.currentTarget.dataset.time
    if (!time || !this.hasTimeInputTarget) return

    this.timeInputTarget.value = time
    const label = this.element.querySelector("[data-appointment-slots-target='timeLabel']")
    if (label) label.textContent = time
    this.highlightSelectedSlot(time)
  }

  async loadSlots() {
    if (!this.hasSlotsContainerTarget || !this.hasServiceSelectTarget || !this.hasDateInputTarget) return

    const serviceId = this.serviceSelectTarget.value
    const date = this.dateInputTarget.value
    if (!serviceId || !date) {
      this.slotsContainerTarget.innerHTML = ""
      return
    }

    const url = new URL(this.slotsUrlValue, window.location.origin)
    url.searchParams.set("service_id", serviceId)
    url.searchParams.set("date", date)
    if (this.hasExcludeIdTarget && this.excludeIdTarget.value) {
      url.searchParams.set("exclude_id", this.excludeIdTarget.value)
    }
    if (this.hasTimeInputTarget && this.timeInputTarget.value) {
      url.searchParams.set("selected_time", this.timeInputTarget.value)
    }

    const response = await fetch(url, {
      headers: { Accept: "text/html" }
    })

    if (response.ok) {
      this.slotsContainerTarget.innerHTML = await response.text()
    }
  }

  highlightSelectedSlot(time) {
    this.slotsContainerTarget.querySelectorAll("[data-time]").forEach((button) => {
      button.classList.toggle("btn-primary", button.dataset.time === time)
      button.classList.toggle("btn-outline", button.dataset.time !== time)
    })
  }
}
