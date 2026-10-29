# frozen_string_literal: true

module KioskPreviewMode
  extend ActiveSupport::Concern

  PREVIEW_WALK_IN_ID = "preview"
  PREVIEW_APPOINTMENT_ID = "preview"

  included do
    helper_method :kiosk_preview_mode?
  end

  def kiosk_preview_mode?
    session[:kiosk_preview_mode].present? && kiosk_preview_authorized?
  end

  def enter_kiosk_preview!(organization:, user:)
    session[:kiosk_preview_mode] = true
    session[:kiosk_preview_organization_id] = organization.id
    session[:kiosk_preview_user_id] = user.id
  end

  def exit_kiosk_preview!
    clear_kiosk_preview_data!
  end

  def clear_kiosk_preview_data!
    session.delete(:kiosk_preview_mode)
    session.delete(:kiosk_preview_organization_id)
    session.delete(:kiosk_preview_user_id)
    session.delete(:kiosk_preview_walk_in)
    session.delete(:kiosk_preview_appointment)
  end

  def preview_queue_number
    rand(1..99).to_s
  end

  def preview_booking_reference
    "PREVIEW#{SecureRandom.hex(2).upcase}"
  end

  def store_preview_walk_in!(data)
    session[:kiosk_preview_walk_in] = data
  end

  def preview_walk_in
    data = session[:kiosk_preview_walk_in]
    return unless data

    Kiosk::PreviewWalkIn.new(data, organization: @organization)
  end

  def store_preview_upsell_session!(upsell, walk_in_data)
    session[:upsell_rule_id] = upsell[:rule].id
    session[:upsell_template_id] = upsell[:template].id
    session[:upsell_service_request_id] = PREVIEW_WALK_IN_ID
    session[:upsell_customer_hash] = upsell[:customer_hash]
    session[:upsell_queue_number] = walk_in_data[:queue_number] || walk_in_data["queue_number"]
    store_preview_walk_in!(walk_in_data)
  end

  private

  def kiosk_preview_authorized?
    preview_user_id = session[:kiosk_preview_user_id]
    return false unless preview_user_id

    Session.active.find_by(id: cookies.signed[:session_id])&.user_id == preview_user_id
  end

  def invalidate_kiosk_preview!
    clear_kiosk_preview_data!
  end
end
