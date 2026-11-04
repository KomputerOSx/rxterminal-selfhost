# frozen_string_literal: true

module ServiceImageHelper
  # True when the service has a stored image. A rejected upload is attached to the in-memory
  # record but not saved, so it must not be rendered (it has no signed id yet).
  def service_image?(service)
    service.image.attached? && service.image.blob.persisted?
  end

  # Renders a service's uploaded image cropped to width x height (CSS pixels; the variant is
  # generated at 2x for sharp displays). Returns nil when the service has no image.
  def service_image_tag(service, width:, height: width, **options)
    return unless service_image?(service)

    source = if service.image.variable? && ImageProcessingSupport.vips?
      service.image.variant(resize_to_fill: [ width * 2, height * 2 ])
    else
      service.image
    end
    image_tag source, { alt: service.display_name, width: width, height: height, loading: "lazy" }.merge(options)
  end
end
