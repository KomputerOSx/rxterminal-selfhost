import { Controller } from "@hotwired/stimulus"
import { setPageDirection } from "kiosk/page_transitions"

export default class extends Controller {
  blockLink(event) {
    event.preventDefault()
  }

  press(event) {
    event.preventDefault()
    const el = event.currentTarget

    el.addEventListener("click", (e) => e.preventDefault(), { once: true })

    const url = el.href || el.dataset.url
    el.classList.add("scale-[0.97]")
    setTimeout(() => el.classList.remove("scale-[0.97]"), 150)
    setPageDirection(el.dataset.kioskNav === "back" ? "back" : "forward")
    setTimeout(() => Turbo.visit(url), 130)
  }
}
