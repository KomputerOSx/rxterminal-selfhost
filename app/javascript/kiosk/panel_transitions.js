const DURATION_MS = 280

export function showPanelImmediate(panels, activePanel) {
  panels.forEach((panel) => {
    panel.dataset.active = "false"
    delete panel.dataset.exiting
    delete panel.dataset.entering
    panel.style.transition = "none"
  })

  activePanel.dataset.active = "true"

  requestAnimationFrame(() =>
    requestAnimationFrame(() => {
      panels.forEach((panel) => panel.style.removeProperty("transition"))
    })
  )
}

export function transitionPanels(fromPanel, toPanel, direction = "forward") {
  fromPanel.dataset.exiting = direction
  fromPanel.dataset.active = "false"

  toPanel.dataset.entering = direction
  toPanel.style.pointerEvents = "none"
  toPanel.style.transition = "none"
  toPanel.dataset.active = "true"
  void toPanel.offsetWidth
  toPanel.style.removeProperty("transition")

  requestAnimationFrame(() => {
    delete toPanel.dataset.entering
  })

  window.setTimeout(() => {
    delete fromPanel.dataset.exiting
    toPanel.style.removeProperty("pointer-events")
  }, DURATION_MS + 24)

  return DURATION_MS
}

export { DURATION_MS as KIOSK_PANEL_TRANSITION_MS }
