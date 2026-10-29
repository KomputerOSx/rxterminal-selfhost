# frozen_string_literal: true

module KioskAuthentication
  extend ActiveSupport::Concern
  include KioskPreviewMode
  include SubscriptionLockout
  include PlanLimitEnforcement

  KIOSK_AUTH_COOKIE = :kiosk_jwt_token

  included do
    before_action :authenticate_kiosk_device
    before_action :set_kiosk_organization
    before_action :enforce_kiosk_subscription_lockout!
    before_action :enforce_kiosk_plan_access!
  end

  private

  def authenticate_kiosk_device
    if session[:kiosk_preview_mode].present?
      if kiosk_preview_authorized?
        return
      end

      invalidate_kiosk_preview!
      redirect_to login_path, alert: "Please sign in to use kiosk preview."
      return
    end

    token = extract_kiosk_jwt_token

    unless token.present?
      respond_to_kiosk_auth_required
      return
    end

    begin
      payload = JwtService.decode(token)
      device_id = payload["device_id"]

      @device = Device.find_by(device_id: device_id)

      unless @device
        respond_to_kiosk_device_not_found
        return
      end

      unless @device.active?
        respond_to_kiosk_forbidden("Device is #{@device.status}")
        return
      end

      token_version = payload["token_version"]
      if token_version.nil? || token_version.to_i != @device.token_version
        clear_kiosk_jwt_token
        respond_to_kiosk_auth_required("Your session has been invalidated. Please re-authenticate.")
        return
      end

      if @device.registered_ip.present?
        unless request.remote_ip == @device.registered_ip
          Rails.logger.warn "IP mismatch for device #{@device.device_id}: expected #{@device.registered_ip}, got #{request.remote_ip}"
          respond_to_kiosk_forbidden("Device must authenticate from registered IP address")
          return
        end
      else
        @device.update(registered_ip: request.remote_ip)
      end

      @device.touch_last_seen

      write_kiosk_jwt_token(token) if cookies.encrypted[KIOSK_AUTH_COOKIE].blank?
    rescue JwtService::Error => e
      Rails.logger.error "JWT authentication failed: #{e.message}"
      clear_kiosk_jwt_token
      respond_to_kiosk_auth_required("Authentication expired. Please authenticate again.")
    end
  end

  def set_kiosk_organization
    if kiosk_preview_mode?
      @organization = Organization.find_by(id: session[:kiosk_preview_organization_id])
      unless @organization
        invalidate_kiosk_preview!
        redirect_to root_path, alert: "Preview session expired. Please try again."
      end
      return
    end

    @organization = @device&.organization

    unless @organization
      if request.format.json?
        render json: { error: "No organization configured for this device" }, status: :unprocessable_entity
      else
        redirect_to kiosk_setup_path, alert: "No organization configured for this device. Please contact your administrator."
      end
    end
  end

  def extract_kiosk_jwt_token
    auth_header = request.headers["Authorization"]
    return auth_header.match(/\ABearer (.+)\z/)&.[](1) if auth_header.present?

    cookies.encrypted[KIOSK_AUTH_COOKIE].presence
  end

  def write_kiosk_jwt_token(token)
    cookies.encrypted[KIOSK_AUTH_COOKIE] = {
      value: token,
      expires: JwtService::TOKEN_EXPIRATION.seconds.from_now,
      httponly: true,
      same_site: :strict,
      secure: Rails.env.production?
    }
  end

  def clear_kiosk_jwt_token
    cookies.delete(KIOSK_AUTH_COOKIE)
  end

  def respond_to_kiosk_auth_required(message = "Please authenticate to access the kiosk.")
    if request.format.json?
      render json: { error: "Authorization required" }, status: :unauthorized
    else
      redirect_to kiosk_setup_path, alert: message
    end
  end

  def respond_to_kiosk_device_not_found
    if request.format.json?
      render json: { error: "Device not found" }, status: :not_found
    else
      redirect_to kiosk_setup_path, alert: "Device not found. Please check your configuration."
    end
  end

  def respond_to_kiosk_forbidden(message)
    if request.format.json?
      render json: { error: message }, status: :forbidden
    else
      redirect_to kiosk_setup_path, alert: "#{message}. Please contact your administrator."
    end
  end

  def current_device
    @device
  end

  def subscription_lockout_organization
    @organization
  end

  def enforce_kiosk_subscription_lockout!
    enforce_subscription_lockout!
  end

  def enforce_kiosk_plan_access!
    return unless @organization
    return if @organization.kiosk_enabled?

    message = if kiosk_preview_mode?
      plan_feature_upgrade_message("kiosk devices", organization: @organization)
    else
      "This kiosk is temporarily unavailable. Please contact the pharmacy."
    end

    if kiosk_preview_mode?
      redirect_to org_kiosk_path, alert: message
    elsif request.format.json?
      render json: { error: message }, status: :forbidden
    else
      redirect_to kiosk_setup_path, alert: message
    end
  end

  def subscription_lockout_layout
    false
  end
end
