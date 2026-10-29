class NotificationMailer < ApplicationMailer
  def notify(user:, title:, body:, details: [])
    @user = user
    @title = title
    @body = body
    @details = details

    mail(to: user.email, subject: title)
  end
end
