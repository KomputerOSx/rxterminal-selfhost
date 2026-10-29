module Notifications
  module Rules
    class AppointmentBookedOnline < Notifications::Rule
      def self.event_type = :appointment_booked_online
      def self.category = :appointments
      def self.channels = [ :in_app ]

      def recipients = organization_owners

      def title = "New appointment booked online"
      def body  = "#{metadata["service"]} booked for #{metadata["date"]} (ref #{metadata["booking_reference"]})."
      def url   = resource ? org_appointment_path(resource) : org_appointments_path
    end
  end
end
