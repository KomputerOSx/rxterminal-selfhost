import { Controller } from "@hotwired/stimulus"

// Optimistic UI updates for queue management forms.
// On submit, removes the current card and shows a skeleton in the target column
// until the Turbo Stream response (or broadcast) replaces it.
export default class extends Controller {
  static values = {
    target: String,
    requestId: Number,
    callNext: Boolean
  }

  connect() {
    this.boundHandleSubmitCapture = this.handleSubmitCapture.bind(this)
    this.boundHandleSubmitStart = this.handleSubmitStart.bind(this)
    this.boundHandleSubmitEnd = this.handleSubmitEnd.bind(this)
    this.boundHandleStreamRender = this.handleStreamRender.bind(this)

    this.element.addEventListener("submit", this.boundHandleSubmitCapture, { capture: true })
    this.element.addEventListener("turbo:submit-start", this.boundHandleSubmitStart)
    this.element.addEventListener("turbo:submit-end", this.boundHandleSubmitEnd)
    document.addEventListener("turbo:before-stream-render", this.boundHandleStreamRender)
  }

  disconnect() {
    this.element.removeEventListener("submit", this.boundHandleSubmitCapture, { capture: true })
    this.element.removeEventListener("turbo:submit-start", this.boundHandleSubmitStart)
    this.element.removeEventListener("turbo:submit-end", this.boundHandleSubmitEnd)
    document.removeEventListener("turbo:before-stream-render", this.boundHandleStreamRender)
  }

  handleSubmitCapture(event) {
    if (!this.callNextValue || this.hasWaitingCustomer()) return

    event.preventDefault()
    event.stopImmediatePropagation()
  }

  hasWaitingCustomer() {
    const waitingContainer = document.getElementById("waiting-cards")
    return Boolean(waitingContainer?.querySelector("[data-request-id]"))
  }

  handleStreamRender(event) {
    const streamElement = event.target
    if (!streamElement?.templateElement) return

    const broadcastFrame = streamElement.templateElement.content.querySelector("turbo-frame")
    if (!broadcastFrame?.id) return

    const skeletonFrame = document.querySelector(
      `turbo-frame[data-skeleton="true"][id="${broadcastFrame.id}"]`
    )
    if (!skeletonFrame) return

    if (this.skeletonTimeout) {
      clearTimeout(this.skeletonTimeout)
      this.skeletonTimeout = null
    }

    skeletonFrame.remove()
    this.currentSkeleton = null
  }

  handleSubmitStart(event) {
    let currentCard

    if (this.callNextValue) {
      if (!this.hasWaitingCustomer()) return

      currentCard = document
        .getElementById("waiting-cards")
        .querySelector("[data-request-id]")
        .closest("turbo-frame")
      if (!currentCard) return
    } else {
      currentCard = this.element.closest("turbo-frame")
      if (!currentCard) return
    }

    const customerData = this.extractCustomerData(currentCard)

    this.rollbackData = {
      card: currentCard.cloneNode(true),
      parent: currentCard.parentElement,
      nextSibling: currentCard.nextSibling
    }

    const targetContainer = this.getTargetContainer(this.targetValue)

    if (this.targetValue === "cancelled") {
      currentCard.remove()
    } else if (targetContainer) {
      this.createSkeletonCard(customerData, targetContainer, this.targetValue)
      currentCard.remove()
    }
  }

  handleSubmitEnd(event) {
    const { success } = event.detail

    if (!success) {
      if (this.skeletonTimeout) clearTimeout(this.skeletonTimeout)

      if (this.currentSkeleton?.parentElement) {
        this.currentSkeleton.remove()
      }

      this.rollback()

      if (this.rollbackData) {
        this.showToast("error", "Failed to update status. Please try again.")
      }
    } else {
      this.rollbackData = null
      this.currentSkeleton = null
    }
  }

  handleTimeout(skeletonFrame) {
    skeletonFrame.remove()

    if (this.rollbackData) {
      const { card, parent, nextSibling } = this.rollbackData

      if (nextSibling?.parentElement) {
        parent.insertBefore(card, nextSibling)
      } else {
        parent.appendChild(card)
      }
    }

    this.showToast("error", "Request timed out. Please try again.")
  }

  getTargetContainer(status) {
    const containers = {
      waiting: document.getElementById("waiting-cards"),
      in_progress: document.getElementById("in-progress-cards"),
      completed: document.getElementById("completed-cards")
    }
    return containers[status]
  }

  extractCustomerData(card) {
    const innerCard = card.querySelector("[data-request-id], [data-skeleton-card]")
    const queueNumberEl = innerCard?.querySelector(".font-black.leading-none, .font-black")
    const queueNumber = queueNumberEl?.textContent.trim() || innerCard?.dataset.queueNumber || "0"

    const nameEl = innerCard?.querySelector(".font-bold, .font-semibold")
    const customerName = nameEl?.textContent.trim() || "Unknown customer"

    const requestId = card.id.match(/service_request_(\d+)/)?.[1]
    const serviceId = innerCard?.dataset.serviceId || null

    return { requestId, queueNumber, customerName, serviceId }
  }

  createSkeletonCard(customerData, container, newStatus) {
    const { requestId, queueNumber, customerName, serviceId } = customerData
    const templateId = `skeleton-${newStatus.replace("_", "-")}-template`
    const template = document.getElementById(templateId)
    if (!template) return null

    const skeletonFrame = document.createElement("turbo-frame")
    skeletonFrame.id = `${newStatus}_service_request_${requestId}`
    skeletonFrame.setAttribute("data-skeleton", "true")

    const clone = template.content.cloneNode(true)

    const queueNumberEl = clone.querySelector('[data-skeleton-field="queue-number"]')
    if (queueNumberEl) queueNumberEl.textContent = queueNumber

    const nameEl = clone.querySelector('[data-skeleton-field="customer-name"]')
    if (nameEl) nameEl.textContent = customerName

    const cardEl = clone.querySelector("[data-skeleton-card]")
    if (cardEl) {
      if (requestId) cardEl.setAttribute("data-request-id", requestId)
      if (serviceId) cardEl.setAttribute("data-service-id", serviceId)
    }

    skeletonFrame.appendChild(clone)

    if (newStatus === "in_progress") {
      container.appendChild(skeletonFrame)
    } else {
      container.prepend(skeletonFrame)
    }

    this.currentSkeleton = skeletonFrame

    this.skeletonTimeout = setTimeout(() => {
      if (skeletonFrame.parentElement) this.handleTimeout(skeletonFrame)
    }, 10000)

    return skeletonFrame
  }

  rollback() {
    if (!this.rollbackData) return

    const { card, parent, nextSibling } = this.rollbackData
    const movedCard = document.getElementById(card.id)

    if (movedCard) movedCard.remove()

    if (nextSibling?.parentElement) {
      parent.insertBefore(card, nextSibling)
    } else {
      parent.appendChild(card)
    }
  }

  showToast(type, message) {
    if (typeof window.toast === "function") {
      window.toast(message, { type })
      return
    }

    alert(message)
  }
}
