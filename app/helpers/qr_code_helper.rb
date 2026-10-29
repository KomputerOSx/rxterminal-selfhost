# frozen_string_literal: true

module QrCodeHelper
  QR_SVG_TAGS = %w[svg path rect g].freeze
  QR_SVG_ATTRIBUTES = %w[
    xmlns viewBox width height d fill id class version shape-rendering transform
  ].freeze

  def sanitized_qr_svg(svg)
    sanitize(svg, tags: QR_SVG_TAGS, attributes: QR_SVG_ATTRIBUTES)
  end

  def marketing_hero_qr_svg
    @marketing_hero_qr_svg ||= begin
      qr = RQRCode::QRCode.new("https://rxterminal.app", level: :m)
      sanitized_qr_svg(qr.as_svg(
        offset: 0,
        color: "135bf9",
        shape_rendering: "crispEdges",
        module_size: 3,
        standalone: true,
        use_path: true
      ))
    end
  end
end
