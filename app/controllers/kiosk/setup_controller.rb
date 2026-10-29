# frozen_string_literal: true

module Kiosk
  class SetupController < BaseController
    KIOSK_AUTH_COOKIE = KioskAuthentication::KIOSK_AUTH_COOKIE

    def index
      @device_id = cookies.encrypted[:kiosk_device_id]
      @is_configured = @device_id.present? && cookies.encrypted[:kiosk_api_key].present?

      token = kiosk_jwt_token
      if token.present?
        begin
          payload = JwtService.decode(token)
          @authenticated_device_id = payload["device_id"]
          @is_authenticated = true
        rescue JwtService::Error
          @is_authenticated = false
          clear_kiosk_jwt_token
        end
      end
    end

    def configure
      device_id = params[:device_id].to_s.strip
      api_key = params[:api_key].to_s.strip

      if device_id.blank? || api_key.blank?
        redirect_to kiosk_setup_path, alert: "Device ID and API key are required."
        return
      end

      cookie_options = {
        expires: 1.year.from_now,
        httponly: true,
        same_site: :strict,
        secure: Rails.env.production?
      }

      cookies.encrypted[:kiosk_device_id] = { value: device_id, **cookie_options }
      cookies.encrypted[:kiosk_api_key] = { value: api_key, **cookie_options }

      redirect_to kiosk_setup_path, notice: "Device credentials saved."
    end

    def authenticate
      device_id = cookies.encrypted[:kiosk_device_id]
      api_key = cookies.encrypted[:kiosk_api_key]

      unless device_id.present? && api_key.present?
        redirect_to kiosk_setup_path, alert: "Kiosk not configured. Please enter device credentials."
        return
      end

      device = Device.find_by(device_id: device_id)
      unless device
        redirect_to kiosk_setup_path, alert: "Device not found. Please check your credentials."
        return
      end

      unless device.active?
        redirect_to kiosk_setup_path, alert: "Device is #{device.status}. Please contact your administrator."
        return
      end

      unless device.authenticate_api_key(api_key)
        log_device_audit(:device_auth_failure, device: device, metadata: {
          reason: "invalid_api_key",
          path: "kiosk/setup"
        })
        redirect_to kiosk_setup_path, alert: "Invalid API key. Please re-configure."
        return
      end

      if device.registered_ip.present?
        unless request.remote_ip == device.registered_ip
          Rails.logger.warn "IP mismatch for device #{device.device_id}: expected #{device.registered_ip}, got #{request.remote_ip}"
          redirect_to kiosk_setup_path, alert: "Device must authenticate from registered IP address. Please contact your administrator."
          return
        end
      else
        device.update(registered_ip: request.remote_ip)
      end

      token = JwtService.encode(device: device)
      write_kiosk_jwt_token(token)
      device.touch_last_seen

      log_device_audit(:device_auth_success, device: device, metadata: {
        device_id: device.device_id,
        organization_id: device.organization_id
      })

      redirect_to kiosk_root_path, notice: "Kiosk ready."
    end

    def clear
      cookies.delete(:kiosk_device_id)
      cookies.delete(:kiosk_api_key)
      cookies.delete(:kiosk_organization_slug)
      clear_kiosk_jwt_token

      redirect_to kiosk_setup_path, notice: "Configuration cleared."
    end

    def logout
      clear_kiosk_jwt_token
      redirect_to kiosk_setup_path, notice: "Logged out. Click Start kiosk to sign in again."
    end

    private

    def kiosk_jwt_token
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

    def log_device_audit(event_type, device:, metadata: {})
      log_audit(
        event_type,
        user: nil,
        resource: device,
        organization: device.organization,
        metadata: metadata
      )
    end
  end
end
