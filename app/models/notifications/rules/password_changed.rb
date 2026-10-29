module Notifications
  module Rules
    class PasswordChanged < Notifications::Rule
      def self.event_type = :password_change
      def self.category = :security

      def recipients
        return User.none unless successful_password_change?

        actor_only
      end

      def title = "Your password was changed"
      def body  = "Your account password was just changed. If this wasn't you, reset your password immediately."
      def url   = profile_path

      private

      def successful_password_change?
        metadata["success"] == true && actor.present?
      end
    end
  end
end
