# frozen_string_literal: true

namespace :encryption do
  desc "Encrypt existing User PII columns (run once after enabling encryption on a plaintext database)"
  task encrypt_users: :environment do
    count = 0
    User.find_each do |user|
      user.encrypt
      count += 1
    end
    puts "Encrypted PII for #{count} users."
  end
end
