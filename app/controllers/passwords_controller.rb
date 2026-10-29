class PasswordsController < ApplicationController
  layout "auth"

  def edit
  end

  def update
    if current_user.has_password? && !current_user.authenticate(params[:current_password])
      log_audit(:password_change, metadata: { success: false, reason: "incorrect_current_password" })
      flash.now[:alert] = "Current password is incorrect."
      render :edit, status: :unprocessable_entity
      return
    end

    persisted_digest = current_user.password_digest

    if current_user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      # Invalidate all other sessions - keep only the current one
      current_user.sessions.where.not(id: Current.session.id).destroy_all

      log_audit(:password_change, metadata: { success: true })

      redirect_to dashboard_path, notice: "Password updated successfully!"
    else
      # has_secure_password sets password_digest in memory as soon as `password:` is
      # assigned, even when validation then fails. Restore it so current_user.has_password?
      # still reflects the persisted state when we re-render the form.
      current_user.password_digest = persisted_digest

      log_audit(:password_change, metadata: { success: false, reason: "validation_failed", errors: current_user.errors.full_messages })

      flash.now[:alert] = current_user.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end
end
