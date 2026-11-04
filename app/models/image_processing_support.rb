# frozen_string_literal: true

# Resizing uploaded images needs the libvips system library. The Docker image and CI have it; a
# bare development machine might not. When it is missing we serve the original upload (sized by
# CSS) instead of a resized variant, because asking for a variant would return a 500 error.
module ImageProcessingSupport
  module_function

  def vips?
    return @vips if defined?(@vips)

    @vips = begin
      require "vips"
      true
    rescue LoadError
      Rails.logger.warn "[images] libvips is not installed: serving original images without resizing. " \
                        "Install it (for example `sudo apt install libvips42`) for faster pages."
      false
    end
  end

  def reset!
    remove_instance_variable(:@vips) if defined?(@vips)
  end
end
