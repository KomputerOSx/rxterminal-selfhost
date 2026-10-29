import { Controller } from "@hotwired/stimulus"
import { showPanelImmediate, transitionPanels, KIOSK_PANEL_TRANSITION_MS } from "kiosk/panel_transitions"

// DOB field config for the service request flow.
const DOB_FIELDS = [
  { maxLen: 2, max: 31,   min: 1,    placeholder: "DD"   },  // 0: day
  { maxLen: 2, max: 12,   min: 1,    placeholder: "MM"   },  // 1: month
  { maxLen: 4, max: 2099, min: 1900, placeholder: "YYYY" },  // 2: year
]

// Postcode validation formats by region.
const POSTCODE_FORMATS = {
  uk: { re: /^([A-Z]{1,2}[0-9][0-9A-Z]?)\s?([0-9][A-Z]{2})$/i, min: 5, max: 8,  numeric: false, errorMsg: "Invalid UK postcode - please check" },
  us: { re: /^\d{5}$/,                                             min: 5, max: 5,  numeric: true,  errorMsg: "Invalid ZIP code - must be 5 digits" },
  ca: { re: /^[ABCEGHJ-NPRSTVXY]\d[ABCEGHJ-NPRSTV-Z]\s?\d[ABCEGHJ-NPRSTV-Z]\d$/i, min: 6, max: 7, numeric: false, errorMsg: "Invalid Canadian postal code" },
  au: { re: /^\d{4}$/,                                             min: 4, max: 4,  numeric: true,  errorMsg: "Invalid postcode - must be 4 digits" },
}

// Kiosk Service Request - 5-step flow
// Name → DOB → Postcode → Confirm → Confirmed
// All steps are CSS panels; only the active one is visible.

export default class extends Controller {
  static targets = [
    // Panels
    "eligibilityPanel", "namePanel", "dobPanel", "postcodePanel", "privacyPanel", "confirmPanel", "confirmedPanel",
    // Name step
    "firstDisplay", "lastDisplay", "firstWrap", "lastWrap",
    // DOB step
    "ddDisplay",   "mmDisplay",   "yyyyDisplay",
    "ddWrap",      "mmWrap",      "yyyyWrap",
    // Postcode step
    "postcodeField",
    "postcodeEmpty", "postcodeFilledDisplay",
    "postcodeOutwardText", "postcodeError", "postcodeConfirmBtn",
    // Privacy step
    "privacyOptionPrivate", "privacyOptionNone",
    "privacyContinueBtn",
    // Confirm step
    "confirmFirstName", "confirmLastName", "confirmDob", "confirmPostcode", "confirmPrivacy",
    // Confirmed step
    "queueNumber", "serviceName",
    // Submit button
    "submitBtn",
  ]

  static values = {
    serviceId:                  Number,
    submitUrl:                  String,
    homeUrl:                    String,
    hasEligibility:             Boolean,
    allowsPrivateConsultation:  Boolean,
    postcodeRegion:             { type: String, default: "uk" },
  }

  // ── Private state ──────────────────────────────────────────────────────────
  #firstName = ""
  #lastName  = ""
  #nameField = "first"

  #dob           = ["", "", ""]
  #dobActive     = 0
  #dobErrorIdx   = null
  #dobShakeTimer = null
  #dobErrTimer   = null

  #postcode           = ""
  #postcodeErrorMsg   = null
  #postcodeShakeTimer = null
  #postcodeErrTimer   = null

  #privacyRequested = null

  connect() {
    this.#showImmediate(this.hasEligibilityValue ? "eligibility" : "name")
    this.#syncName()
    this.#syncDob()
    this.#updatePostcodeUI()
  }

  disconnect() {
    clearTimeout(this.#dobShakeTimer)
    clearTimeout(this.#dobErrTimer)
    clearTimeout(this.#postcodeShakeTimer)
    clearTimeout(this.#postcodeErrTimer)
  }

  // ── Step 1: Name ────────────────────────────────────────────────────────────

  nameKey(event) {
    const key = event.currentTarget.dataset.key
    this.#pressKey(event.currentTarget)

    if (key === "⌫") {
      if (this.#nameField === "first") {
        this.#firstName = this.#firstName.slice(0, -1)
      } else {
        if (this.#lastName.length === 0) {
          this.#nameField = "first"
        } else {
          this.#lastName = this.#lastName.slice(0, -1)
        }
      }
    } else if (key === "→") {
      if (this.#nameField === "first" && this.#firstName.length > 0) {
        this.#nameField = "last"
      } else if (this.#nameField === "last" && this.#lastName.length > 0) {
        this.#goAfterName()
        return
      }
    } else {
      const char = key === "SPACE" ? " " : key
      if (this.#nameField === "first" && this.#firstName.length < 30) {
        this.#firstName += char
      } else if (this.#nameField === "last" && this.#lastName.length < 30) {
        this.#lastName += char
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
    this.#lastName  = ""
    this.#nameField = "first"
    this.#syncName()
  }

  nameBack() {
    if (this.hasEligibilityValue) {
      this.#transition("name", "eligibility")
    } else {
      history.back()
    }
  }

  eligibilityAccept(event) {
    this.#pressKey(event.currentTarget)
    setTimeout(() => this.#transition("eligibility", "name"), 140)
  }

  eligibilityDecline(event) {
    this.#pressKey(event.currentTarget)
    setTimeout(() => Turbo.visit(this.homeUrlValue), 140)
  }

  // ── Step 2: DOB ─────────────────────────────────────────────────────────────

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
    const cur   = this.#dob[this.#dobActive]

    if (cur.length >= field.maxLen) {
      this.#triggerDobShake(this.#dobActive)
      return
    }

    const next = cur + key
    if (!this.#validateDobField(this.#dobActive, next)) {
      this.#triggerDobShake(this.#dobActive)
      return
    }

    clearTimeout(this.#dobErrTimer)
    this.#dobErrorIdx = null
    this.#dob[this.#dobActive] = next
    this.#syncDob()

    // Auto-advance to next field when complete
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
    this.#dob         = ["", "", ""]
    this.#dobActive   = 0
    this.#dobErrorIdx = null
    this.#syncDob()
  }

  dobBack() {
    clearTimeout(this.#dobShakeTimer)
    clearTimeout(this.#dobErrTimer)
    this.#dobErrorIdx = null
    this.#transition("dob", "name")
  }

  // ── Step 3: Postcode ─────────────────────────────────────────────────────────

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
      const fmt  = this.#fmt
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
    this.#postcode         = ""
    this.#postcodeErrorMsg = null
    this.#updatePostcodeUI()
  }

  // ── Step 4: Privacy ──────────────────────────────────────────────────────────

  privacySelect(event) {
    this.#pressKey(event.currentTarget)
    this.#privacyRequested = event.currentTarget.dataset.option === "true"
    this.#syncPrivacy()
  }

  privacyBack() {
    if (this.hasPostcodePanelTarget) {
      this.#transition("privacy", "postcode")
    } else if (this.hasDobPanelTarget) {
      this.#transition("privacy", "dob")
    } else {
      this.#transition("privacy", "name")
    }
  }

  privacyContinue(event) {
    if (this.#privacyRequested === null) return
    this.#pressKey(event.currentTarget)
    this.#populateConfirm()
    setTimeout(() => this.#transition("privacy", "confirm"), 140)
  }

  // ── Step 5: Confirm ──────────────────────────────────────────────────────────

  confirmBack() {
    if (this.allowsPrivateConsultationValue) {
      this.#transition("confirm", "privacy")
    } else if (this.hasPostcodePanelTarget) {
      this.#transition("confirm", "postcode")
    } else if (this.hasDobPanelTarget) {
      this.#transition("confirm", "dob")
    } else {
      this.#transition("confirm", "name")
    }
  }

  async confirmSubmit() {
    const btn = this.submitBtnTarget
    this.#pressKey(btn)
    this.#setLoading(btn, true)

    const [dd, mm, yyyy] = this.#dob
    const dob = this.hasDobPanelTarget ? `${yyyy}-${mm.padStart(2, "0")}-${dd.padStart(2, "0")}` : null

    try {
      const res = await fetch(this.submitUrlValue, {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept":        "application/json",
          "X-CSRF-Token":  document.querySelector('meta[name="csrf-token"]')?.content,
        },
        body: JSON.stringify({
          service_id:      this.serviceIdValue,
          service_request: {
            first_name:        this.#firstName,
            last_name:         this.#lastName,
            dob,
            postcode:          this.hasPostcodePanelTarget ? this.#postcodeFormat(this.#postcode) : null,
            privacy_requested: this.allowsPrivateConsultationValue ? (this.#privacyRequested === true) : false,
          },
        }),
      })

      const data = await res.json()
      if (!res.ok) { this.#setLoading(btn, false); return }

      if (data.redirect_to) {
        Turbo.visit(data.redirect_to)
      } else {
        if (this.hasQueueNumberTarget) this.queueNumberTarget.textContent = data.queue_number
        if (this.hasServiceNameTarget)  this.serviceNameTarget.textContent  = data.service_name || ""
        this.#transition("confirm", "confirmed")
      }
    } catch {
      this.#setLoading(btn, false)
    }
  }

  // ── Step 5: Confirmed ────────────────────────────────────────────────────────

  done() { Turbo.visit(this.homeUrlValue || "/kiosk") }

  // ── Private: Name ────────────────────────────────────────────────────────────

  #syncName() {
    this.firstDisplayTarget.textContent = this.#firstName || "·"
    this.lastDisplayTarget.textContent  = this.#lastName  || "·"
    this.firstWrapTarget.dataset.active = this.#nameField === "first" ? "true" : "false"
    this.lastWrapTarget.dataset.active  = this.#nameField === "last"  ? "true" : "false"
  }

  // ── Private: DOB ────────────────────────────────────────────────────────────

  #validateDobField(idx, val) {
    const num = parseInt(val, 10)
    if (isNaN(num)) return true
    const field = DOB_FIELDS[idx]
    if (val.length === field.maxLen && (num < field.min || num > field.max)) return false
    if (idx === 0 && val.length === 1 && num > 3) return false  // day can't start > 3
    if (idx === 1 && val.length === 1 && num > 1) return false  // month can't start > 1
    return true
  }

  #handleDobConfirm() {
    const firstIncomplete = this.#dob.findIndex((val, i) => val.length < DOB_FIELDS[i].maxLen)
    if (firstIncomplete !== -1) {
      this.#dobActive = firstIncomplete
      this.#triggerDobShake(firstIncomplete)
      return
    }
    if (this.hasPostcodePanelTarget) {
      this.#transition("dob", "postcode")
    } else if (this.allowsPrivateConsultationValue) {
      this.#transition("dob", "privacy")
    } else {
      this.#populateConfirm()
      this.#transition("dob", "confirm")
    }
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
    const wraps    = [ this.ddWrapTarget, this.mmWrapTarget, this.yyyyWrapTarget ]
    const displays = [ this.ddDisplayTarget, this.mmDisplayTarget, this.yyyyDisplayTarget ]

    this.#dob.forEach((val, i) => {
      const isActive = this.#dobActive === i
      const isError  = this.#dobErrorIdx === i
      const state    = isError ? "error" : isActive ? "active" : "idle"

      wraps[i].dataset.state  = state
      wraps[i].dataset.active = isActive ? "true" : "false"
      displays[i].dataset.state = state
      displays[i].textContent   = val || DOB_FIELDS[i].placeholder
    })
  }

  // ── Private: Postcode ───────────────────────────────────────────────────────

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
    if (this.allowsPrivateConsultationValue) {
      this.#transition("postcode", "privacy")
    } else {
      this.#populateConfirm()
      this.#transition("postcode", "confirm")
    }
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

    const raw     = this.#postcode
    const isError = !!this.#postcodeErrorMsg
    const isReady = raw.length >= this.#fmt.min
    const state   = isError ? "error" : isReady ? "ready" : "idle"

    this.postcodeFieldTarget.dataset.state = state

    if (raw.length === 0) {
      if (this.hasPostcodeEmptyTarget)         this.postcodeEmptyTarget.classList.remove("hidden")
      if (this.hasPostcodeFilledDisplayTarget) this.postcodeFilledDisplayTarget.classList.add("hidden")
    } else {
      if (this.hasPostcodeEmptyTarget)         this.postcodeEmptyTarget.classList.add("hidden")
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

  // ── Private: Privacy ─────────────────────────────────────────────────────────

  #syncPrivacy() {
    if (!this.hasPrivacyOptionPrivateTarget) return
    const active = (val) => val ? "true" : "false"
    this.privacyOptionPrivateTarget.dataset.active = active(this.#privacyRequested === true)
    this.privacyOptionNoneTarget.dataset.active    = active(this.#privacyRequested === false)

    const continueBtn = this.privacyContinueBtnTarget
    const ready = this.#privacyRequested !== null
    continueBtn.dataset.active = active(ready)
    continueBtn.classList.toggle("btn-primary", ready)
    continueBtn.classList.toggle("btn-disabled", !ready)
  }

  // ── Private: Confirm ─────────────────────────────────────────────────────────

  #populateConfirm() {
    const [dd, mm, yyyy] = this.#dob
    this.confirmFirstNameTarget.textContent = this.#firstName
    this.confirmLastNameTarget.textContent  = this.#lastName
    if (this.hasConfirmDobTarget) {
      this.confirmDobTarget.textContent = `${dd.padStart(2,"0")}/${mm.padStart(2,"0")}/${yyyy}`
    }
    if (this.hasConfirmPostcodeTarget) {
      this.confirmPostcodeTarget.textContent = this.#postcodeFormat(this.#postcode).toUpperCase()
    }
    if (this.allowsPrivateConsultationValue && this.hasConfirmPrivacyTarget) {
      this.confirmPrivacyTarget.textContent = this.#privacyRequested ? "Private Room" : "No Preference"
    }
  }

  // ── Private: Shared ──────────────────────────────────────────────────────────

  #setLoading(btn, loading) {
    if (loading) {
      btn.disabled  = true
      btn.innerHTML = `
        <span class="material-symbols-outlined animate-spin">progress_activity</span>
        Processing&hellip;`
    } else {
      btn.disabled  = false
      btn.innerHTML = "Confirm &amp; Join Queue"
    }
  }

  #pressKey(_el) {
    // btn:active scale handled globally in application.css
  }

  #showImmediate(name) {
    showPanelImmediate(this.#allPanels(), this.#panel(name))
  }

  #transition(from, to) {
    const direction = this.#stepDirection(from, to)
    transitionPanels(this.#panel(from), this.#panel(to), direction)

    if (to === "confirmed") {
      window.setTimeout(() => this.#playConfirmedEnterAnimation(), KIOSK_PANEL_TRANSITION_MS + 40)
    }
  }

  #stepDirection(from, to) {
    const order = ["eligibility", "name", "dob", "postcode", "privacy", "confirm", "confirmed"]
    const fromIndex = order.indexOf(from)
    const toIndex = order.indexOf(to)
    if (fromIndex === -1 || toIndex === -1) return "forward"
    return toIndex > fromIndex ? "forward" : "back"
  }

  #playConfirmedEnterAnimation() {
    this.confirmedPanelTarget.querySelectorAll("[data-kiosk-confirmed-animate]").forEach((el) => {
      el.classList.remove("kiosk-confirmed-animate")
      void el.offsetWidth
      el.classList.add("kiosk-confirmed-animate")
    })
  }

  #goAfterName() {
    if (this.hasDobPanelTarget) { this.#transition("name", "dob"); return }
    if (this.hasPostcodePanelTarget) { this.#transition("name", "postcode"); return }
    if (this.allowsPrivateConsultationValue) { this.#transition("name", "privacy"); return }
    this.#populateConfirm()
    this.#transition("name", "confirm")
  }

  #panel(name)  { return this[`${name}PanelTarget`] }

  #allPanels() {
    return [
      this.eligibilityPanelTarget,
      this.namePanelTarget,
      ...(this.hasDobPanelTarget ? [ this.dobPanelTarget ] : []),
      ...(this.hasPostcodePanelTarget ? [ this.postcodePanelTarget ] : []),
      this.privacyPanelTarget,
      this.confirmPanelTarget,
      this.confirmedPanelTarget,
    ]
  }

  get #fmt() { return POSTCODE_FORMATS[this.postcodeRegionValue] ?? POSTCODE_FORMATS.uk }
}
