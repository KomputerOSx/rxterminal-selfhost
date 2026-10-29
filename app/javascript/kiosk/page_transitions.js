const DIRECTION_KEY = "kiosk:page-direction"

export function setPageDirection(direction) {
  sessionStorage.setItem(DIRECTION_KEY, direction)
}

export function consumePageDirection() {
  const direction = sessionStorage.getItem(DIRECTION_KEY) || "forward"
  sessionStorage.removeItem(DIRECTION_KEY)
  return direction
}

function kioskBody(body = document.body) {
  return body?.dataset?.kioskApp === "true"
}

function kioskLink(link) {
  if (!link?.href) return false
  if (link.target === "_blank") return false
  if (link.origin !== window.location.origin) return false
  if (link.hasAttribute("download")) return false
  if (link.dataset.turbo === "false") return false
  return link.pathname.startsWith("/kiosk")
}

function applyVisitDirection() {
  const direction = consumePageDirection()
  document.documentElement.dataset.kioskVt = direction
}

function clearVisitDirection() {
  delete document.documentElement.dataset.kioskVt
}

export function installKioskPageTransitions() {
  // Capture direction before Stimulus press handlers call Turbo.visit()
  document.addEventListener("pointerdown", (event) => {
    if (!kioskBody()) return

    const link = event.target.closest("a[href]")
    if (!link || !kioskLink(link)) return

    setPageDirection(link.dataset.kioskNav === "back" ? "back" : "forward")
  }, true)

  document.addEventListener("turbo:visit", (event) => {
    if (!kioskBody()) return

    if (event.detail.action === "restore" && !sessionStorage.getItem(DIRECTION_KEY)) {
      setPageDirection("back")
    }

    applyVisitDirection()
  })

  document.addEventListener("turbo:render", () => {
    if (document.documentElement.dataset.kioskVt) clearVisitDirection()
  })
}
