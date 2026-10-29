# frozen_string_literal: true

namespace :credentials do
  desc "Print a credential value by dot-separated path (for Kamal .kamal/secrets)"
  task :fetch, [ :path ] => :environment do |_task, args|
    abort "Usage: bin/rails credentials:fetch app.host" if args[:path].blank?

    keys = args[:path].split(".")
    value = keys.reduce(Rails.application.credentials) { |node, key| node&.dig(key.to_sym) }

    abort "No credential at #{args[:path]}" if value.blank?

    print value
  end
end
