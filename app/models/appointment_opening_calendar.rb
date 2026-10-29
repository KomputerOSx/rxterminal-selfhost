# frozen_string_literal: true

class AppointmentOpeningCalendar < ApplicationRecord
  belongs_to :appointment_opening
  belongs_to :calendar

  validates :calendar_id, uniqueness: { scope: :appointment_opening_id }
end
