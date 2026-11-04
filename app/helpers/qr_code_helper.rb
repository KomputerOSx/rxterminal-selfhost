# frozen_string_literal: true

module QrCodeHelper
  QR_SVG_TAGS = %w[svg path rect g].freeze
  QR_SVG_ATTRIBUTES = %w[
    xmlns viewBox width height d fill id class version shape-rendering transform
  ].freeze

  def sanitized_qr_svg(svg)
    sanitize(svg, tags: QR_SVG_TAGS, attributes: QR_SVG_ATTRIBUTES)
  end
end
