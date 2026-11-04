class ConfirmationsController < ApplicationController
  include InvitationResumption

  layout "auth"

  allow_unauthenticated_access

  def new
    @email = session[:pending_confirmation_email]

    unless @email.present? && PendingRegistration.find(@email)
      flash[:toast] = { message: "Please sign up to get a confirmation code.", type: "error" }
      redirect_to login_path
    end
  end

  def create
    email = session[:pending_confirmation_email]
    pending = email.present? ? PendingRegistration.find(email) : nil

    if pending.nil?
      flash[:toast] = { message: "Your signup session has expired. Please open your invitation link again.", type: "error" }
      redirect_to login_path
      return
    end

    unless pending.verify_code(otp_code_param)
      @email = email
      @code_error = "Incorrect code. Please try again."
      render :new, status: :unprocessable_entity
      return
    end

    invitation = OrganizationInvitation.find_usable(session[:pending_invitation_token])
    unless invitation && invitation.email.casecmp?(pending.email)
      PendingRegistration.destroy(email)
      session.delete(:pending_confirmation_email)
      flash[:toast] = { message: "Sign-up is by invitation only. Ask an administrator to invite you.", type: "error" }
      redirect_to login_path
      return
    end

    # Invited staff join the organization that invited them; the owner already did onboarding.
    user = User.new(email: pending.email, confirmed_at: Time.current, onboarding_completed_at: Time.current)
    user.password_digest = pending.password_digest

    begin
      user.save!(validate: false)
    rescue ActiveRecord::RecordNotUnique
      # Someone else claimed this email while this signup was pending confirmation.
      PendingRegistration.destroy(email)
      session.delete(:pending_confirmation_email)
      flash[:toast] = { message: "That email is already registered. Please log in instead.", type: "error" }
      redirect_to login_path
      return
    end

    pending_invitation_token = session[:pending_invitation_token]

    PendingRegistration.destroy(email)
    reset_session # regenerate session id - defends against session fixation

    log_audit(:user_registered, user: user, metadata: { email: user.email })
    log_audit(:account_confirmed, user: user, metadata: { email: user.email })

    start_new_session_for(user)
    log_audit(:login_success, user: user, metadata: { auto_login_after_confirmation: true })

    resume_pending_invitation_for(user, token: pending_invitation_token)
    flash[:toast] ||= { message: "Email confirmed! You've joined #{invitation.organization.name}.", type: "success" }
    redirect_to dashboard_path
  end
end
