# frozen_string_literal: true

# Email-safe hex values converted from the DaisyUI light theme tokens in
# app/assets/tailwind/application.css.
module MailerTheme
  BASE_100 = "#f8f8f8"
  BASE_200 = "#f5f5f4"
  BASE_300 = "#d4d0ce"
  BASE_CONTENT = "#000000"

  BODY_BG = BASE_100
  HEADER_FOOTER_BG = BASE_200
  HEADER_FOOTER_TEXT = BASE_CONTENT
  HEADER_FOOTER_BORDER = BASE_300

  BODY_TEXT = "#374151"
  HEADING_TEXT = "#111827"
  MUTED_TEXT = "#6b7280"
  LIGHT_MUTED = "#9ca3af"
  FOOTER_MUTED = "#6b7280"

  CARD_BG = "#ffffff"
  CARD_BORDER = BASE_300
  PRIMARY = "#135bf9"
  PRIMARY_CONTENT = "#ffffff"

  MAX_WIDTH = 600
  LOGO_FILENAME = "rxterminal-title.png"
  LOGO_PATH = Rails.root.join("app/assets/images/RxTerminal-Title.png")
  LOGO_SMALL_FILENAME = "rxterminal-title-small.png"
  LOGO_SMALL_PATH = Rails.root.join("app/assets/images/RxTerminal-Title-small.png")
end
