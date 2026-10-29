import { Controller } from "@hotwired/stimulus"

// Client-side service filter for queue cards and stat counters.
export default class extends Controller {
  static values = {
    serviceIds: { type: Array, default: [] }
  }

  connect() {
    this.applyFilter()
    this.setupObserver()
    this.boundInterceptStats = this.interceptStats.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundInterceptStats)
  }

  disconnect() {
    this.observer?.disconnect()
    document.removeEventListener("turbo:before-stream-render", this.boundInterceptStats)
  }

  serviceIdsValueChanged() {
    this.applyFilter()
  }

  applyFilter() {
    const ids = this.serviceIdsValue

    document.querySelectorAll("[data-service-id]").forEach((card) => {
      const cardServiceId = parseInt(card.dataset.serviceId, 10)
      const target = card.closest("turbo-frame") || card
      if (ids.length === 0 || ids.includes(cardServiceId)) {
        target.style.display = ""
      } else {
        target.style.display = "none"
      }
    })

    // With no filter active, the server (broadcast/poll) is the sole source of truth for the
    // stat counters - recomputing from currently-rendered cards here would race with it and
    // flicker to a different (and incomplete - e.g. it can't see cancelled requests) number.
    // Only take over once a filter narrows the board to a subset the server counts don't reflect.
    if (ids.length > 0) this.updateStats()
  }

  updateStats() {
    const waitingCount = this.countVisible("#waiting-cards")
    const inProgressCount = this.countVisible("#in-progress-cards")
    const completedCount = this.countVisible("#completed-cards")

    const statWaiting = document.getElementById("stat-waiting")
    const statInProgress = document.getElementById("stat-in-progress")
    const statCompleted = document.getElementById("stat-completed")
    const statTotal = document.getElementById("stat-total")

    if (statWaiting) statWaiting.textContent = waitingCount
    if (statInProgress) statInProgress.textContent = inProgressCount
    if (statCompleted) statCompleted.textContent = completedCount
    if (statTotal) statTotal.textContent = waitingCount + inProgressCount + completedCount
  }

  countVisible(containerSelector) {
    const container = document.querySelector(containerSelector)
    if (!container) return 0

    return Array.from(container.querySelectorAll("[data-service-id]")).filter((el) => {
      const frame = el.closest("turbo-frame")
      return frame ? frame.style.display !== "none" : el.style.display !== "none"
    }).length
  }

  setupObserver() {
    const containers = ["#waiting-cards", "#in-progress-cards", "#completed-cards"]
      .map((selector) => document.querySelector(selector))
      .filter(Boolean)

    if (!containers.length) return

    this.observer = new MutationObserver(() => this.applyFilter())
    containers.forEach((container) => {
      this.observer.observe(container, { childList: true, subtree: false })
    })
  }

  toggleCheckbox(event) {
    const serviceId = parseInt(event.currentTarget.value, 10)
    const current = [...this.serviceIdsValue]
    const idx = current.indexOf(serviceId)

    if (event.currentTarget.checked) {
      if (idx < 0) current.push(serviceId)
    } else if (idx >= 0) {
      current.splice(idx, 1)
    }

    this.serviceIdsValue = current
    this.updateUrl(current)
    this.updateDropdownLabel(current)
    this.syncCallNextForm(current)
  }

  clear() {
    this.serviceIdsValue = []
    this.updateUrl([])
    this.element.querySelectorAll("[data-queue-filter-checkbox]").forEach((checkbox) => {
      checkbox.checked = false
    })
    this.updateDropdownLabel([])
    this.syncCallNextForm([])
  }

  updateDropdownLabel(ids) {
    const label = this.element.querySelector("[data-queue-filter-label]")
    if (!label) return

    if (ids.length === 0) {
      label.textContent = "All services"
    } else {
      label.textContent = `${ids.length} ${ids.length === 1 ? "service" : "services"}`
    }
  }

  syncCallNextForm(ids) {
    const form = document.getElementById("call-next-form")
    if (!form) return

    form.querySelectorAll('input[name="service_ids[]"]').forEach((el) => el.remove())
    ids.forEach((id) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "service_ids[]"
      input.value = id
      form.appendChild(input)
    })
  }

  updateUrl(ids) {
    const url = new URL(window.location.href)
    url.searchParams.delete("service_ids[]")
    ids.forEach((id) => url.searchParams.append("service_ids[]", id))
    window.history.replaceState({}, "", url.toString())
  }

  interceptStats(event) {
    if (this.serviceIdsValue.length === 0) return

    const statTargets = new Set(["stat-waiting", "stat-in-progress", "stat-completed", "stat-total"])
    const target = event.target?.getAttribute?.("target")

    if (target && statTargets.has(target)) {
      event.detail.render = () => this.updateStats()
    }
  }
}
