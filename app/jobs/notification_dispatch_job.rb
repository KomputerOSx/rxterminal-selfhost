class NotificationDispatchJob < ApplicationJob
  queue_as :default

  def perform(event_type:, actor_id:, resource_type:, resource_id:, organization_id:, metadata:)
    rule_class = Notifications::Registry.for(event_type)
    return unless rule_class

    rule = rule_class.new(
      actor: actor_id ? User.find_by(id: actor_id) : nil,
      resource: resolve(resource_type, resource_id),
      organization: organization_id ? Organization.find_by(id: organization_id) : nil,
      metadata: metadata.with_indifferent_access
    )

    recipients = Array(rule.recipients).uniq
    return if recipients.empty?

    category = rule_class.category

    if rule_class.channels.include?(:in_app)
      in_app_recipients = recipients.select { |user| user.notification_channel_enabled?(category, :in_app) }
      Notification.deliver!(title: rule.title, body: rule.body, url: rule.url, category: category.to_s,
        details: rule.details, to: in_app_recipients, created_by: rule.actor) if in_app_recipients.any?
    end

    if rule_class.channels.include?(:email)
      recipients.select { |user| user.notification_channel_enabled?(category, :email) }.each do |user|
        NotificationMailer.notify(user: user, title: rule.title, body: rule.body, details: rule.details).deliver_later
      end
    end
  rescue => e
    Rails.logger.error "[NotificationDispatchJob] #{e.class}: #{e.message} - event=#{event_type}"
  end

  private

  def resolve(type, id)
    return nil if type.blank? || id.blank?

    type.constantize.find_by(id: id)
  end
end
