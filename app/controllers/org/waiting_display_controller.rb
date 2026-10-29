# frozen_string_literal: true

module Org
  class WaitingDisplayController < ApplicationController
    include SubscriptionLockout
    include PortalQrCode

    layout "waiting_display"

    DISPLAY_TOKEN_COOKIE = :waiting_display_token
    DISPLAY_TOKEN_DURATION = 30.days
    DISPLAY_TOKEN_PURPOSE = "waiting_display"

    allow_unauthenticated_access only: [ :index, :poll ]

    # Auth is skipped for these actions, so resume_session does not run via
    # require_authentication. Without this, set_current_organization sees no
    # current_user, Current.organization stays nil, and staff get bounced to
    # login (then dashboard) instead of the display page.
    prepend_before_action :resume_session_if_present

    before_action :authenticate_for_display
    before_action :load_display_organization
    before_action :enforce_waiting_display_subscription_lockout!
    before_action :authorize_staff_display_setup, only: [ :index ]
    before_action :stamp_display_token, only: [ :index ]
    # On both index and poll - the QR rotates hourly now, and a display can sit open for a
    # full shift with no page reload, so it needs to be re-evaluated on every poll to pick up
    # the rotation. Cheap: an in-memory HMAC sign + SVG string build, no I/O.
    before_action :load_portal_qr_code, only: [ :index, :poll ]

    def index
      load_waiting_view_data
    end

    def poll
      load_waiting_view_data
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to org_waiting_display_path }
      end
    end

    private

    def resume_session_if_present
      resume_session if cookies.signed[:session_id].present?
    end

    def authenticate_for_display
      return if resume_session

      @display_org_id = display_org_id_from_cookie
      return if @display_org_id.present?

      redirect_to login_path, alert: "Please sign in to set up this display."
    end

    def authorize_staff_display_setup
      return unless current_user

      authorize Current.organization, :index?, policy_class: QueuePolicy
    end

    def load_display_organization
      organization = if current_user
        Current.organization || resolve_organization_for_user(current_user)
      else
        Organization.find_by(id: @display_org_id)
      end

      unless organization
        cookies.delete(DISPLAY_TOKEN_COOKIE)
        redirect_to login_path, alert: "Display session expired. Please sign in again." and return
      end

      @organization = organization
      Current.organization = organization
    end

    def resolve_organization_for_user(user)
      orgs = user.organizations
      orgs.find_by(id: session[:current_organization_id]) || orgs.first
    end

    def stamp_display_token
      return unless current_user
      return if cookies.encrypted[DISPLAY_TOKEN_COOKIE].present?

      token = Rails.application.message_verifier(DISPLAY_TOKEN_PURPOSE)
        .generate({ org_id: @organization.id }, expires_in: DISPLAY_TOKEN_DURATION)

      cookies.encrypted[DISPLAY_TOKEN_COOKIE] = {
        value: token,
        expires: DISPLAY_TOKEN_DURATION.from_now,
        httponly: true,
        same_site: :strict,
        secure: Rails.env.production?
      }
    end

    def display_org_id_from_cookie
      raw = cookies.encrypted[DISPLAY_TOKEN_COOKIE]
      return nil if raw.blank?

      payload = Rails.application.message_verifier(DISPLAY_TOKEN_PURPOSE).verify(raw)
      payload[:org_id]
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      cookies.delete(DISPLAY_TOKEN_COOKIE)
      nil
    end

    # See PortalQrCode - nil context means no sub-feature is enabled, nothing to show.
    def load_portal_qr_code
      @portal_qr_context = portal_qr_context(@organization)
      @portal_qr_svg = portal_qr_svg(@portal_qr_context.url) if @portal_qr_context
    end

    def load_waiting_view_data
      @service_ids = filter_service_ids
      @services = @organization.services.visible.active.by_display_order
      requests = @organization.service_requests.for_services(@service_ids)

      @waiting = requests.where(status: "waiting").includes(:service).order(:created_at)
      @in_progress = requests.where(status: "in_progress").includes(:service).order(:called_at)

      if @organization.waiting_time_enabled?
        avg = ServiceRequest.average_wait_minutes(@organization.id, since: @organization.waiting_time_reset_at)
        @avg_wait_display = avg ? "#{avg} min" : "N/A"
      end
    end

    def filter_service_ids
      ids = params[:service_ids]
      return nil if ids.blank?

      Array(ids).map(&:to_i).select(&:positive?)
    end

    def subscription_lockout_organization
      @organization
    end

    def enforce_waiting_display_subscription_lockout!
      enforce_subscription_lockout!
    end

    def subscription_lockout_public_message
      "This waiting display is temporarily unavailable."
    end
  end
end
