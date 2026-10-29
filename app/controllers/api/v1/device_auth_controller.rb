# frozen_string_literal: true

module Api
  module V1
    class DeviceAuthController < BaseController
      def create
        device_id = params[:device_id].to_s.strip
        api_key = params[:api_key].to_s

        device = Device.find_by(device_id: device_id)

        unless device
          write_device_audit_log(nil, :device_auth_failure, {
            reason: "device_not_found",
            device_id_attempted: device_id
          })
          render json: { error: "Device not found" }, status: :not_found
          return
        end

        unless device.active?
          write_device_audit_log(device, :device_auth_failure, { reason: "device_#{device.status}" })
          render json: { error: "Device is #{device.status}" }, status: :forbidden
          return
        end

        unless device.authenticate_api_key(api_key)
          write_device_audit_log(device, :device_auth_failure, { reason: "invalid_api_key" })
          render json: { error: "Invalid API key" }, status: :unauthorized
          return
        end

        if device.registered_ip.present?
          unless request.remote_ip == device.registered_ip
            write_device_audit_log(device, :device_auth_failure, {
              reason: "ip_mismatch",
              registered_ip: device.registered_ip
            })
            Rails.logger.warn "IP mismatch for device #{device.device_id}: expected #{device.registered_ip}, got #{request.remote_ip}"
            render json: { error: "Device must authenticate from registered IP address" }, status: :forbidden
            return
          end
        else
          device.update(registered_ip: request.remote_ip)
        end

        device.touch_last_seen

        token = JwtService.encode(device: device)

        write_device_audit_log(device, :device_auth_success, {
          device_id: device.device_id,
          organization_id: device.organization_id
        })

        render json: {
          token: token,
          device_id: device.device_id,
          organization_slug: device.organization.slug,
          expires_at: JwtService::TOKEN_EXPIRATION.seconds.from_now.iso8601
        }, status: :ok
      end

      private

      def write_device_audit_log(device, event_type, metadata)
        log_audit(
          event_type,
          user: nil,
          resource: device,
          organization: device&.organization,
          metadata: metadata
        )
      end
    end
  end
end
