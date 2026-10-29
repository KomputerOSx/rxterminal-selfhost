import { Controller } from "@hotwired/stimulus"

const THEME_DATA_VALUES = {
  "kiosk-default": "kiosk-default",
  "kiosk-violet": "kiosk-violet",
  "kiosk-pastel": "kiosk-pastel",
  "kiosk-cmyk": "kiosk-cmyk",
  "kiosk-acid": "kiosk-acid",
  "kiosk-mac": "kiosk-mac",
  "kiosk-radiant-orange": "kiosk-radiant-orange",
  custom: "kiosk-custom"
}

const PREVIEW_CANVAS_WIDTH = 1100

export default class extends Controller {
  static targets = [ "themeInput", "customPanel", "preview", "colorInput", "colorValue", "radiusInput" ]

  connect() {
    this.updatePreview()
    this.resizeFrames()
    this.#watchPreviewAssets()

    this.resizeObserver = new ResizeObserver(() => this.resizeFrames())
    this.resizeObserver.observe(this.previewTarget)

    this.boundResizeFrames = this.resizeFrames.bind(this)
    this.element.addEventListener("kiosk-theme-preview:resize", this.boundResizeFrames)
  }

  disconnect() {
    this.resizeObserver?.disconnect()
    this.element.removeEventListener("kiosk-theme-preview:resize", this.boundResizeFrames)
  }

  updatePreview() {
    const selectedTheme = this.#selectedTheme()
    const resolvedTheme = THEME_DATA_VALUES[selectedTheme] || "kiosk-default"

    this.previewTarget.setAttribute("data-theme", resolvedTheme)

    if (selectedTheme === "custom") {
      this.customPanelTarget.classList.remove("hidden")
      this.#syncColorLabels()
    } else {
      this.customPanelTarget.classList.add("hidden")
    }

    const style = this.#previewStyle(selectedTheme)
    if (style) {
      this.previewTarget.setAttribute("style", style)
    } else {
      this.previewTarget.removeAttribute("style")
    }

    requestAnimationFrame(() => this.resizeFrames())
  }

  resizeFrames() {
    this.previewTarget.querySelectorAll("[data-kiosk-theme-preview-frame]").forEach((frame) => {
      const canvas = frame.querySelector("[data-kiosk-theme-preview-canvas]")
      if (!canvas) return

      const frameWidth = frame.clientWidth
      if (!frameWidth) return

      const scale = frameWidth / PREVIEW_CANVAS_WIDTH
      canvas.style.transform = `scale(${scale})`
      frame.style.height = `${canvas.offsetHeight * scale}px`
    })
  }

  #selectedTheme() {
    const checked = this.themeInputTargets.find((input) => input.checked)
    return checked?.value || "kiosk-default"
  }

  #previewStyle(selectedTheme) {
    const declarations = []

    if (selectedTheme === "custom") {
      this.colorInputTargets.forEach((input) => {
        const cssKey = input.dataset.colorKey.replace(/_/g, "-")
        declarations.push(`--color-${cssKey}: ${input.value}`)
      })
    }

    this.radiusInputTargets.forEach((input) => {
      if (!input.value) return
      const cssKey = input.dataset.radiusKey.replace(/_/g, "-")
      declarations.push(`--${cssKey}: ${input.value}`)
    })

    return declarations.map((declaration) => `${declaration};`).join(" ")
  }

  #syncColorLabels() {
    this.colorInputTargets.forEach((input) => {
      const label = this.colorValueTargets.find((node) => node.dataset.colorKey === input.dataset.colorKey)
      if (label) label.textContent = input.value
    })
  }

  #watchPreviewAssets() {
    this.previewTarget.querySelectorAll("img").forEach((image) => {
      if (image.complete) return
      image.addEventListener("load", () => this.resizeFrames(), { once: true })
    })
  }
}
