import { Controller } from "@hotwired/stimulus"

// Pre-selects the visitor's browser-detected time zone in a <select> populated by Rails'
// time_zone_select, so the field defaults to "wherever you actually are" instead of a fixed
// value. Only runs when data-timezone-detect-auto-value is true (e.g. the field is still at
// its unconfigured default) - never overrides an explicit choice already saved.
export default class extends Controller {
  static targets = ["select"]
  static values = { mapping: Object, auto: Boolean }

  connect() {
    if (!this.autoValue) return

    const detected = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (!detected) return

    const match = Object.entries(this.mappingValue).find(([ , tzInfoName ]) => tzInfoName === detected)
    if (!match) return

    const [ friendlyName ] = match
    const option = Array.from(this.selectTarget.options).find((o) => o.value === friendlyName)
    if (option) this.selectTarget.value = friendlyName
  }
}
