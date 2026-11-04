# frozen_string_literal: true

# First-run wizard: creates the owner account, the organization and the system admin role in one
# transaction. Only reachable while the install has no users.
class SetupController < ApplicationController
  layout "auth"

  allow_unauthenticated_access
  skip_before_action :enforce_setup!
  skip_before_action :enforce_onboarding_gate!
  skip_before_action :enforce_maintenance_mode!

  class AlreadySetUp < StandardError; end

  before_action :redirect_if_set_up

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params.merge(confirmed_at: Time.current))
    @organization_name = params[:organization_name].to_s.strip

    if @organization_name.blank?
      @user.valid?
      @user.errors.add(:base, "Organization name can't be blank")
      return render_form
    end

    organization = nil
    begin
      ActiveRecord::Base.transaction do
        lock_for_setup!
        raise AlreadySetUp unless Setup.required?

        @user.save!
        organization = Organization.create_for!(@user, name: @organization_name)
        @user.grant_role!(Role.find_by!(scope: :system, name: Role::SYSTEM_ADMIN))
      end
    rescue AlreadySetUp
      return redirect_to login_path, alert: "This server has already been set up."
    rescue ActiveRecord::RecordInvalid
      return render_form
    end

    reset_session
    log_audit(:user_registered, user: @user, metadata: { email: @user.email, setup: true })
    log_audit(:organization_created, user: @user, resource: organization, metadata: { name: organization.name, slug: organization.slug })
    start_new_session_for(@user)
    log_audit(:login_success, user: @user, metadata: { setup: true })

    redirect_to dashboard_path, notice: "Welcome! Your server is set up."
  end

  private

  def redirect_if_set_up
    redirect_to login_path unless Setup.required?
  end

  # SQLite serialises write transactions, so re-checking Setup.required? inside the transaction
  # is enough there. On Postgres take an advisory lock so two simultaneous setups cannot both pass.
  def lock_for_setup!
    return unless ActiveRecord::Base.connection.adapter_name.match?(/postg/i)

    ActiveRecord::Base.connection.execute("SELECT pg_advisory_xact_lock(7461001)")
  end

  def render_form
    render :new, status: :unprocessable_entity
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
