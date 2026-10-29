# frozen_string_literal: true

module Public
  class AppointmentCheckinReference
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :booking_reference, :string
  end
end
