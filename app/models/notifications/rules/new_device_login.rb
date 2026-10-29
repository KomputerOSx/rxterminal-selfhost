module Notifications
  module Rules
    class NewDeviceLogin < Notifications::Rule
      def self.event_type = :new_device_login
      def self.category = :security

      def recipients = actor_only

      def title = "New sign-in to your account"

      def body = "Your account was just signed into from a device we haven't seen before. If this wasn't you, change your password immediately."

      def details
        [
          [ "IP address", ip_address ],
          [ "Browser", device_info.browser ],
          [ "Operating system", device_info.os ],
          [ "Device type", device_info.device_type ],
          [ "User agent", raw_user_agent ]
        ]
      end

      def url = profile_path

      private

      def device_info
        @device_info ||= DeviceInfo.parse(metadata["user_agent"])
      end

      def ip_address
        metadata["ip_address"].presence || "Unknown"
      end

      def raw_user_agent
        metadata["user_agent"].presence || "Unknown"
      end
    end
  end
end
