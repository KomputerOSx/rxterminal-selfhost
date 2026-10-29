# frozen_string_literal: true

class JwtService
  TOKEN_EXPIRATION = 24.hours.to_i

  class << self
    def secret_key
      key = Rails.application.credentials.jwt_secret_key
      raise "jwt_secret_key is not configured in Rails credentials" if key.blank?

      key
    end

    def encode(device:, additional_claims: {})
      payload = {
        device_id: device.device_id,
        organization_id: device.organization_id,
        organization_slug: device.organization.slug,
        token_version: device.token_version,
        type: "device",
        exp: Time.now.to_i + TOKEN_EXPIRATION,
        iat: Time.now.to_i
      }.merge(additional_claims)

      JWT.encode(payload, secret_key, "HS256")
    end

    def decode(token)
      decoded = JWT.decode(token, secret_key, true, { algorithm: "HS256" })
      decoded.first
    rescue JWT::ExpiredSignature
      raise JwtService::Error, "Token has expired"
    rescue JWT::DecodeError => e
      raise JwtService::Error, "Invalid token: #{e.message}"
    end
  end

  class Error < StandardError; end
end
