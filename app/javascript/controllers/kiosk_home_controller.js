import { Controller } from "@hotwired/stimulus"
import { setPageDirection } from "kiosk/page_transitions"

export default class extends Controller {
  start(event) {
    event.preventDefault()

    const el = event.currentTarget
    el.addEventListener("click", (e) => e.preventDefault(), { once: true })
    this.#press(el)

    const url = el.dataset.url
    if (url) {
      setPageDirection("forward")
      setTimeout(() => Turbo.visit(url), 130)
    }
  }

  #press(el) {
    el.classList.add("scale-[0.97]")
    setTimeout(() => el.classList.remove("scale-[0.97]"), 150)
  }
}
