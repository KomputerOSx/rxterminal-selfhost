# frozen_string_literal: true

module OmniauthHelper
  def oauth_provider_enabled?(provider)
    case provider.to_sym
    when :google_oauth2 then ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
    when :github then ENV["GITHUB_CLIENT_ID"].present? && ENV["GITHUB_CLIENT_SECRET"].present?
    else false
    end
  end

  def any_oauth_provider_enabled?
    %i[google_oauth2 github].any? { |provider| oauth_provider_enabled?(provider) }
  end
end
