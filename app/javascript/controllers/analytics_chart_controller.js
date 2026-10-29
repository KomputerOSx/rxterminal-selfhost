import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"

Chart.register(...registerables)

const COLOR_TOKENS = new Set([
  "primary",
  "secondary",
  "accent",
  "neutral",
  "info",
  "success",
  "warning",
  "error"
])

export default class extends Controller {
  static values = {
    chartType: { type: String, default: "line" },
    labels: Array,
    datasets: Array,
    stacked: { type: Boolean, default: false }
  }

  connect() {
    this.colorProbe = document.createElement("div")
    this.colorProbe.hidden = true
    document.body.appendChild(this.colorProbe)

    this.renderChart()

    this.themeObserver = new MutationObserver(() => this.updateTheme())
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme"]
    })
  }

  disconnect() {
    this.themeObserver?.disconnect()
    this.colorProbe?.remove()
    this.chart?.destroy()
  }

  renderChart() {
    const horizontal = this.chartTypeValue === "horizontalBar"
    const type = horizontal ? "bar" : this.chartTypeValue

    this.chart?.destroy()

    this.chart = new Chart(this.element, {
      type,
      data: {
        labels: this.labelsValue,
        datasets: this.normalizedDatasets()
      },
      options: this.buildOptions()
    })
  }

  updateTheme() {
    if (!this.chart) return

    const { tick, grid } = this.themeColors()

    this.chart.options.plugins.legend.labels.color = tick

    for (const axis of ["x", "y"]) {
      const scale = this.chart.options.scales[axis]
      scale.ticks.color = tick
      scale.grid.color = grid
    }

    this.chart.data.datasets = this.normalizedDatasets()
    this.chart.update()
  }

  buildOptions() {
    const horizontal = this.chartTypeValue === "horizontalBar"
    const { tick, grid } = this.themeColors()

    return {
      responsive: true,
      maintainAspectRatio: false,
      indexAxis: horizontal ? "y" : "x",
      plugins: {
        legend: {
          display: this.datasetsValue.length > 1,
          labels: { boxWidth: 12, usePointStyle: true, color: tick }
        }
      },
      scales: {
        x: {
          stacked: this.stackedValue,
          beginAtZero: true,
          ticks: { color: tick },
          grid: { color: grid },
          border: { display: false }
        },
        y: {
          stacked: this.stackedValue,
          beginAtZero: true,
          ticks: { precision: 0, color: tick },
          grid: { color: grid },
          border: { display: false }
        }
      }
    }
  }

  themeColors() {
    return {
      tick: this.toRgba(this.cssVar("--color-base-content"), 0.6),
      grid: this.toRgba(this.cssVar("--color-base-300"), 0.55)
    }
  }

  normalizedDatasets() {
    return this.datasetsValue.map((dataset) => {
      const raw = dataset.backgroundColor || dataset.borderColor || "primary"
      const isArray = Array.isArray(raw)
      const alpha = this.chartTypeValue === "line" ? 0.14 : 0.85

      return {
        ...dataset,
        borderWidth: 2,
        pointRadius: this.chartTypeValue === "line" ? 3 : 0,
        pointHoverRadius: this.chartTypeValue === "line" ? 5 : 0,
        backgroundColor: isArray
          ? raw.map((color) => this.toRgba(this.resolveColor(color), alpha))
          : this.toRgba(this.resolveColor(raw), alpha),
        borderColor: isArray
          ? raw.map((color) => this.toRgba(this.resolveColor(color), 1))
          : this.toRgba(this.resolveColor(raw), 1)
      }
    })
  }

  themeRoot() {
    return this.element.closest("[data-theme]") || document.documentElement
  }

  cssVar(name) {
    return getComputedStyle(this.themeRoot()).getPropertyValue(name).trim()
  }

  resolveColor(color) {
    if (typeof color === "string" && COLOR_TOKENS.has(color)) {
      return this.cssVar(`--color-${color}`)
    }

    return color
  }

  toRgba(color, alpha = 1) {
    if (!color || typeof color !== "string") return `rgba(128, 128, 128, ${alpha})`

    const rgbaMatch = color.match(/^rgba?\(([^)]+)\)$/)
    if (rgbaMatch) {
      const parts = rgbaMatch[1].split(",").map((part) => part.trim())
      const existingAlpha = parts[3] !== undefined ? parseFloat(parts[3]) : 1
      return `rgba(${parts[0]}, ${parts[1]}, ${parts[2]}, ${alpha * existingAlpha})`
    }

    this.colorProbe.style.color = ""
    this.colorProbe.style.color = color
    const resolved = getComputedStyle(this.colorProbe).color
    const rgbMatch = resolved.match(/^rgba?\((\d+),\s*(\d+),\s*(\d+)/)
    if (!rgbMatch) return color

    return `rgba(${rgbMatch[1]}, ${rgbMatch[2]}, ${rgbMatch[3]}, ${alpha})`
  }
}
