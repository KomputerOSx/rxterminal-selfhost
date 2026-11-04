# frozen_string_literal: true

namespace :selfhost do
  namespace :legal do
    desc "Copy the default legal templates into the override directory (storage/legal) so you can edit them. FORCE=1 overwrites."
    task export: :environment do
      dir = LegalDocument.override_dir
      FileUtils.mkdir_p(dir)

      LegalDocument.names.each do |name|
        target = dir.join("#{name}.html")
        if target.exist? && ENV["FORCE"].blank?
          puts "skip   #{target} (exists; FORCE=1 to overwrite)"
        else
          FileUtils.cp(LegalDocument.default_dir.join("#{name}.html"), target)
          puts "wrote  #{target}"
        end
      end

      puts "\nEdit these files; changes apply immediately. Placeholders: #{LegalDocument.placeholders.keys.map { |k| "{{#{k}}}" }.join(' ')}"
    end

    desc "Show which legal documents are customised"
    task status: :environment do
      LegalDocument.names.each do |name|
        puts "#{name.ljust(16)} #{LegalDocument.customised?(name) ? 'customised' : 'default'}"
      end
    end
  end
end
