# frozen_string_literal: true

class ContactController < ApplicationController
  layout "landing"

  allow_unauthenticated_access only: [ :new, :create, :sent ]
  skip_before_action :enforce_onboarding_gate!

  def new
    ContactSpamGuard.prepare_session!(session: session)
  end

  def create
    if ContactSpamGuard.bot_submission?(params: params, session: session)
      redirect_to contact_sent_path and return
    end

    name    = sanitise_header(params[:name])
    email   = sanitise_header(params[:email])
    phone   = sanitise_header(params[:phone])
    message = params[:message].to_s.strip.gsub(/[\r\n]{3,}/, "\n\n")

    if name.blank? || email.blank? || message.blank?
      flash.now[:alert] = "Please fill in your name, email, and message."
      render :new, status: :unprocessable_entity and return
    end

    if name.length > 100 || email.length > 254 || phone.length > 20 || message.length > 5000
      flash.now[:alert] = "One or more fields exceeds the maximum allowed length."
      render :new, status: :unprocessable_entity and return
    end

    unless email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
      flash.now[:alert] = "Please enter a valid email address."
      render :new, status: :unprocessable_entity and return
    end

    ContactMailer.enquiry(name: name, email: email, phone: phone, message: message).deliver_later
    ContactMailer.confirmation(name: name, email: email, phone: phone, message: message).deliver_later

    flash[:contact_name] = name
    redirect_to contact_sent_path
  end

  def sent
    @name = flash[:contact_name].to_s.strip.presence || "there"
  end

  private

  def sanitise_header(value)
    value.to_s.strip.gsub(/[\r\n\t]/, " ").squeeze(" ")
  end
end
