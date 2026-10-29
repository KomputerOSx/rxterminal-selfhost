import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { data: Array }

  connect() {
    this.render()
  }

  render() {
    const data = this.dataValue
    const width = this.element.clientWidth || 480
    const height = 80
    const pad = { top: 8, bottom: 24, left: 4, right: 4 }
    const innerW = width - pad.left - pad.right
    const innerH = height - pad.top - pad.bottom
    const n = data.length
    const barW = Math.floor(innerW / n) - 3

    const maxVal = Math.max(...data.map((d) => d.conversions + d.declines), 1)

    const bars = data.map((d, i) => {
      const x = pad.left + i * (innerW / n)
      const totalH = Math.round(((d.conversions + d.declines) / maxVal) * innerH)
      const acceptedH = Math.round((d.conversions / maxVal) * innerH)
      const declinedH = totalH - acceptedH
      const yAccepted = pad.top + innerH - acceptedH
      const yDeclined = yAccepted - declinedH

      return `
        ${declinedH > 0 ? `<rect x="${x}" y="${yDeclined}" width="${barW}" height="${declinedH}" fill="oklch(82% 0.02 250)" rx="2"/>` : ""}
        ${acceptedH > 0 ? `<rect x="${x}" y="${yAccepted}" width="${barW}" height="${acceptedH}" fill="oklch(62% 0.18 145)" rx="2"/>` : ""}
        <text x="${x + barW / 2}" y="${height - 4}" text-anchor="middle" font-size="9" fill="currentColor">${d.date}</text>
      `
    }).join("")

    this.element.innerHTML = `
      <svg viewBox="0 0 ${width} ${height}" width="100%" height="${height}" xmlns="http://www.w3.org/2000/svg" class="text-base-content/50">
        ${bars}
      </svg>
      <div class="flex items-center gap-4 mt-2 text-xs text-base-content/50">
        <span class="flex items-center gap-1"><span class="inline-block w-3 h-3 rounded-sm bg-success"></span> Accepted</span>
        <span class="flex items-center gap-1"><span class="inline-block w-3 h-3 rounded-sm bg-base-300"></span> Declined</span>
      </div>
    `
  }
}
