# frozen_string_literal: true

# Builds the destination URL/label/SVG for the public-portal QR code shown on the staff waiting
# display (Org::WaitingDisplayController).
module PortalQrCode
  extend ActiveSupport::Concern

  PortalQrContext = Struct.new(:url, :label, keyword_init: true)

  private

  # nil when the org has nothing worth scanning for (umbrella public_portal is on, but no
  # sub-feature is) - callers should skip rendering the QR block entirely in that case.
  def portal_qr_context(organization)
    walk_in = organization.mobile_service_request_enabled?
    check_in = organization.online_appointment_check_enabled?
    booking = organization.online_appointment_booking_enabled?

    if walk_in || check_in
      label = if walk_in && check_in
        "Scan to check in or join the queue"
      elsif check_in
        "Scan to check in"
      else
        "Scan to join queue"
      end
      token = walk_in_token(organization)
      PortalQrContext.new(url: helpers.portal_arrive_url(organization, token: token), label: label)
    elsif booking
      PortalQrContext.new(url: helpers.organization_public_portal_url(organization), label: "Scan to book your appointment")
    end
  end

  def portal_qr_svg(url)
    uri = URI.parse(url.to_s)
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      raise ArgumentError, "QR codes require an HTTP(S) URL"
    end

    qr = RQRCode::QRCode.new(uri.to_s, level: :m)
    qr.as_svg(
      offset: 0,
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 4,
      standalone: true,
      use_path: true,
      viewbox: true,
      svg_attributes: { width: "100%", height: "100%" }
    )
  end

  # Deterministic for a whole wall-clock hour: MessageVerifier#generate has no random IV, so an
  # identical payload + identical expires_at produces byte-identical output. No stored state, no
  # scheduled job - the token just changes the instant Time.current crosses into a new hour. The
  # +5 minute grace past the boundary keeps an already-scanned tab from getting bounced right at
  # the rotation edge; MessageVerifier#verify already raises InvalidSignature once a message is
  # past its expires_at, so Public::ArrivalsController needs no changes to honor this.
  def walk_in_token(organization)
    bucket_end = Time.current.beginning_of_hour + 1.hour
    Rails.application.message_verifier("walk-in").generate(
      { "org_id" => organization.id, "org_slug" => organization.slug },
      expires_at: bucket_end + 5.minutes
    )
  end
end
