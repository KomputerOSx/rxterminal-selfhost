import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: { type: String, default: "managers" } }

  select(event) {
    this.activeValue = event.currentTarget.dataset.audienceTabKey
  }

  activeValueChanged(value) {
    this.tabTargets.forEach((tab) => {
      tab.classList.toggle("aud-tab--active", tab.dataset.audienceTabKey === value)
    })
    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.audienceTabKey !== value
    })
  }
}
