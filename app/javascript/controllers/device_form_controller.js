import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["deviceId", "registeredIp"]
  static values = { serverIp: String, orgSlug: String }

  generateDeviceId() {
    const slug = (this.orgSlugValue || "kiosk").replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "")
    const suffix = Math.random().toString(36).slice(2, 6)
    this.deviceIdTarget.value = `${slug}_${suffix}`
  }

  useMyIp() {
    this.registeredIpTarget.value = this.serverIpValue
  }
}
