# frozen_string_literal: true

module Org
  class OrganizationsController < BaseController
    skip_before_action :require_current_organization!, only: %i[new create]

    def new
      @organization = Organization.new
      authorize @organization, :create?
    end

    def create
      authorize Organization.new, :create?

      organization = Organization.create_for!(
        current_user,
        name: organization_params[:name],
        slug: organization_params[:slug],
        address_line1: organization_params[:address_line1],
        address_line2: organization_params[:address_line2],
        address_city: organization_params[:address_city],
        address_state: organization_params[:address_state],
        address_postal_code: organization_params[:address_postal_code],
        address_country: organization_params[:address_country],
        contact_email: organization_params[:contact_email],
        contact_phone: organization_params[:contact_phone],
        validate_essential_details: true
      )
      session[:current_organization_id] = organization.id

      redirect_to billing_path,
        notice: "#{organization.name} created. Choose a plan to start using it."
    rescue ActiveRecord::RecordInvalid => e
      @organization = e.record
      @organization.assign_attributes(organization_params)
      render :new, status: :unprocessable_entity
    end

    def update
      permitted = organization_params
      if permitted.empty?
        skip_authorization
        head :forbidden and return
      end

      authorize Current.organization, :update? if permitted.key?(:name)
      if permitted.key?(:slug) || permitted.key?(:postcode_region) || permitted.key?(:service_currency) || permitted.key?(:kiosk_collect_postcode) ||
          permitted.key?(:kiosk_collect_dob) || permitted.key?(:kiosk_fallback_icon) ||
          permitted.key?(:contact_email) || permitted.key?(:contact_phone) ||
          permitted.key?(:time_zone) ||
          permitted.key?(:address_line1) || permitted.key?(:address_line2) ||
          permitted.key?(:address_city) || permitted.key?(:address_state) ||
          permitted.key?(:address_postal_code) || permitted.key?(:address_country)
        authorize Current.organization, :update?, policy_class: PortalConfigPolicy
      end

      organization = Current.organization

      # Warm the Pay::Customer association before a possible validation failure below - the
      # settings view checks plan/billing state (e.g. custom_domain_allowed?) on re-render, and
      # Pay's lazy payment_processor auto-vivification uses with_lock, which raises if called
      # on a record with unsaved changes (the invalid attributes we're about to assign).
      organization.payment_processor
      organization.enforce_slug_change_limit = true

      if organization.update(permitted)
        log_audit(:organization_updated, resource: organization, metadata: {
          changed_fields: organization.saved_changes.except("updated_at").keys
        })
        respond_to do |format|
          format.turbo_stream do
            flash.now[:toast] = { message: "Organization updated.", type: "success" }
            render turbo_stream: [
              turbo_stream.replace(dom_id(Current.organization, :name_display), partial: "org/settings/name_display"),
              turbo_stream.update(dom_id(Current.organization, :dialog), partial: "org/settings/name_dialog_content"),
              turbo_stream.replace(dom_id(Current.organization, :nav_label), partial: "shared/org_nav_label", locals: { organization: Current.organization }),
              turbo_stream.replace(dom_id(Current.organization, :nav_item_label), partial: "shared/org_nav_item_label", locals: { organization: Current.organization }),
              turbo_stream.replace(dom_id(Current.organization, :logo_gallery), partial: "org/settings/logo_gallery", locals: { organization: Current.organization }),
              turbo_stream.update("flash_messages", partial: "shared/flash")
            ]
          end
          format.html { redirect_to org_settings_path, notice: "Organization updated." }
        end
      else
        render_update_errors
      end
    end

    private

    def render_update_errors
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update(dom_id(Current.organization, :dialog), partial: "org/settings/name_dialog_content"),
            turbo_stream.replace(dom_id(Current.organization, :logo_gallery), partial: "org/settings/logo_gallery", locals: { organization: Current.organization })
          ], status: :unprocessable_entity
        end
        format.html do
          render "org/settings/index", status: :unprocessable_entity
        end
      end
    end

    def organization_params
      raw = params.require(:organization)
      permitted = []
      permitted << :name if raw.key?(:name) || action_name.in?(%w[new create])
      permitted << :slug if action_name.in?(%w[new create])
      permitted << :address_line1 if action_name.in?(%w[new create])
      permitted << :address_line2 if action_name.in?(%w[new create])
      permitted << :address_city if action_name.in?(%w[new create])
      permitted << :address_state if action_name.in?(%w[new create])
      permitted << :address_postal_code if action_name.in?(%w[new create])
      permitted << :address_country if action_name.in?(%w[new create])
      permitted << :contact_email if action_name.in?(%w[new create])
      permitted << :contact_phone if action_name.in?(%w[new create])
      if current_user.has_permission?("app.portal.configure", organization: Current.organization)
        permitted << :slug if raw.key?(:slug)
        permitted << :postcode_region if raw.key?(:postcode_region)
        permitted << :service_currency if raw.key?(:service_currency)
        permitted << :kiosk_collect_postcode if raw.key?(:kiosk_collect_postcode)
        permitted << :kiosk_collect_dob if raw.key?(:kiosk_collect_dob)
        permitted << :kiosk_fallback_icon if raw.key?(:kiosk_fallback_icon)
        permitted << :contact_email if raw.key?(:contact_email)
        permitted << :contact_phone if raw.key?(:contact_phone)
        permitted << :time_zone if raw.key?(:time_zone)
        permitted << :address_line1 if raw.key?(:address_line1)
        permitted << :address_line2 if raw.key?(:address_line2)
        permitted << :address_city if raw.key?(:address_city)
        permitted << :address_state if raw.key?(:address_state)
        permitted << :address_postal_code if raw.key?(:address_postal_code)
        permitted << :address_country if raw.key?(:address_country)
      end
      raw.permit(permitted)
    end
  end
end
