import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "step", "stepIndicator",
    "serviceSelect", "calendarFrame", "slotsFrame",
    "selectedDate", "selectedSlot", "selectedSlotDisplay",
    "eligibilityPanel",
    "dateError", "slotError",
    "detailsError",
    "reviewService", "reviewDate", "reviewTime",
    "reviewName", "reviewDob", "reviewPostcode", "reviewEmail", "reviewNotes",
    "formDate", "formSlot", "submitBtn",
  ]

  static values = {
    calendarUrl: String,
    slotsUrl: String,
    step: { type: Number, default: 0 },
    hasErrors: { type: Boolean, default: false },
    errorStep: { type: Number, default: 0 },
    eligibilityData: { type: Object, default: {} },
  }

  connect() {
    this.#showStep(this.hasErrorsValue ? this.errorStepValue : this.stepValue)
    const preserveCalendar = this.hasErrorsValue &&
      this.hasSelectedDateTarget &&
      this.selectedDateTarget.value
    if (this.hasCalendarFrameTarget && !preserveCalendar) this.#loadCalendar()
    this.#renderEligibility()
  }

  nextStep(event) {
    event.preventDefault()
    if (!this.#validateCurrentStep()) return
    this.#showStep(this.stepValue + 1)
  }

  prevStep(event) {
    event.preventDefault()
    this.#showStep(this.stepValue - 1)
  }

  prevMonth(event) {
    event.preventDefault()
    if (event.currentTarget.disabled) return
    const current = this.#currentMonth()
    const prev = new Date(current.getFullYear(), current.getMonth() - 1, 1)
    this.#loadCalendar(prev)
  }

  nextMonth(event) {
    event.preventDefault()
    if (event.currentTarget.disabled) return
    const current = this.#currentMonth()
    const next = new Date(current.getFullYear(), current.getMonth() + 1, 1)
    this.#loadCalendar(next)
  }

  selectDate(event) {
    const btn = event.currentTarget
    if (btn.dataset.disabled === "true") return

    this.calendarFrameTarget.querySelectorAll("button[data-date]").forEach(b => {
      b.classList.remove("bg-primary", "text-primary-content", "font-bold")
      b.classList.add("hover:bg-base-200")
    })
    btn.classList.add("bg-primary", "text-primary-content", "font-bold")
    btn.classList.remove("hover:bg-base-200")

    const date = btn.dataset.date
    this.selectedDateTarget.value = date
    if (this.hasFormDateTarget) this.formDateTarget.value = date

    this.#loadSlots(date)
    this.#clearError(this.dateErrorTarget)
  }

  async serviceChanged() {
    this.#renderEligibility()
    await this.#loadCalendar(this.#currentMonth())

    const date = this.hasSelectedDateTarget ? this.selectedDateTarget.value : ""
    if (!date) return

    const dateButton = this.calendarFrameTarget.querySelector(`button[data-date="${date}"]`)
    if (dateButton && dateButton.dataset.disabled !== "true") {
      this.#loadSlots(date)
    } else {
      this.selectedDateTarget.value = ""
      if (this.hasFormDateTarget) this.formDateTarget.value = ""
      if (this.hasSlotsFrameTarget) this.slotsFrameTarget.innerHTML = ""
    }
  }

  selectSlot(event) {
    const btn = event.currentTarget
    if (btn.dataset.taken === "true") return

    this.slotsFrameTarget.querySelectorAll("button[data-slot]").forEach(b => {
      b.classList.remove("bg-primary", "text-primary-content")
      b.classList.add("border-base-300", "hover:border-primary")
    })
    btn.classList.add("bg-primary", "text-primary-content")
    btn.classList.remove("border-base-300", "hover:border-primary")

    const slot = btn.dataset.slot
    this.selectedSlotTarget.value = slot
    if (this.hasFormSlotTarget) this.formSlotTarget.value = slot
    if (this.hasSelectedSlotDisplayTarget) this.selectedSlotDisplayTarget.textContent = btn.textContent.trim()
    this.#clearError(this.slotErrorTarget)
  }

  submit(event) {
    if (!this.#validateCurrentStep()) {
      event.preventDefault()
    }
  }

  #showStep(idx) {
    const steps = this.stepTargets
    idx = Math.max(0, Math.min(idx, steps.length - 1))
    this.stepValue = idx

    steps.forEach((el, i) => {
      el.classList.toggle("hidden", i !== idx)
    })

    if (this.hasStepIndicatorTarget) {
      this.stepIndicatorTargets.forEach((el, i) => {
        el.classList.toggle("bg-primary", i === idx)
        el.classList.toggle("text-primary-content", i === idx)
        el.classList.toggle("bg-base-300", i !== idx)
        el.classList.toggle("text-base-content/60", i !== idx)
      })
    }

    if (idx === this.stepTargets.length - 1) this.#populateReview()
    window.scrollTo({ top: 0, behavior: "smooth" })
  }

  #validateCurrentStep() {
    const step = this.stepValue

    if (step === 0) {
      const date = this.hasSelectedDateTarget ? this.selectedDateTarget.value : ""
      const slot = this.hasSelectedSlotTarget ? this.selectedSlotTarget.value : ""

      if (!date) {
        if (this.hasDateErrorTarget) this.dateErrorTarget.textContent = "Please select a date."
        return false
      }
      if (!slot) {
        if (this.hasSlotErrorTarget) this.slotErrorTarget.textContent = "Please select a time slot."
        return false
      }
    }

    if (step === 1) {
      const form = this.element.querySelector("form")
      if (!form) return true

      const required = [
        { name: "first_name", label: "First name" },
        { name: "last_name",  label: "Last name" },
        { name: "dob",        label: "Date of birth" },
        { name: "postcode",   label: "Postcode" },
      ].filter(({ name }) => !!form.querySelector(`[name="appointment[${name}]"]`)?.required)

      let valid = true
      required.forEach(({ name, label }) => {
        const field = form.querySelector(`[name="appointment[${name}]"]`)
        if (!field) return
        this.#clearFieldError(field)
        if (!field.value.trim()) {
          this.#showFieldError(field, `${label} is required.`)
          valid = false
        }
      })

      const emailField = form.querySelector('[name="appointment[email]"]')
      if (emailField) {
        this.#clearFieldError(emailField)
        const email = emailField.value.trim()
        if (!email && emailField.required) {
          this.#showFieldError(emailField, "Email is required.")
          valid = false
        } else if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
          this.#showFieldError(emailField, "Please enter a valid email address.")
          valid = false
        }
      }

      if (!valid) {
        form.querySelector("[data-field-error]")?.scrollIntoView({ behavior: "smooth", block: "center" })
      }

      return valid
    }

    return true
  }

  #populateReview() {
    const form = this.element.querySelector("form")
    if (!form) return

    const val = (name) => form.querySelector(`[name="appointment[${name}]"]`)?.value || ""
    const display = (target, value) => { if (this[`has${this.#cap(target)}Target`]) this[`${target}Target`].textContent = value }

    const serviceEl = form.querySelector(`[name="appointment[service_id]"] option:checked`)
    display("reviewService", serviceEl?.textContent || "")

    const rawDate = val("appointment_date")
    if (rawDate) {
      const [y, m, d] = rawDate.split("-").map(Number)
      display("reviewDate", new Date(y, m - 1, d).toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long", year: "numeric" }))
    }

    display("reviewTime", this.#formatSlotTime(val("appointment_time")))
    display("reviewName", [val("first_name"), val("last_name")].filter(Boolean).join(" "))

    const rawDob = val("dob")
    if (rawDob) {
      const parts = rawDob.split("-").map(Number)
      const dobDate = parts[0] > 31
        ? new Date(parts[0], parts[1] - 1, parts[2])
        : new Date(parts[2], parts[1] - 1, parts[0])
      display("reviewDob", dobDate.toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric" }))
    }

    display("reviewPostcode", val("postcode") || "Not provided")
    display("reviewEmail", val("email") || "Not provided")
    display("reviewNotes", val("notes") || "None")
  }

  #cap(str) { return str.charAt(0).toUpperCase() + str.slice(1) }

  // Matches Public::AppointmentsHelper#portal_slot_label ("%-l:%M%P"), so the review step
  // shows the same 12-hour format the slot picker used one step earlier.
  #formatSlotTime(value) {
    const match = /^(\d{2}):(\d{2})/.exec(value || "")
    if (!match) return ""

    const hours = Number(match[1])
    const period = hours >= 12 ? "pm" : "am"
    const hour12 = hours % 12 || 12
    return `${hour12}:${match[2]}${period}`
  }

  #currentMonth() {
    const frame = this.hasCalendarFrameTarget ? this.calendarFrameTarget : null
    const btn = frame?.querySelector("button[data-date]")
    if (btn) {
      const d = new Date(btn.dataset.date)
      return new Date(d.getFullYear(), d.getMonth(), 1)
    }
    return new Date(new Date().getFullYear(), new Date().getMonth(), 1)
  }

  async #loadCalendar(month = null) {
    if (!this.hasCalendarFrameTarget) return
    const d = month || new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    const monthStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`
    const params = new URLSearchParams({ month: monthStr })
    if (this.hasServiceSelectTarget && this.serviceSelectTarget.value) params.set("service_id", this.serviceSelectTarget.value)
    if (this.hasSelectedDateTarget && this.selectedDateTarget.value) params.set("selected_date", this.selectedDateTarget.value)
    const url = `${this.calendarUrlValue}?${params}`
    const res = await fetch(url, { headers: { Accept: "text/html" } })
    if (res.ok) this.calendarFrameTarget.innerHTML = await res.text()
  }

  async #loadSlots(date) {
    if (!this.hasSlotsFrameTarget) return
    const serviceId = this.hasServiceSelectTarget ? this.serviceSelectTarget.value : ""
    const url = `${this.slotsUrlValue}?date=${date}&service_id=${serviceId}`
    const res = await fetch(url, { headers: { Accept: "text/html" } })
    if (res.ok) this.slotsFrameTarget.innerHTML = await res.text()
  }

  #renderEligibility() {
    if (!this.hasEligibilityPanelTarget) return
    const panel = this.eligibilityPanelTarget
    const serviceId = this.hasServiceSelectTarget ? this.serviceSelectTarget.value : ""
    const req = serviceId ? (this.eligibilityDataValue[serviceId] || null) : null

    if (!req) { panel.innerHTML = ""; panel.classList.add("hidden"); return }

    const eligible   = (req["eligible"]    || []).filter(Boolean)
    const notEligible = (req["not_eligible"] || []).filter(Boolean)
    const additional = (req["additional"]  || []).filter(Boolean)

    if (!eligible.length && !notEligible.length && !additional.length) {
      panel.innerHTML = ""; panel.classList.add("hidden"); return
    }

    const section = (items, label, badgeClass) => {
      if (!items.length) return ""
      return `
        <div class="card border border-base-300">
          <div class="card-body gap-2 p-4">
            <span class="badge ${badgeClass} badge-sm">${label}</span>
            <ul class="list-disc list-inside text-sm space-y-1 text-base-content/80">
              ${items.map(i => `<li>${i}</li>`).join("")}
            </ul>
          </div>
        </div>`
    }

    panel.innerHTML = `
      <div class="space-y-3">
        ${section(eligible, "Eligible if", "badge-success")}
        ${section(notEligible, "Not eligible if", "badge-error")}
        ${section(additional, "Additional information", "badge-info")}
      </div>`
    panel.classList.remove("hidden")
  }

  #clearError(el) {
    if (el) el.textContent = ""
  }

  #showFieldError(field, message) {
    field.classList.add("error")
    const err = document.createElement("p")
    err.className = "text-error text-sm mt-1"
    err.dataset.fieldError = "true"
    err.textContent = message
    field.closest(".form-control")?.appendChild(err)
  }

  #clearFieldError(field) {
    field.classList.remove("error")
    field.closest(".form-control")?.querySelectorAll("[data-field-error]").forEach(el => el.remove())
  }
}
