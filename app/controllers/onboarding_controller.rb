class OnboardingController < ApplicationController
  layout "onboarding"

  skip_before_action :enforce_onboarding_gate!

  before_action :load_step_context, only: %i[show update]

  def show
    return redirect_to dashboard_path if current_user.onboarding_completed?

    pointer = current_user.onboarding_current_step
    requested_key = params[:step].presence
    target = requested_key ? Onboarding.find(requested_key) : pointer

    # Can't jump ahead of the furthest step reached; revisiting an earlier step is fine.
    if target.nil? || Onboarding.index_of(target.key) > Onboarding.index_of(pointer.key)
      return redirect_to onboarding_step_path(pointer.key)
    end

    @step = target
  end

  def update
    return redirect_to dashboard_path if current_user.onboarding_completed?

    @step = Onboarding.find(params[:step])
    return redirect_to onboarding_path if @step.nil?

    unless save_step(@step)
      return render :show, status: :unprocessable_entity
    end

    if Onboarding.last_step?(@step.key)
      # update_columns (not update!) - avoids re-running full User validations, which would
      # fail for OAuth-created users whose password_digest is blank.
      current_user.update_columns(onboarding_completed_at: Time.current, onboarding_step: @step.key)
      redirect_to dashboard_path, notice: "Welcome aboard!"
    else
      next_step = Onboarding.step_after(@step.key)
      pointer = current_user.onboarding_current_step
      # Only move the pointer forward - re-submitting an earlier step via Back
      # shouldn't erase progress already made further ahead.
      current_user.update_columns(onboarding_step: next_step.key) if Onboarding.index_of(next_step.key) > Onboarding.index_of(pointer.key)
      redirect_to onboarding_step_path(next_step.key)
    end
  end

  def skip
    current_user.update_columns(onboarding_completed_at: Time.current) unless current_user.onboarding_completed?
    redirect_to dashboard_path, notice: "Onboarding skipped - you can pick it up later from your account if needed."
  end

  private

  def load_step_context
    @user = current_user
    @organization = current_user.signup_organization
  end

  def save_step(step)
    case step.key
    when "welcome", "finish"
      true
    when "profile"
      @user.assign_attributes(profile_params)
      @user.save(context: :onboarding)
    when "organization"
      return false unless @organization

      @organization.assign_attributes(organization_params)
      @organization.save(context: :essential_details)
    when "business_type"
      return false unless @organization

      save_business_type_step
    when "data_collection"
      return false unless @organization

      @organization.assign_attributes(data_collection_params)
      @organization.save
    when "time_zone"
      return false unless @organization

      @organization.assign_attributes(time_zone_params)
      @organization.save
    when "currency"
      return false unless @organization

      @organization.assign_attributes(currency_params)
      @organization.save
    else
      true
    end
  end

  def profile_params
    params.fetch(:user, {}).permit(:first_name, :last_name)
  end

  def organization_params
    params.fetch(:organization, {}).permit(
      :name, :slug, :contact_email, :contact_phone,
      :address_line1, :address_line2, :address_city,
      :address_state, :address_postal_code, :address_country
    )
  end

  def time_zone_params
    params.fetch(:organization, {}).permit(:time_zone)
  end

  def currency_params
    params.fetch(:organization, {}).permit(:service_currency)
  end

  def business_type_params
    params.fetch(:organization, {}).permit(:business_type)
  end

  def data_collection_params
    params.fetch(:organization, {}).permit(:kiosk_collect_dob, :kiosk_collect_postcode)
  end

  # Applies the chosen preset's starter services/upsell rule only the first time this step is
  # completed for this org - revisiting via Back and switching presets updates business_type but
  # does not re-seed, so switching presets never creates a second, duplicate batch of services.
  def save_business_type_step
    already_applied = @organization.business_type.present?
    @organization.assign_attributes(business_type_params)
    return false unless @organization.save

    if !already_applied && @organization.business_type.present?
      Onboarding::PresetApplier.new(@organization).apply!(@organization.business_type)
    end

    true
  end
end
