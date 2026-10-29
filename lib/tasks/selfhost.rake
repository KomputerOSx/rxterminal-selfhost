# frozen_string_literal: true

namespace :selfhost do
  desc "Print the generated secrets so they can be saved in a password manager"
  task :show_secrets do
    file = ENV.fetch("SECRETS_FILE", Rails.root.join("storage/secrets.env").to_s)
    abort "No secrets file at #{file}. Start the app once to generate it." unless File.exist?(file)

    puts "Keep these safe. Losing the ACTIVE_RECORD_ENCRYPTION_* keys makes patient data unreadable."
    puts
    puts File.read(file)
  end
end
