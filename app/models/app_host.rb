# frozen_string_literal: true

# The application hostname this install answers to (APP_HOST).
module AppHost
  module_function

  # Host Authorization may pass "pharmacy.example.com:3000"; strip port + www.
  def normalize(host)
    host.to_s.downcase.split(":", 2).first.to_s.sub(/\Awww\./, "")
  end

  def primary_hosts
    hosts = [ primary_host, "localhost", "127.0.0.1" ].compact
    # Rails integration tests default to www.example.com / example.com.
    hosts.concat(%w[example.com www.example.com]) if defined?(Rails) && (Rails.env.test? || Rails.env.development?)
    hosts.map { |host| normalize(host) }.uniq
  end

  def primary?(host)
    normalized = normalize(host)
    primary_hosts.any? { |primary| normalized == primary || normalized.end_with?(".#{primary}") }
  end

  # Used by config.hosts in development/production.
  def allowed_request_host?(host)
    primary?(host)
  end

  def primary_host
    ENV["APP_HOST"].presence || "localhost"
  end
end
