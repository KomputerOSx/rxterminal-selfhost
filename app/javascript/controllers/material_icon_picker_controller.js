import { Controller } from "@hotwired/stimulus"

// Searchable Material Symbols icon picker. Icons are passed as grouped JSON via
// data-material-icon-picker-icons-value from ApplicationHelper::MATERIAL_ICON_GROUPS.
export default class extends Controller {
  static targets = [
    "hidden",
    "triggerIcon",
    "triggerLabel",
    "popover",
    "search",
    "grid",
    "empty"
  ]

  static values = {
    icons: Object,
    selected: String,
    updateUrl: String,
    serviceId: Number
  }

  connect() {
    this.boundCloseOnOutside = this.closeOnOutsideClick.bind(this)
    this.boundCloseOnEscape = this.closeOnEscape.bind(this)
    this.render()
    this.updateTrigger()
  }

  disconnect() {
    this.#removeListeners()
  }

  toggle(event) {
    event?.preventDefault()
    if (this.popoverTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.popoverTarget.classList.remove("hidden")
    document.addEventListener("click", this.boundCloseOnOutside, true)
    document.addEventListener("keydown", this.boundCloseOnEscape, true)
    this.searchTarget.focus()
  }

  close() {
    this.popoverTarget.classList.add("hidden")
    this.#removeListeners()
    this.searchTarget.value = ""
    this.render()
  }

  select(event) {
    const icon = event.currentTarget.dataset.iconValue
    if (this.hasUpdateUrlValue) {
      this.#patchService({ icon })
      this.selectedValue = icon
      this.hiddenTarget.value = icon
      this.updateTrigger()
      this.close()
      return
    }

    this.hiddenTarget.value = icon
    this.selectedValue = icon
    this.updateTrigger()
    this.close()
  }

  clear(event) {
    event.preventDefault()
    this.hiddenTarget.value = ""
    this.selectedValue = ""
    this.updateTrigger()
    this.close()
  }

  filter() {
    this.render(this.searchTarget.value.trim().toLowerCase())
  }

  render(query = "") {
    const selected = this.hiddenTarget.value
    this.gridTarget.innerHTML = ""
    let visibleCount = 0
    const groups = this.iconsValue || {}

    if (query) {
      Object.entries(groups).forEach(([category, names]) => {
        names.forEach((name) => {
          const haystack = `${name} ${category}`.toLowerCase().replace(/_/g, " ")
          if (!haystack.includes(query)) return

          visibleCount += 1
          this.gridTarget.appendChild(this.#buildIconButton(name, selected))
        })
      })
      this.gridTarget.className = "grid max-h-80 grid-cols-6 gap-1.5 overflow-y-auto sm:grid-cols-8"
    } else {
      Object.entries(groups).forEach(([category, names]) => {
        const section = document.createElement("div")
        const heading = document.createElement("p")
        heading.className = "mb-2 text-xs font-semibold uppercase tracking-wide text-base-content/45"
        heading.textContent = category
        section.appendChild(heading)

        const inner = document.createElement("div")
        inner.className = "grid grid-cols-6 gap-1.5 sm:grid-cols-8"
        names.forEach((name) => {
          inner.appendChild(this.#buildIconButton(name, selected))
          visibleCount += 1
        })
        section.appendChild(inner)
        this.gridTarget.appendChild(section)
      })
      this.gridTarget.className = "max-h-80 space-y-4 overflow-y-auto"
    }

    this.emptyTarget.classList.toggle("hidden", visibleCount > 0)
  }

  updateTrigger() {
    const selected = this.hiddenTarget.value
    this.triggerIconTarget.textContent = selected || "add_photo_alternate"
    this.triggerIconTarget.classList.toggle("text-base-content/40", !selected)
    this.triggerLabelTarget.textContent = selected ? selected.replace(/_/g, " ") : "Choose icon"
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }

  #buildIconButton(name, selected) {
    const button = document.createElement("button")
    button.type = "button"
    button.title = name.replace(/_/g, " ")
    button.dataset.iconValue = name
    button.dataset.action = "click->material-icon-picker#select"
    button.className = this.#buttonClass(name === selected)

    const icon = document.createElement("span")
    icon.className = "material-symbols-outlined"
    icon.style.fontSize = "20px"
    icon.textContent = name
    button.appendChild(icon)
    return button
  }

  #buttonClass(selected) {
    const base = "btn btn-square btn-sm"
    return selected ? `${base} btn-primary` : `${base} btn-outline`
  }

  #removeListeners() {
    document.removeEventListener("click", this.boundCloseOnOutside, true)
    document.removeEventListener("keydown", this.boundCloseOnEscape, true)
  }

  #patchService(body) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const params = new URLSearchParams({ service_id: this.serviceIdValue, ...body })

    fetch(this.updateUrlValue, {
      method: "PATCH",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": token
      },
      body: params
    })
      .then((response) => response.text())
      .then((html) => {
        if (window.Turbo?.renderStreamMessage) {
          window.Turbo.renderStreamMessage(html)
        }
      })
  }
}
