# frozen_string_literal: true

module PlanLimitEnforcement
  extend ActiveSupport::Concern

  private

  def plan_limit_organization
    Current.organization || @organization
  end

  def block_if_at_service_limit!
    org = plan_limit_organization
    return false unless org&.at_service_limit?

    deny_plan_limit!(plan_limit_upgrade_message("service", organization: org))
    true
  end

  def block_if_at_upsell_rule_limit!
    org = plan_limit_organization
    return false unless org&.at_upsell_rule_limit?

    deny_plan_limit!(plan_limit_upgrade_message("upsell rule", organization: org))
    true
  end

  def block_if_at_monthly_request_limit!(public_facing: false)
    org = plan_limit_organization
    return false unless org&.at_monthly_request_limit?

    message = if public_facing
      "This service is temporarily unavailable. Please visit the pharmacy for assistance."
    else
      plan_limit_upgrade_message("monthly service request", organization: org)
    end

    deny_plan_limit!(message, public_facing: public_facing)
    true
  end

  def block_unless_appointments_enabled!(public_facing: false)
    org = plan_limit_organization
    return false if org&.appointments_enabled?

    message = if public_facing
      "Online appointment booking is temporarily unavailable. Please contact the pharmacy."
    else
      plan_feature_upgrade_message("appointment booking", organization: org)
    end

    deny_plan_limit!(message, public_facing: public_facing)
    true
  end

  def block_unless_calendars_enabled!(public_facing: false)
    org = plan_limit_organization
    return false if org&.calendars_enabled?

    message = if public_facing
      "This feature is temporarily unavailable. Please contact the pharmacy."
    else
      plan_feature_upgrade_message("calendars", organization: org)
    end

    deny_plan_limit!(message, public_facing: public_facing)
    true
  end

  def block_unless_kiosk_enabled!(public_facing: false)
    org = plan_limit_organization
    return false if org&.kiosk_enabled?

    message = if public_facing
      "This kiosk is temporarily unavailable. Please contact the pharmacy."
    else
      plan_feature_upgrade_message("kiosk devices", organization: org)
    end

    deny_plan_limit!(message, public_facing: public_facing)
    true
  end

  def deny_plan_limit!(message, fallback_path: nil, public_facing: false)
    respond_to do |format|
      format.html { redirect_to(fallback_path || plan_limit_redirect_path(public_facing:), alert: message) }
      format.turbo_stream do
        flash.now[:toast] = { message: message, type: "error" }
        render turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash"), status: :unprocessable_entity
      end
      format.json { render json: { error: message }, status: :unprocessable_entity }
    end
  end

  def plan_limit_redirect_path(public_facing: false)
    return root_path if public_facing || !current_user

    billing_path
  end

  def plan_limit_upgrade_message(limit_label, organization:)
    helpers.plan_limit_upgrade_message(limit_label, organization: organization)
  end

  def plan_feature_upgrade_message(feature_label, organization:)
    helpers.plan_feature_upgrade_message(feature_label, organization: organization)
  end
end
