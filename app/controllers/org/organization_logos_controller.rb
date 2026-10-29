# frozen_string_literal: true

module Org
  class OrganizationLogosController < BaseController
    # See Org::OrganizationsController - same content-type/size guard, duplicated here rather
    # than shared, matching how Admin::EmailCampaignImagesController already duplicates it too.
    ALLOWED_CONTENT_TYPES = ActiveStorage.web_image_content_types
    MAX_FILE_SIZE = 5.megabytes
    MAX_FILES_PER_UPLOAD = OrganizationLogo::MAX_PER_ORGANIZATION

    before_action :authorize_manage

    def create
      organization = Current.organization
      files = Array(params.dig(:organization_logo, :images)).reject(&:blank?).first(MAX_FILES_PER_UPLOAD)

      if files.empty?
        return respond_with_message("Choose at least one logo to upload.", type: "error")
      end

      existing_count = organization.organization_logos.where(status: %w[pending approved]).count
      if existing_count + files.size > OrganizationLogo::MAX_PER_ORGANIZATION
        return respond_with_message(
          "You can have at most #{OrganizationLogo::MAX_PER_ORGANIZATION} logos pending or approved at a time.",
          type: "error"
        )
      end

      files.each do |file|
        if (reason = invalid_logo_reason(file))
          return respond_with_message("#{file.original_filename}: #{reason}", type: "error")
        end
      end

      created = files.map do |file|
        logo = organization.organization_logos.build(uploaded_by: current_user)
        logo.image.attach(file)
        logo.save!
        logo
      end

      created.each do |logo|
        log_audit(:organization_logo_submitted, resource: logo, organization: organization, metadata: { organization_logo_id: logo.id })
      end

      respond_with_message("#{created.size} logo#{"s" if created.size != 1} submitted for approval.", type: "success")
    end

    def activate
      organization = Current.organization
      logo = organization.organization_logos.approved.find(params[:id])

      organization.kiosk_logo.purge if organization.kiosk_logo.attached?
      organization.kiosk_logo.attach(logo.image.blob)

      log_audit(:organization_logo_activated, resource: logo, organization: organization, metadata: { organization_logo_id: logo.id })

      respond_with_message("Logo set as active.", type: "success")
    end

    def deactivate
      organization = Current.organization
      organization.kiosk_logo.purge if organization.kiosk_logo.attached?

      log_audit(:organization_logo_activated, organization: organization, metadata: { deactivated: true })

      respond_with_message("Active logo removed.", type: "success")
    end

    def destroy
      organization = Current.organization
      logo = organization.organization_logos.find(params[:id])
      logo.destroy!

      log_audit(:organization_logo_withdrawn, organization: organization, metadata: { organization_logo_id: logo.id, status: logo.status })

      respond_with_message("Logo submission removed.", type: "success")
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
