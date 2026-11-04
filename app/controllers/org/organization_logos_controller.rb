# frozen_string_literal: true

module Org
  class OrganizationLogosController < BaseController
    # See Org::OrganizationsController - same content-type/size guard, duplicated here rather
    # than shared.
    ALLOWED_CONTENT_TYPES = ActiveStorage.web_image_content_types
    MAX_FILE_SIZE = 5.megabytes

    before_action :authorize_manage

    def create
      organization = Current.organization
      file = params.dig(:organization_logo, :image)

      return respond_with_message("Choose a logo to upload.", type: "error") if file.blank?

      if (reason = invalid_logo_reason(file))
        return respond_with_message("#{file.original_filename}: #{reason}", type: "error")
      end

      organization.kiosk_logo.attach(file)
      log_audit(:organization_logo_uploaded, resource: organization, organization: organization)

      respond_with_message("Logo updated.", type: "success")
    end

    def destroy
      organization = Current.organization
      organization.kiosk_logo.purge if organization.kiosk_logo.attached?

      log_audit(:organization_logo_removed, resource: organization, organization: organization)

      respond_with_message("Logo removed.", type: "success")
    end

    private

    def authorize_manage
      authorize Current.organization, :update?, policy_class: PortalConfigPolicy
    end

    def invalid_logo_reason(file)
      return "must be a PNG, JPEG, GIF, or WebP image" unless ALLOWED_CONTENT_TYPES.include?(file.content_type.to_s)
      return "must be smaller than #{MAX_FILE_SIZE / 1.megabyte} MB" if file.size > MAX_FILE_SIZE

      nil
    end

    def respond_with_message(message, type:)
      respond_to do |format|
        format.turbo_stream do
          flash.now[:toast] = { message: message, type: type }
          render turbo_stream: [
            turbo_stream.replace(dom_id(Current.organization, :logo_gallery), partial: "org/settings/logo_gallery", locals: { organization: Current.organization }),
            turbo_stream.update("flash_messages", partial: "shared/flash")
          ]
        end
        format.html do
          if type == "error"
            redirect_to org_settings_path, alert: message
          else
            redirect_to org_settings_path, notice: message
          end
        end
      end
    end
  end
end
