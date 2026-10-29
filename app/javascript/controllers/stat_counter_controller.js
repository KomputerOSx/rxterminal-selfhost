import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["number"]

  connect() {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            this.#run()
            observer.disconnect()
          }
        })
      },
      { threshold: 0.4 }
    )
    observer.observe(this.element)
  }

  #run() {
    this.numberTargets.forEach((el) => {
      const end = parseInt(el.dataset.end, 10)
      const duration = parseInt(el.dataset.duration, 10)
      const suffix = el.dataset.suffix || ""
      const start = performance.now()

      const tick = (now) => {
        const progress = Math.min((now - start) / duration, 1)
        const eased = 1 - Math.pow(1 - progress, 3)
        el.textContent = Math.round(eased * end) + suffix
        if (progress < 1) requestAnimationFrame(tick)
      }
      requestAnimationFrame(tick)
    })
  }
}
