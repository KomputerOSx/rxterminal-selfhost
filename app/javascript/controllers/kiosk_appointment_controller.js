import { Controller } from "@hotwired/stimulus"
import { showPanelImmediate, transitionPanels } from "kiosk/panel_transitions"

const DOB_FIELDS = [
  { maxLen: 2, max: 31,   min: 1,    placeholder: "DD"   },
  { maxLen: 2, max: 12,   min: 1,    placeholder: "MM"   },
  { maxLen: 4, max: 2099, min: 1900, placeholder: "YYYY" },
]

const POSTCODE_FORMATS = {
  uk: { re: /^([A-Z]{1,2}[0-9][0-9A-Z]?)\s?([0-9][A-Z]{2})$/i, min: 5, max: 8,  numeric: false, errorMsg: "Invalid UK postcode - please check" },
  us: { re: /^\d{5}$/,                                             min: 5, max: 5,  numeric: true,  errorMsg: "Invalid ZIP code - must be 5 digits" },
  ca: { re: /^[ABCEGHJ-NPRSTVXY]\d[ABCEGHJ-NPRSTV-Z]\s?\d[ABCEGHJ-NPRSTV-Z]\d$/i, min: 6, max: 7, numeric: false, errorMsg: "Invalid Canadian postal code" },
  au: { re: /^\d{4}$/,                                             min: 4, max: 4,  numeric: true,  errorMsg: "Invalid postcode - must be 4 digits" },
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/

export default class extends Controller {
  static targets = [
    "eligibilityPanel", "appointmentPanel", "namePanel", "dobPanel", "postcodePanel",
    "emailPanel", "notesPanel", "confirmPanel",
    "apptSubtitle", "apptCalendarView", "apptCalendarFrame", "apptCalGrid",
    "apptTimeView", "apptTimeContent", "apptSlotGrid", "apptConfirmBtn",
    "firstDisplay", "lastDisplay", "firstWrap", "lastWrap",
    "ddDisplay", "mmDisplay", "yyyyDisplay", "ddWrap", "mmWrap", "yyyyWrap",
    "postcodeField", "postcodeEmpty", "postcodeFilledDisplay",
    "postcodeOutwardText", "postcodeError", "postcodeConfirmBtn",
    "emailField", "emailDisplay", "emailLabel", "emailErrorMsg",
    "emailConfirmBtn", "emailSkippedView", "emailKeyboardView", "emailChip",
    "notesDisplay", "notesCharCount",
    "apptError", "confirmError",
    "confirmDate", "confirmTime",
    "confirmFirstName", "confirmLastName", "confirmDob", "confirmPostcode",
    "confirmEmail", "confirmNotes",
    "submitBtn",
  ]

  static values = {
    calendarUrl:    String,
    serviceId:      Number,
    submitUrl:      String,
    slotsUrl:       String,
    initialMonth:   String,
    hasEligibility: Boolean,
    homeUrl:        String,
    startStep:      String,
    upsellBooking:  Boolean,
    prefillFirstName: String,
    prefillLastName:  String,
    prefillDob:       String,
    prefillPostcode:  String,
    postcodeRegion:   { type: String, default: "uk" },
  }

  #today = null
  #apptDate = null
  #apptSlot = null
  #apptStep = "date"
  #apptViewDate = null
  #firstName = ""
  #lastName = ""
  #nameField = "first"
  #dob = ["", "", ""]
  #dobActive = 0
  #dobErrorIdx = null
  #dobShakeTimer = null
  #dobErrTimer = null
  #postcode = ""
  #postcodeErrorMsg = null
  #postcodeShakeTimer = null
  #postcodeErrTimer = null
  #email = ""
  #emailSkipped = false
  #emailErrMsg = null
  #emailShakeTimer = null
  #emailErrTimer = null
  #notes = ""
  #notesSkipped = false
  #submitError = null

  connect() {
    const now = new Date()
    now.setHours(0, 0, 0, 0)
    this.#today = now
    const [initialYear, initialMonth] = (this.initialMonthValue || "").split("-").map(Number)
    this.#apptViewDate = initialYear && initialMonth
      ? new Date(initialYear, initialMonth - 1, 1)
      : new Date(now.getFullYear(), now.getMonth(), 1)

    this._onCalPress = (e) => this.#onCalPress(e)
    this._onSlotPress = (e) => this.#onSlotPress(e)
    this.apptCalendarFrameTarget.addEventListener("pointerdown", this._onCalPress)
    this.apptTimeContentTarget.addEventListener("pointerdown", this._onSlotPress)

    this.#applyPrefills()
    const startStep = this.startStepValue || (this.hasEligibilityValue ? "eligibility" : "appointment")
    this.#showImmediate(startStep)
    this.#renderApptUI()
    this.#syncName()
    this.#syncDob()
    this.#updatePostcodeUI()
    this.#updateEmailUI()
    this.#syncNotes()
  }

  disconnect() {
    this.apptCalendarFrameTarget.removeEventListener("pointerdown", this._onCalPress)
    this.apptTimeContentTarget.removeEventListener("pointerdown", this._onSlotPress)
    clearTimeout(this.#dobShakeTimer)
    clearTimeout(this.#dobErrTimer)
    clearTimeout(this.#postcodeShakeTimer)
    clearTimeout(this.#postcodeErrTimer)
    clearTimeout(this.#emailShakeTimer)
    clearTimeout(this.#emailErrTimer)
  }

  eligibilityAccept(event) {
    this.#pressKey(event.currentTarget)
    setTimeout(() => this.#transition("eligibility", "appointment"), 140)
  }

  eligibilityDecline(event) {
    this.#pressKey(event.currentTarget)
    setTimeout(() => Turbo.visit(this.homeUrlValue), 140)
  }

  apptPrevMonth(event) {
    if (event.currentTarget.disabled) return
    this.#pressKey(event.currentTarget)
    const d = this.#apptViewDate
    this.#apptViewDate = new Date(d.getFullYear(), d.getMonth() - 1, 1)
    this.#fetchCalendar()
  }

  apptNextMonth(event) {
    if (event.currentTarget.disabled) return
    this.#pressKey(event.currentTarget)
    const d = this.#apptViewDate
    this.#apptViewDate = new Date(d.getFullYear(), d.getMonth() + 1, 1)
    this.#fetchCalendar()
  }

  apptBackToDate(event) {
    this.#pressKey(event.currentTarget)
    this.#clearSubmitError()
    this.#apptSlot = null
    this.#apptStep = "date"
    this.#renderApptUI()
    this.#renderApptConfirmBtn()
  }

  apptBack() {
    if (this.#apptStep === "time") {
      this.#apptSlot = null
      this.#apptStep = "date"
      this.#renderApptUI()
      this.#renderApptConfirmBtn()
    } else if (this.hasEligibilityValue && !this.upsellBookingValue) {
      this.#transition("appointment", "eligibility")
    } else {
      history.back()
    }
  }

  apptConfirm(event) {
    this.#pressKey(event.currentTarget)
    if (!this.#apptDate || !this.#apptSlot) return
    this.#transition("appointment", this.upsellBookingValue ? "email" : "name")
  }

  nameKey(event) {
    const key = event.currentTarget.dataset.key
    this.#pressKey(event.currentTarget)

    if (key === "⌫") {
      if (this.#nameField === "first") {
        this.#firstName = this.#firstName.slice(0, -1)
      } else if (this.#lastName.length === 0) {
        this.#nameField = "first"
      } else {
        this.#lastName = this.#lastName.slice(0, -1)
      }
    } else if (key === "→") {
      if (this.#nameField === "first" && this.#firstName.length > 0) {
        this.#nameField = "last"
      } else if (this.#nameField === "last" && this.#lastName.length > 0) {
        this.#transition("name", this.#afterName())
        return
      }
    } else {
      if (this.#nameField === "first" && this.#firstName.length < 30) {
        this.#firstName += key
      } else if (this.#nameField === "last" && this.#lastName.length < 30) {
        this.#lastName += key
      }
    }
    this.#syncName()
  }

  nameFocus(event) {
    this.#nameField = event.currentTarget.dataset.field
    this.#syncName()
  }

  nameReset() {
    this.#firstName = ""
    this.#lastName = ""
    this.#nameField = "first"
    this.#syncName()
  }

  nameBack() { this.#transition("name", "appointment") }

  dobKey(event) {
    const key = event.currentTarget.dataset.key
    this.#pressKey(event.currentTarget)

    if (key === "✓") { this.#handleDobConfirm(); return }

    if (key === "⌫") {
      clearTimeout(this.#dobErrTimer)
      this.#dobErrorIdx = null
      if (this.#dob[this.#dobActive].length > 0) {
        this.#dob[this.#dobActive] = this.#dob[this.#dobActive].slice(0, -1)
      } else if (this.#dobActive > 0) {
        this.#dobActive--
        this.#dob[this.#dobActive] = this.#dob[this.#dobActive].slice(0, -1)
      }
      this.#syncDob()
      return
    }

    if (!/^\d$/.test(key)) return

    const field = DOB_FIELDS[this.#dobActive]
    const cur = this.#dob[this.#dobActive]
    if (cur.length >= field.maxLen) { this.#triggerDobShake(this.#dobActive); return }

    const next = cur + key
    if (!this.#validateDobField(this.#dobActive, next)) { this.#triggerDobShake(this.#dobActive); return }

    clearTimeout(this.#dobErrTimer)
    this.#dobErrorIdx = null
    this.#dob[this.#dobActive] = next
    this.#syncDob()

    if (next.length === field.maxLen && this.#dobActive < 2) {
      setTimeout(() => { this.#dobActive++; this.#syncDob() }, 110)
    }
  }

  dobSegmentFocus(event) {
    this.#dobActive = parseInt(event.currentTarget.dataset.segment)
    this.#syncDob()
  }

  dobReset() {
    clearTimeout(this.#dobShakeTimer)
    clearTimeout(this.#dobErrTimer)
    this.#dob = ["", "", ""]
    this.#dobActive = 0
    this.#dobErrorIdx = null
    this.#syncDob()
  }

  dobBack() {
    clearTimeout(this.#dobShakeTimer)
    clearTimeout(this.#dobErrTimer)
    this.#dobErrorIdx = null
    this.#transition("dob", "name")
  }

  postcodeKey(event) {
    const key = event.currentTarget.dataset.key
    this.#pressKey(event.currentTarget)
    this.#postcodeErrorMsg = null

    if (key === "⌫") {
      this.#postcode = this.#postcode.slice(0, -1)
    } else if (key === "✓") {
      this.#handlePostcodeConfirm()
      return
    } else {
      const char = key.toUpperCase()
      const fmt = this.#fmt
      if (fmt.numeric ? !/^\d$/.test(char) : !/^[A-Z0-9]$/.test(char)) return
      if (this.#postcode.length >= fmt.max) { this.#triggerPostcodeShake(); return }
      this.#postcode += char
    }
    this.#updatePostcodeUI()
  }

  postcodeBack() {
    clearTimeout(this.#postcodeShakeTimer)
    clearTimeout(this.#postcodeErrTimer)
    this.#postcodeErrorMsg = null
    this.#transition("postcode", this.hasDobPanelTarget ? "dob" : "name")
  }

  postcodeReset() {
    clearTimeout(this.#postcodeShakeTimer)
    clearTimeout(this.#postcodeErrTimer)
    this.#postcode = ""
    this.#postcodeErrorMsg = null
    this.#updatePostcodeUI()
  }

  emailKey(event) {
    const key = event.currentTarget.dataset.key
    this.#pressKey(event.currentTarget)
    this.#emailErrMsg = null

    if (key === "⌫") {
      this.#email = this.#email.slice(0, -1)
    } else {
      const char = key.toLowerCase()
      if (this.#email.length >= 60) { this.#triggerEmailShake(); return }
      this.#email += char
    }
    this.#updateEmailUI()
  }

  emailChipPress(event) {
    this.#pressKey(event.currentTarget)
    const domain = event.currentTarget.dataset.domain
    const atIdx = this.#email.indexOf("@")
    const base = atIdx >= 0 ? this.#email.slice(0, atIdx) : this.#email
    this.#email = base + domain
    this.#emailErrMsg = null
    this.#updateEmailUI()
  }

  emailConfirm(event) {
    this.#pressKey(event.currentTarget)
    if (!this.#email.trim()) {
      this.#triggerEmailShake("Please enter your email address")
      return
    }
    if (!EMAIL_RE.test(this.#email)) {
      this.#triggerEmailShake("Invalid email - please check")
      return
    }
    this.#emailSkipped = false
    this.#transition("email", "notes")
  }

  emailSkip(event) {
    this.#pressKey(event.currentTarget)
    this.#emailSkipped = true
    this.#transition("email", "notes")
  }

  emailUnskip(event) {
    this.#pressKey(event.currentTarget)
    this.#emailSkipped = false
    this.#updateEmailUI()
  }

  emailReset() {
    clearTimeout(this.#emailShakeTimer)
    clearTimeout(this.#emailErrTimer)
    this.#email = ""
    this.#emailErrMsg = null
    this.#emailSkipped = false
    this.#updateEmailUI()
  }

  emailBack() {
    clearTimeout(this.#emailShakeTimer)
    clearTimeout(this.#emailErrTimer)
    this.#emailErrMsg = null
    if (this.upsellBookingValue) {
      this.#transition("email", "appointment")
    } else if (this.hasPostcodePanelTarget) {
      this.#transition("email", "postcode")
    } else if (this.hasDobPanelTarget) {
      this.#transition("email", "dob")
    } else {
      this.#transition("email", "name")
    }
  }

  notesKey(event) {
    const key = event.currentTarget.dataset.key
    this.#pressKey(event.currentTarget)

    if (key === "⌫") {
      this.#notes = this.#notes.slice(0, -1)
    } else if (key === "→") {
      this.#notesSkipped = false
      this.#populateConfirm()
      this.#transition("notes", "confirm")
      return
    } else {
      const char = key === "SPACE" ? " " : key
      if (this.#notes.length < 200) this.#notes += char
    }
    this.#syncNotes()
  }

  notesChipPress(event) {
    this.#pressKey(event.currentTarget)
    const note = event.currentTarget.dataset.note
    if (!note) return
    const separator = this.#notes.length > 0 ? ", " : ""
    const candidate = this.#notes + separator + note
    if (candidate.length <= 200) this.#notes = candidate
    this.#syncNotes()
  }

  notesSkip(event) {
    this.#pressKey(event.currentTarget)
    this.#notesSkipped = true
    this.#populateConfirm()
    this.#transition("notes", "confirm")
  }

  notesReset() {
    this.#notes = ""
    this.#syncNotes()
  }

  notesBack() { this.#transition("notes", "email") }

  confirmBack() { this.#transition("confirm", "notes") }

  async confirmSubmit() {
    const btn = this.submitBtnTarget
    this.#pressKey(btn)
    this.#clearSubmitError()
    this.#setLoading(btn, true)

    const [dd, mm, yyyy] = this.#dob
    const dob = this.hasDobPanelTarget ? `${yyyy}-${mm.padStart(2, "0")}-${dd.padStart(2, "0")}` : null

    try {
      const res = await fetch(this.submitUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        },
        body: JSON.stringify({
          appointment: {
            service_id: this.serviceIdValue,
            first_name: this.#firstName,
            last_name: this.#lastName,
            dob,
            postcode: this.hasPostcodePanelTarget ? this.#postcodeFormat(this.#postcode) : null,
            email: this.#emailSkipped ? null : (this.#email || null),
            appointment_date: this.#apptDate,
            appointment_time: this.#apptSlot,
            notes: this.#notesSkipped ? null : (this.#notes || null),
          },
        }),
      })

      const data = await res.json()
      if (!res.ok) {
        this.#setLoading(btn, false)
        this.#handleSubmitError(data)
        return
      }
      if (data.redirect_to) Turbo.visit(data.redirect_to)
    } catch {
      this.#showConfirmError("Could not complete your booking. Please try again.")
      this.#setLoading(btn, false)
    }
  }

  #renderApptUI() {
    const isDate = this.#apptStep === "date"
    const isTime = this.#apptStep === "time"

    this.apptCalendarViewTarget.classList.toggle("hidden", !isDate)
    this.apptTimeViewTarget.classList.toggle("hidden", !isTime)
    this.apptSubtitleTarget.textContent = isTime ? "Choose a time slot" : "Select a date"
    this.#renderApptError()

    if (isDate) this.#fetchCalendar()
    if (isTime) this.#renderApptConfirmBtn()
  }

  #onCalPress(e) {
    e.preventDefault()
    const btn = e.target.closest("[data-date]")
    if (!btn || btn.dataset.disabled === "true") return
    this.#pressKey(btn)
    this.#clearSubmitError()
    this.#apptDate = btn.dataset.date
    this.#apptSlot = null
    setTimeout(() => {
      this.#apptStep = "time"
      this.#renderApptUI()
      this.#renderApptConfirmBtn()
      this.#fetchSlots()
    }, 120)
  }

  async #fetchCalendar() {
    const url = new URL(this.calendarUrlValue, window.location.origin)
    url.searchParams.set("month", this.#monthParam())
    url.searchParams.set("service_id", this.serviceIdValue)
    if (this.#apptDate) url.searchParams.set("selected_date", this.#apptDate)

    try {
      const res = await fetch(url, { headers: { Accept: "text/html" } })
      if (!res.ok) return
      this.apptCalendarFrameTarget.innerHTML = await res.text()
    } catch {}
  }

  async #fetchSlots() {
    this.#showSlotsLoading()

    try {
      const url = new URL(this.slotsUrlValue, window.location.origin)
      url.searchParams.set("service_id", this.serviceIdValue)
      url.searchParams.set("date", this.#apptDate)
      const res = await fetch(url, { headers: { Accept: "text/html" } })
      if (!res.ok) throw new Error("slot fetch failed")
      this.apptTimeContentTarget.innerHTML = await res.text()
      this.#syncSlotButtons()
      this.#renderApptConfirmBtn()
    } catch {
      this.apptTimeContentTarget.innerHTML =
        `<div class="rounded-2xl border border-error/30 bg-error/10 p-8 text-center font-semibold text-error">Could not load slots. Please try again.</div>`
    }
  }

  #showSlotsLoading() {
    this.apptTimeContentTarget.innerHTML = `
      <div class="flex flex-col gap-5">
        <div class="rounded-2xl border border-primary/30 bg-primary/10 p-5">
          <div class="skeleton h-3 w-28 rounded"></div>
          <div class="skeleton mt-2 h-8 w-56 max-w-full rounded"></div>
          <div class="skeleton mt-1 h-4 w-12 rounded"></div>
        </div>
        <div class="grid grid-cols-3 gap-2 sm:grid-cols-4 md:grid-cols-6">
          ${"<div class=\"skeleton h-14 rounded-xl\"></div>".repeat(12)}
        </div>
      </div>`
  }

  #onSlotPress(e) {
    e.preventDefault()
    const btn = e.target.closest("[data-slot]")
    if (!btn || btn.dataset.taken === "true") return
    this.#pressKey(btn)
    this.#clearSubmitError()
    this.#apptSlot = btn.dataset.slot
    this.#syncSlotButtons()
    this.#renderApptConfirmBtn()
  }

  #syncSlotButtons() {
    this.apptTimeContentTarget.querySelectorAll("[data-slot]").forEach((slotButton) => {
      const selected = this.#apptSlot === slotButton.dataset.slot
      const taken = slotButton.dataset.taken === "true"
      slotButton.dataset.selected = selected ? "true" : "false"
      slotButton.classList.toggle("btn-primary", selected)
      slotButton.classList.toggle("btn-outline", !selected && !taken)
    })
  }

  #renderApptConfirmBtn() {
    const btn = this.apptConfirmBtnTarget
    const ready = Boolean(this.#apptSlot)
    btn.dataset.active = ready ? "true" : "false"
    btn.classList.toggle("btn-primary", ready)
    btn.classList.toggle("btn-disabled", !ready)
    if (ready) {
      btn.innerHTML =
        `<span class="material-symbols-outlined">check</span> Confirm ${this.#fmtSlot(this.#apptSlot)}`
    } else {
      btn.textContent = "Select a time above"
    }
  }

  #monthParam() {
    return `${this.#apptViewDate.getFullYear()}-${String(this.#apptViewDate.getMonth() + 1).padStart(2, "0")}`
  }

  #fmtSlot(s) {
    if (!s) return ""
    const [h, m] = s.split(":").map(Number)
    const suffix = h >= 12 ? "pm" : "am"
    const hour = h > 12 ? h - 12 : h === 0 ? 12 : h
    return `${hour}:${String(m).padStart(2, "0")}${suffix}`
  }

  #syncName() {
    this.firstDisplayTarget.textContent = this.#firstName || "·"
    this.lastDisplayTarget.textContent = this.#lastName || "·"
    this.firstWrapTarget.dataset.active = this.#nameField === "first" ? "true" : "false"
    this.lastWrapTarget.dataset.active = this.#nameField === "last" ? "true" : "false"
  }

  #applyPrefills() {
    this.#firstName = this.prefillFirstNameValue || ""
    this.#lastName = this.prefillLastNameValue || ""

    if (this.prefillDobValue) {
      const parts = this.prefillDobValue.split("-")
      if (parts.length === 3) this.#dob = [parts[2], parts[1], parts[0]]
    }

    if (this.hasPostcodePanelTarget) {
      this.#postcode = (this.prefillPostcodeValue || "").replace(/\s+/g, "").toUpperCase()
    }
  }

  #validateDobField(idx, val) {
    const num = parseInt(val, 10)
    if (isNaN(num)) return true
    const field = DOB_FIELDS[idx]
    if (val.length === field.maxLen && (num < field.min || num > field.max)) return false
    if (idx === 0 && val.length === 1 && num > 3) return false
    if (idx === 1 && val.length === 1 && num > 1) return false
    return true
  }

  #handleDobConfirm() {
    const firstIncomplete = this.#dob.findIndex((val, i) => val.length < DOB_FIELDS[i].maxLen)
    if (firstIncomplete !== -1) {
      this.#dobActive = firstIncomplete
      this.#triggerDobShake(firstIncomplete)
      return
    }
    this.#transition("dob", this.hasPostcodePanelTarget ? "postcode" : "email")
  }

  #triggerDobShake(idx) {
    this.#dobErrorIdx = idx
    this.#syncDob()
    const wraps = [this.ddWrapTarget, this.mmWrapTarget, this.yyyyWrapTarget]
    const el = wraps[idx]
    el.classList.remove("kiosk-shake")
    void el.offsetWidth
    el.classList.add("kiosk-shake")
    clearTimeout(this.#dobShakeTimer)
    this.#dobShakeTimer = setTimeout(() => el.classList.remove("kiosk-shake"), 450)
    clearTimeout(this.#dobErrTimer)
    this.#dobErrTimer = setTimeout(() => { this.#dobErrorIdx = null; this.#syncDob() }, 700)
  }

  #syncDob() {
    const wraps = [this.ddWrapTarget, this.mmWrapTarget, this.yyyyWrapTarget]
    const displays = [this.ddDisplayTarget, this.mmDisplayTarget, this.yyyyDisplayTarget]

    this.#dob.forEach((val, i) => {
      const isActive = this.#dobActive === i
      const isError = this.#dobErrorIdx === i
      const state = isError ? "error" : isActive ? "active" : "idle"

      wraps[i].dataset.state = state
      wraps[i].dataset.active = isActive ? "true" : "false"
      displays[i].dataset.state = state
      displays[i].textContent = val || DOB_FIELDS[i].placeholder
    })
  }

  #postcodeFormat(raw) {
    if (this.#fmt.numeric) return raw
    if (raw.length <= 3) return raw
    const split = raw.length - 3
    return `${raw.slice(0, split)} ${raw.slice(split)}`
  }

  #handlePostcodeConfirm() {
    const fmt = this.#fmt
    if (this.#postcode.length < fmt.min) {
      this.#triggerPostcodeShake("Too short - please check")
      return
    }
    const formatted = this.#postcodeFormat(this.#postcode)
    if (!fmt.re.test(formatted)) {
      this.#triggerPostcodeShake(fmt.errorMsg)
      return
    }
    this.#transition("postcode", "email")
  }

  #triggerPostcodeShake(message = null) {
    this.#postcodeErrorMsg = message
    this.#updatePostcodeUI()
    if (this.hasPostcodeFieldTarget) {
      const el = this.postcodeFieldTarget
      el.classList.remove("kiosk-shake")
      void el.offsetWidth
      el.classList.add("kiosk-shake")
      clearTimeout(this.#postcodeShakeTimer)
      this.#postcodeShakeTimer = setTimeout(() => el.classList.remove("kiosk-shake"), 450)
    }
    if (message) {
      clearTimeout(this.#postcodeErrTimer)
      this.#postcodeErrTimer = setTimeout(() => { this.#postcodeErrorMsg = null; this.#updatePostcodeUI() }, 3000)
    }
  }

  #updatePostcodeUI() {
    if (!this.hasPostcodeFieldTarget) return

    const raw = this.#postcode
    const isError = !!this.#postcodeErrorMsg
    const isReady = raw.length >= this.#fmt.min
    const state = isError ? "error" : isReady ? "ready" : "idle"

    this.postcodeFieldTarget.dataset.state = state

    if (raw.length === 0) {
      if (this.hasPostcodeEmptyTarget) this.postcodeEmptyTarget.classList.remove("hidden")
      if (this.hasPostcodeFilledDisplayTarget) this.postcodeFilledDisplayTarget.classList.add("hidden")
    } else {
      if (this.hasPostcodeEmptyTarget) this.postcodeEmptyTarget.classList.add("hidden")
      if (this.hasPostcodeFilledDisplayTarget) {
        this.postcodeFilledDisplayTarget.classList.remove("hidden")
        if (this.hasPostcodeOutwardTextTarget) {
          this.postcodeOutwardTextTarget.textContent = raw
        }
      }
    }

    if (this.hasPostcodeErrorTarget) {
      this.postcodeErrorTarget.textContent = this.#postcodeErrorMsg || ""
      this.postcodeErrorTarget.classList.toggle("hidden", !this.#postcodeErrorMsg)
    }

    if (this.hasPostcodeConfirmBtnTarget) {
      const btn = this.postcodeConfirmBtnTarget
      btn.classList.toggle("btn-primary", isReady && !isError)
      btn.classList.toggle("btn-disabled", !isReady || isError)
    }
  }

  #triggerEmailShake(message = null) {
    this.#emailErrMsg = message
    this.#updateEmailUI()
    if (this.hasEmailFieldTarget) {
      const el = this.emailFieldTarget
      el.classList.remove("kiosk-shake")
      void el.offsetWidth
      el.classList.add("kiosk-shake")
      clearTimeout(this.#emailShakeTimer)
      this.#emailShakeTimer = setTimeout(() => el.classList.remove("kiosk-shake"), 450)
    }
    if (message) {
      clearTimeout(this.#emailErrTimer)
      this.#emailErrTimer = setTimeout(() => { this.#emailErrMsg = null; this.#updateEmailUI() }, 3000)
    }
  }

  #updateEmailUI() {
    if (!this.hasEmailFieldTarget) return

    if (this.hasEmailSkippedViewTarget) {
      this.emailSkippedViewTarget.classList.toggle("hidden", !this.#emailSkipped)
      this.emailSkippedViewTarget.classList.toggle("flex", this.#emailSkipped)
    }
    if (this.hasEmailKeyboardViewTarget) {
      this.emailKeyboardViewTarget.classList.toggle("hidden", this.#emailSkipped)
    }

    if (this.#emailSkipped) return

    const isReady = EMAIL_RE.test(this.#email)
    const isError = !!this.#emailErrMsg
    const state = isError ? "error" : isReady ? "ready" : "active"

    this.emailFieldTarget.dataset.state = state

    if (this.hasEmailDisplayTarget) {
      this.emailDisplayTarget.textContent = this.#email || "name@example.com"
      this.emailDisplayTarget.classList.toggle("text-base-content", !!this.#email && !isError)
      this.emailDisplayTarget.classList.toggle("text-base-content/40", !this.#email && !isError)
      this.emailDisplayTarget.classList.toggle("text-error", isError)
    }

    if (this.hasEmailErrorMsgTarget) {
      this.emailErrorMsgTarget.textContent = this.#emailErrMsg || ""
      this.emailErrorMsgTarget.classList.toggle("hidden", !this.#emailErrMsg)
    }

    if (this.hasEmailChipTarget) {
      const atIdx = this.#email.indexOf("@")
      const base = atIdx >= 0 ? this.#email.slice(0, atIdx) : this.#email
      this.emailChipTargets.forEach((chip) => {
        chip.dataset.active = (this.#email.includes("@") && this.#email === base + chip.dataset.domain) ? "true" : "false"
      })
    }

    if (this.hasEmailConfirmBtnTarget) {
      const btn = this.emailConfirmBtnTarget
      btn.classList.toggle("btn-primary", isReady && !isError)
      btn.classList.toggle("btn-disabled", !isReady || isError)
    }
  }

  #syncNotes() {
    if (this.hasNotesDisplayTarget) {
      this.notesDisplayTarget.textContent = this.#notes || "·"
      this.notesDisplayTarget.classList.toggle("text-base-content", !!this.#notes)
      this.notesDisplayTarget.classList.toggle("text-base-content/40", !this.#notes)
    }
    if (this.hasNotesCharCountTarget) {
      const remaining = 200 - this.#notes.length
      this.notesCharCountTarget.textContent = `${remaining} characters remaining`
      this.notesCharCountTarget.classList.toggle("text-error", remaining < 20)
      this.notesCharCountTarget.classList.toggle("text-base-content/50", remaining >= 20)
    }
  }

  #populateConfirm() {
    this.#renderConfirmError()
    const [dd, mm, yyyy] = this.#dob
    if (this.hasConfirmDateTarget && this.#apptDate) {
      const d = new Date(this.#apptDate + "T00:00:00")
      this.confirmDateTarget.textContent =
        d.toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long", year: "numeric" })
    }
    if (this.hasConfirmTimeTarget) this.confirmTimeTarget.textContent = this.#fmtSlot(this.#apptSlot)
    if (this.hasConfirmFirstNameTarget) this.confirmFirstNameTarget.textContent = this.#firstName
    if (this.hasConfirmLastNameTarget) this.confirmLastNameTarget.textContent = this.#lastName
    if (this.hasConfirmDobTarget) this.confirmDobTarget.textContent = `${dd.padStart(2, "0")}/${mm.padStart(2, "0")}/${yyyy}`
    if (this.hasConfirmPostcodeTarget) this.confirmPostcodeTarget.textContent = this.#postcodeFormat(this.#postcode).toUpperCase()
    if (this.hasConfirmEmailTarget) this.confirmEmailTarget.textContent = this.#emailSkipped || !this.#email ? "-" : this.#email
    if (this.hasConfirmNotesTarget) this.confirmNotesTarget.textContent = this.#notesSkipped || !this.#notes ? "-" : this.#notes
  }

  #setLoading(btn, loading) {
    if (loading) {
      btn.disabled = true
      btn.innerHTML =
        `<span class="material-symbols-outlined animate-spin">progress_activity</span> Processing&hellip;`
    } else {
      btn.disabled = false
      btn.innerHTML = "Confirm Booking"
    }
  }

  #pressKey(_el) {}

  #showImmediate(name) {
    showPanelImmediate(this.#allPanels(), this.#panel(name))
  }

  #transition(from, to) {
    this.#clearSubmitError()
    transitionPanels(this.#panel(from), this.#panel(to), this.#stepDirection(from, to))
  }

  #stepDirection(from, to) {
    const order = ["eligibility", "appointment", "name", "dob", "postcode", "email", "notes", "confirm"]
    const fromIndex = order.indexOf(from)
    const toIndex = order.indexOf(to)
    if (fromIndex === -1 || toIndex === -1) return "forward"
    return toIndex > fromIndex ? "forward" : "back"
  }

  #handleSubmitError(data) {
    const errors = Array.isArray(data?.errors) ? data.errors : []
    const message = errors[0] || "Could not complete your booking. Please try again."

    if (errors.some((e) => e.includes("no longer available"))) {
      this.#apptSlot = null
      this.#submitError = "That time has just been taken. Please choose another slot."
      transitionPanels(this.#panel("confirm"), this.#panel("appointment"), "back")
      this.#apptStep = "time"
      this.#renderApptUI()
      this.#fetchSlots()
      return
    }

    this.#showConfirmError(message)
  }

  #showConfirmError(message) {
    this.#submitError = message
    this.#renderConfirmError()
  }

  #clearSubmitError() {
    this.#submitError = null
    this.#renderConfirmError()
    this.#renderApptError()
  }

  #renderConfirmError() {
    if (!this.hasConfirmErrorTarget) return
    this.confirmErrorTarget.textContent = this.#submitError || ""
    this.confirmErrorTarget.classList.toggle("hidden", !this.#submitError)
  }

  #renderApptError() {
    if (!this.hasApptErrorTarget) return
    const show = !!this.#submitError && this.#apptStep === "time"
    this.apptErrorTarget.textContent = show ? this.#submitError : ""
    this.apptErrorTarget.classList.toggle("hidden", !show)
  }

  #afterName() {
    if (this.hasDobPanelTarget) return "dob"
    if (this.hasPostcodePanelTarget) return "postcode"
    return "email"
  }

  #panel(name) { return this[`${name}PanelTarget`] }

  #allPanels() {
    return [
      this.eligibilityPanelTarget,
      this.appointmentPanelTarget,
      this.namePanelTarget,
      ...(this.hasDobPanelTarget ? [this.dobPanelTarget] : []),
      ...(this.hasPostcodePanelTarget ? [this.postcodePanelTarget] : []),
      this.emailPanelTarget,
      this.notesPanelTarget,
      this.confirmPanelTarget,
    ]
  }

  get #fmt() { return POSTCODE_FORMATS[this.postcodeRegionValue] ?? POSTCODE_FORMATS.uk }
}
