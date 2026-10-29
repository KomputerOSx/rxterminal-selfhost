import { Controller } from "@hotwired/stimulus"
import { showPanelImmediate, transitionPanels } from "kiosk/panel_transitions"

const DOB_FIELDS = [
  { id: "dd",   maxLen: 2 },
  { id: "mm",   maxLen: 2 },
  { id: "yyyy", maxLen: 4 },
]

export default class extends Controller {
  static values = {
    refFormId:     String,
    detailsFormId: String,
    initialMode:   String,
    collectDob:    Boolean,
    candidatesUrl: String,
  }

  static targets = [
    "chooseView", "refView", "nameView", "dobView", "candidatesView", "alert", "alertMessage", "topbar",
    "refDisplay", "refConfirmBtn", "refInput",
    "nameDisplay", "nameContinueBtn",
    "dobNameBadge",
    "ddTab", "mmTab", "yyyyTab",
    "ddDisplay", "mmDisplay", "yyyyDisplay",
    "dobConfirmBtn",
    "candidatesGrid",
    "lastNameInput", "dobInput", "appointmentIdInput",
  ]

  connect() {
    this.mode      = "choose"
    this.reference = ""
    this.lastName  = ""
    this.dob       = { dd: "", mm: "", yyyy: "" }
    this.dobActive = "dd"
    this.errorField = null

    const initial = this.initialModeValue
    if (initial === "reference") this.mode = "reference"
    else if (initial === "details") this.mode = "name"

    this.#showImmediate(this.mode)
    this.#renderStep()

    if (this.hasAlertTarget && !this.alertTarget.classList.contains("!hidden")) {
      this.alertTimeout = setTimeout(() => this.alertTarget.classList.add("!hidden"), 5000)
    }
  }

  chooseRef(event) {
    event.preventDefault()
    this.#press(event.currentTarget, "kiosk-card-pressing")
    setTimeout(() => this.#navigateTo("reference"), 130)
  }

  chooseName(event) {
    event.preventDefault()
    this.#press(event.currentTarget, "kiosk-card-pressing")
    setTimeout(() => this.#navigateTo("name"), 130)
  }

  back(event) {
    event.preventDefault()
    this.#press(event.currentTarget)
    this.errorField = null
    if (this.mode === "reference" || this.mode === "name") this.#navigateTo("choose")
    else if (this.mode === "dob") this.#navigateTo("name")
    else if (this.mode === "candidates") this.#navigateTo(this.collectDobValue ? "dob" : "name")
  }

  refKey(event) {
    event.preventDefault()
    const key = event.currentTarget.dataset.key
    this.#press(event.currentTarget)
    if (key === "⌫") {
      this.reference = this.reference.slice(0, -1)
    } else if (this.reference.length < 6) {
      this.reference += key
    }
    this.#renderStep()
  }

  refConfirm(event) {
    event.preventDefault()
    this.#press(event.currentTarget)
    if (this.reference.trim().length < 6) {
      this.#shake(this.refDisplayTarget); return
    }
    this.refInputTarget.value = this.reference.trim().toUpperCase()
    document.getElementById(this.refFormIdValue).submit()
  }

  refReset(event) {
    event.preventDefault()
    this.#press(event.currentTarget)
    this.reference = ""
    this.#renderStep()
  }

  nameKey(event) {
    event.preventDefault()
    const key = event.currentTarget.dataset.key
    this.#press(event.currentTarget)
    if (key === "⌫") {
      this.lastName = this.lastName.slice(0, -1)
    } else if (key === "SPACE") {
      if (this.lastName.length > 0) this.lastName += " "
    } else if (this.lastName.length < 30) {
      this.lastName += key
    }
    this.#renderStep()
  }

  nameReset(event) {
    event.preventDefault()
    this.#press(event.currentTarget)
    this.lastName = ""
    this.#renderStep()
  }

  nameContinue(event) {
    event.preventDefault()
    this.#press(event.currentTarget)
    if (this.lastName.trim().length < 2) {
      this.#shake(this.nameDisplayTarget); return
    }
    if (!this.collectDobValue) {
      this.lastNameInputTarget.value = this.lastName.trim()
      this.dobInputTarget.value      = ""
      this.#fetchCandidates()
      return
    }
    this.dob  = { dd: "", mm: "", yyyy: "" }
    this.dobActive  = "dd"
    this.errorField = null
    this.#navigateTo("dob")
  }

  selectDobField(event) {
    event.preventDefault()
    this.dobActive  = event.currentTarget.dataset.field
    this.errorField = null
    this.#renderStep()
  }

  dobKey(event) {
    event.preventDefault()
    const key = event.currentTarget.dataset.key
    this.#press(event.currentTarget)
    if (key === "⌫") {
      this.#dobBackspace()
    } else if (key === "✓") {
      this.#dobConfirm(); return
    } else {
      this.#dobDigit(key)
    }
    this.#renderStep()
  }

  dobReset(event) {
    event.preventDefault()
    this.#press(event.currentTarget)
    this.dob       = { dd: "", mm: "", yyyy: "" }
    this.dobActive = "dd"
    this.errorField = null
    this.#renderStep()
  }

  #navigateTo(to) {
    const from = this.mode
    if (from === to) return

    transitionPanels(this.#viewPanel(from), this.#viewPanel(to), this.#stepDirection(from, to))
    this.mode = to
    this.#syncTopbar()
    this.#renderStep()
  }

  #showImmediate(mode) {
    showPanelImmediate(this.#allViews(), this.#viewPanel(mode))
    this.#syncTopbar()
  }

  #syncTopbar() {
    if (!this.hasTopbarTarget) return

    this.topbarTarget.classList.toggle("invisible", this.mode !== "choose")
    this.topbarTarget.classList.toggle("pointer-events-none", this.mode !== "choose")
  }

  #renderStep() {
    if (this.mode === "reference") this.#renderRef()
    if (this.mode === "name")      this.#renderName()
    if (this.mode === "dob")       this.#renderDob()
  }

  #stepDirection(from, to) {
    const order = ["choose", "reference", "name", "dob", "candidates"]
    const fromIndex = order.indexOf(from)
    const toIndex = order.indexOf(to)
    if (fromIndex === -1 || toIndex === -1) return "forward"
    return toIndex > fromIndex ? "forward" : "back"
  }

  #viewPanel(mode) {
    return {
      choose:     this.chooseViewTarget,
      reference:  this.refViewTarget,
      name:       this.nameViewTarget,
      dob:        this.dobViewTarget,
      candidates: this.candidatesViewTarget,
    }[mode]
  }

  #allViews() {
    return [
      this.chooseViewTarget,
      this.refViewTarget,
      this.nameViewTarget,
      this.dobViewTarget,
      this.candidatesViewTarget,
    ]
  }

  #renderRef() {
    const val   = this.reference
    const ready = val.trim().length >= 6
    this.refDisplayTarget.textContent = val || "—"
    this.refDisplayTarget.classList.toggle("text-base-content/40", !val)
    this.refDisplayTarget.classList.toggle("text-base-content", !!val)
    this.#syncBtn(this.refConfirmBtnTarget, ready)
  }

  #renderName() {
    const val   = this.lastName
    const ready = val.trim().length >= 2
    this.nameDisplayTarget.textContent = val || "·"
    this.#syncBtn(this.nameContinueBtnTarget, ready)
  }

  #renderDob() {
    this.dobNameBadgeTarget.textContent = this.lastName

    DOB_FIELDS.forEach(({ id }) => {
      const isActive = this.dobActive === id
      const isError  = this.errorField === id
      const val      = this.dob[id]
      const wrap     = this[`${id}TabTarget`]
      const disp     = this[`${id}DisplayTarget`]
      const state    = isError ? "error" : isActive ? "active" : "idle"

      wrap.dataset.state  = state
      wrap.dataset.active = isActive ? "true" : "false"
      disp.dataset.state  = state
      disp.textContent    = val || id.toUpperCase()
    })
  }

  #dobBackspace() {
    const f = this.dobActive
    if (this.dob[f].length > 0) {
      this.dob[f] = this.dob[f].slice(0, -1)
      this.errorField = null
    } else {
      const idx = DOB_FIELDS.findIndex(d => d.id === f)
      if (idx > 0) {
        this.dobActive = DOB_FIELDS[idx - 1].id
        this.dob[this.dobActive] = this.dob[this.dobActive].slice(0, -1)
        this.errorField = null
      }
    }
  }

  #dobDigit(digit) {
    const { id, maxLen } = DOB_FIELDS.find(f => f.id === this.dobActive)
    const cur = this.dob[id]
    if (cur.length >= maxLen || !this.#validateDob(id, cur + digit)) {
      this.#triggerError(id); return
    }
    this.dob[id] = cur + digit
    if (this.dob[id].length >= maxLen) {
      const idx = DOB_FIELDS.findIndex(f => f.id === id)
      if (idx < DOB_FIELDS.length - 1) {
        setTimeout(() => { this.dobActive = DOB_FIELDS[idx + 1].id; this.#renderStep() }, 110)
      }
    }
  }

  #validateDob(id, val) {
    if (!val) return true
    const n = parseInt(val, 10)
    if (isNaN(n)) return false
    if (id === "dd") {
      if (val.length === 1 && n > 3) return false
      if (val.length === 2 && (n < 1 || n > 31)) return false
    }
    if (id === "mm") {
      if (val.length === 1 && n > 1) return false
      if (val.length === 2 && (n < 1 || n > 12)) return false
    }
    if (id === "yyyy" && val.length === 4 && (n < 1900 || n > 2099)) return false
    return true
  }

  #triggerError(fieldId) {
    this.errorField = fieldId
    this.#renderStep()
    this.#shake(this[`${fieldId}TabTarget`])
    setTimeout(() => { this.errorField = null; this.#renderStep() }, 700)
  }

  #dobConfirm() {
    const missing = DOB_FIELDS.find(f => this.dob[f.id].length < f.maxLen)
    if (missing) { this.#triggerError(missing.id); return }
    const { dd, mm, yyyy } = this.dob
    this.lastNameInputTarget.value = this.lastName.trim()
    this.dobInputTarget.value      = `${yyyy}-${mm.padStart(2, "0")}-${dd.padStart(2, "0")}`
    this.#fetchCandidates()
  }

  async #fetchCandidates() {
    const url = new URL(this.candidatesUrlValue, window.location.origin)
    url.searchParams.set("last_name", this.lastName.trim())
    if (this.collectDobValue) {
      const { dd, mm, yyyy } = this.dob
      url.searchParams.set("dob", `${yyyy}-${mm.padStart(2, "0")}-${dd.padStart(2, "0")}`)
    }

    const response = await fetch(url, { headers: { Accept: "text/html" } })

    if (!response.ok) {
      this.#showAlert(`No matching appointment found for "${this.lastName.trim()}". Please check your details and try again, or speak to a member of staff.`)
      return
    }

    this.candidatesGridTarget.innerHTML = await response.text()
    this.#navigateTo("candidates")
  }

  #showAlert(message) {
    if (!this.hasAlertTarget) return

    clearTimeout(this.alertTimeout)
    this.alertMessageTarget.textContent = message
    this.alertTarget.classList.remove("!hidden")
    this.alertTimeout = setTimeout(() => this.alertTarget.classList.add("!hidden"), 5000)
  }

  selectCandidate(event) {
    event.preventDefault()
    const btn = event.currentTarget
    if (btn.disabled) return
    this.#press(btn)
    this.appointmentIdInputTarget.value = btn.dataset.appointmentId
    this.lastNameInputTarget.value = this.lastName.trim()
    this.dobInputTarget.value = this.collectDobValue
      ? `${this.dob.yyyy}-${this.dob.mm.padStart(2, "0")}-${this.dob.dd.padStart(2, "0")}`
      : ""
    setTimeout(() => document.getElementById(this.detailsFormIdValue).submit(), 130)
  }

  #syncBtn(el, ready) {
    el.classList.toggle("btn-primary", ready)
    el.classList.toggle("btn-disabled", !ready)
    el.disabled = !ready
  }

  #press(el, cls = "kiosk-key-pressing") {
    el.classList.remove(cls)
    void el.offsetWidth
    el.classList.add(cls)
  }

  #shake(el) {
    el.classList.remove("kiosk-shake")
    void el.offsetWidth
    el.classList.add("kiosk-shake")
  }
}
