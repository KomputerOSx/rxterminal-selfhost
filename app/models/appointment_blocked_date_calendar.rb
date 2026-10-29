# frozen_string_literal: true

class AppointmentBlockedDateCalendar < ApplicationRecord
  belongs_to :appointment_blocked_date
  belongs_to :calendar

  validates :calendar_id, uniqueness: { scope: :appointment_blocked_date_id }
end
