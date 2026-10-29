# frozen_string_literal: true

class ContactMailer < ApplicationMailer
  def enquiry(name:, email:, phone:, message:)
    @name = name
    @email = email
    @phone = phone
    @message = message

    safe_name = name.gsub(/[\r\n\t]/, " ").squeeze(" ").truncate(100)
    safe_email = email.gsub(/[\r\n\t<>]/, "").truncate(254)

    mail(
      to: "contact@strixon.co.uk",
      reply_to: "#{safe_name} <#{safe_email}>",
      subject: "RxTerminal enquiry from #{safe_name}"
    )
  end

  def confirmation(name:, email:, phone:, message:)
    @name = name
    @email = email
    @phone = phone
    @message = message

    safe_email = email.gsub(/[\r\n\t<>]/, "").truncate(254)

    mail(
      to: safe_email,
      reply_to: "contact@strixon.co.uk",
      subject: "We've received your message - RxTerminal"
    )
  end
end
