import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  selectedCard = null
  selectedColumn = null
  observer = null

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
    this.setupMutationObserver()
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
    this.observer?.disconnect()
    this.clearSelection()
  }

  handleKeydown(event) {
    if (this.isTypingInInput()) return

    switch (event.key) {
      case "ArrowUp":
        event.preventDefault()
        this.navigateVertical("up")
        break
      case "ArrowDown":
        event.preventDefault()
        this.navigateVertical("down")
        break
      case "ArrowLeft":
        event.preventDefault()
        this.navigateHorizontal("left")
        break
      case "ArrowRight":
        event.preventDefault()
        this.navigateHorizontal("right")
        break
      case "n":
      case "N":
        this.callNextCustomer()
        break
      case "p":
      case "P":
        this.completeTopCustomer()
        break
      case "r":
      case "R":
        this.refreshQueue()
        break
      case "z":
        if (event.ctrlKey || event.metaKey) {
          event.preventDefault()
          this.revertLastCompleted()
        }
        break
      case "Enter":
        this.handleEnterKey()
        break
      case "Backspace":
        this.handleBackspaceKey(event)
        break
      case "Escape":
        this.clearSelection()
        break
    }
  }

  isTypingInInput() {
    const activeElement = document.activeElement
    return activeElement && (
      activeElement.tagName === "INPUT" ||
      activeElement.tagName === "TEXTAREA" ||
      activeElement.tagName === "SELECT" ||
      activeElement.isContentEditable
    )
  }

  navigateVertical(direction) {
    const cards = this.getCardsInColumn(this.selectedColumn || "waiting")
    if (cards.length === 0) return

    if (!this.selectedCard) {
      this.selectCard(cards[0])
      return
    }

    const currentIndex = cards.indexOf(this.selectedCard)
    let newIndex = direction === "up" ? currentIndex - 1 : currentIndex + 1
    newIndex = Math.max(0, Math.min(newIndex, cards.length - 1))

    if (newIndex !== currentIndex) {
      this.selectCard(cards[newIndex])
    }
  }

  navigateHorizontal(direction) {
    const targetColumn = direction === "left" ? "waiting" : "in_progress"
    const cards = this.getCardsInColumn(targetColumn)
    if (cards.length === 0) return

    this.selectCard(cards[0])
  }

  callNextCustomer() {
    const waitingCards = this.getCardsInColumn("waiting")
    if (waitingCards.length === 0) return

    const form = this.findFormWithStatus(waitingCards[0], "in_progress")
    form?.requestSubmit()
  }

  refreshQueue() {
    document.querySelector('[data-queue-target="refreshBtn"]')?.click()
  }

  completeTopCustomer() {
    const inProgressCards = this.getCardsInColumn("in_progress")
    if (inProgressCards.length === 0) return

    const topCard = inProgressCards[0]
    const completeForm = this.findFormWithStatus(topCard, "completed")
    if (!completeForm) return

    completeForm.requestSubmit()
    if (this.selectedCard === topCard) this.clearSelection()
  }

  revertLastCompleted() {
    const completedCards = this.getCardsInColumn("completed")
    if (completedCards.length === 0) return

    const revertForm = this.findRevertForm(completedCards[0])
    revertForm?.requestSubmit()
  }

  handleEnterKey() {
    if (!this.selectedCard) return

    const column = this.getCardColumn(this.selectedCard)
    const targetStatus = column === "waiting" ? "in_progress" : "completed"
    const form = this.findFormWithStatus(this.selectedCard, targetStatus)
    if (!form) return

    form.requestSubmit()
    this.clearSelection()
  }

  handleBackspaceKey(event) {
    event.preventDefault()
    if (!this.selectedCard) return

    const column = this.getCardColumn(this.selectedCard)
    const targetStatus = column === "waiting" ? "cancelled" : "waiting"
    const form = this.findFormWithStatus(this.selectedCard, targetStatus)
    if (!form) return

    if (column === "waiting") {
      const submitButton = form.querySelector('button[type="submit"], input[type="submit"]')
      submitButton?.click()
    } else {
      form.requestSubmit()
    }

    this.clearSelection()
  }

  selectCard(card) {
    this.clearSelection()

    card.setAttribute("data-keyboard-selected", "true")
    card.classList.add(
      "keyboard-selected",
      "border-2",
      "border-primary",
      "bg-primary/10",
      "transition-all",
      "duration-200"
    )

    this.selectedCard = card
    this.selectedColumn = this.getCardColumn(card)

    card.scrollIntoView({ behavior: "smooth", block: "nearest" })
    this.announceSelection(card)
  }

  clearSelection() {
    if (!this.selectedCard) return

    this.selectedCard.removeAttribute("data-keyboard-selected")
    this.selectedCard.classList.remove(
      "keyboard-selected",
      "border-2",
      "border-primary",
      "bg-primary/10"
    )

    this.selectedCard = null
    this.selectedColumn = null
  }

  getCardsInColumn(column) {
    const containerId = {
      waiting: "waiting-cards",
      in_progress: "in-progress-cards",
      completed: "completed-cards"
    }[column]

    const container = containerId ? document.getElementById(containerId) : null
    if (!container) return []

    return Array.from(container.querySelectorAll("[data-request-id]"))
      .filter((card) => {
        const frame = card.closest("turbo-frame")
        if (frame?.getAttribute("data-skeleton") === "true") return false

        const visibleTarget = frame || card
        return visibleTarget.style.display !== "none"
      })
  }

  getCardColumn(card) {
    return card.closest("#waiting-cards") ? "waiting" : "in_progress"
  }

  findFormWithStatus(card, targetStatus) {
    for (const form of card.querySelectorAll("form")) {
      const statusInput = form.querySelector('input[name="status"]')
      if (statusInput?.value === targetStatus) return form
    }

    return null
  }

  findRevertForm(card) {
    for (const form of card.querySelectorAll("form")) {
      if (form.action?.includes("revert_completed")) return form
    }

    return null
  }

  setupMutationObserver() {
    this.observer = new MutationObserver(() => {
      if (this.selectedCard && !document.body.contains(this.selectedCard)) {
        this.clearSelection()
        return
      }

      if (this.selectedCard) {
        const newColumn = this.getCardColumn(this.selectedCard)
        if (newColumn !== this.selectedColumn) this.selectedColumn = newColumn
      }
    })

    for (const id of ["waiting-cards", "in-progress-cards"]) {
      const container = document.getElementById(id)
      if (container) this.observer.observe(container, { childList: true, subtree: true })
    }
  }

  showShortcutsDialog() {
    const modal = document.createElement("dialog")
    modal.className = "modal modal-open"
    modal.innerHTML = `
      <div class="modal-box max-w-2xl border border-base-300">
        <h3 class="mb-4 text-lg font-bold">Keyboard shortcuts</h3>
        <div class="space-y-6">
          <div>
            <h4 class="mb-2 font-semibold">Navigation</h4>
            <div class="grid grid-cols-1 gap-2 sm:grid-cols-2">
              <div class="flex items-center gap-2"><kbd class="kbd kbd-sm">↑</kbd><span class="text-sm">Move up in column</span></div>
              <div class="flex items-center gap-2"><kbd class="kbd kbd-sm">↓</kbd><span class="text-sm">Move down in column</span></div>
              <div class="flex items-center gap-2"><kbd class="kbd kbd-sm">←</kbd><span class="text-sm">Waiting column</span></div>
              <div class="flex items-center gap-2"><kbd class="kbd kbd-sm">→</kbd><span class="text-sm">In progress column</span></div>
            </div>
          </div>
          <div>
            <h4 class="mb-2 font-semibold">Actions</h4>
            <div class="grid grid-cols-1 gap-2">
              <div class="flex items-center gap-2"><kbd class="kbd kbd-sm">N</kbd><span class="text-sm">Call next customer</span></div>
              <div class="flex items-center gap-2"><kbd class="kbd kbd-sm">P</kbd><span class="text-sm">Complete top in-progress customer</span></div>
              <div class="flex items-center gap-2"><kbd class="kbd kbd-sm">R</kbd><span class="text-sm">Refresh queue and waiting display</span></div>
              <div class="flex items-center gap-2"><kbd class="kbd kbd-sm">Ctrl+Z</kbd><span class="text-sm">Revert most recent completed customer</span></div>
              <div class="flex items-center gap-2"><kbd class="kbd kbd-sm">Enter</kbd><span class="text-sm">Call (waiting) or complete (in progress)</span></div>
              <div class="flex items-center gap-2"><kbd class="kbd kbd-sm">Backspace</kbd><span class="text-sm">Cancel (waiting) or return to queue (in progress)</span></div>
              <div class="flex items-center gap-2"><kbd class="kbd kbd-sm">Esc</kbd><span class="text-sm">Clear selection</span></div>
            </div>
          </div>
        </div>
        <div class="modal-action">
          <button type="button" class="btn btn-sm" data-shortcuts-close>Close</button>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop"><button>close</button></form>
    `

    const close = () => modal.remove()
    modal.querySelector("[data-shortcuts-close]")?.addEventListener("click", close)
    modal.addEventListener("close", close)
    document.body.appendChild(modal)
    modal.showModal()
  }

  announceSelection(card) {
    const nameEl = card.querySelector(".font-bold, .font-semibold")
    const queueNumberEl = card.querySelector(".font-black")
    const column = this.getCardColumn(card)

    const name = nameEl?.textContent.trim() || "Unknown"
    const number = queueNumberEl?.textContent.trim() || "?"
    const columnName = column === "waiting" ? "waiting queue" : "in progress"

    this.announce(`Selected customer ${number}, ${name}, in ${columnName}`)
  }

  announce(message) {
    let liveRegion = document.getElementById("keyboard-nav-announcements")

    if (!liveRegion) {
      liveRegion = document.createElement("div")
      liveRegion.id = "keyboard-nav-announcements"
      liveRegion.setAttribute("role", "status")
      liveRegion.setAttribute("aria-live", "polite")
      liveRegion.setAttribute("aria-atomic", "true")
      liveRegion.className = "absolute -m-px h-px w-px overflow-hidden whitespace-nowrap border-0 p-0"
      document.body.appendChild(liveRegion)
    }

    liveRegion.textContent = message
  }
}
