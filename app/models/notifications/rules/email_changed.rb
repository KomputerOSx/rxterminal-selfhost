module Notifications
  module Rules
    class EmailChanged < Notifications::Rule
      def self.event_type = :email_change_completed
      def self.category = :security
      def self.channels = [ :in_app ]

      def recipients = actor_only

      def title = "Your email address was changed"
      def body  = "Your account email address was changed to #{metadata["email"]}."
      def url   = profile_path
    end
  end
end
