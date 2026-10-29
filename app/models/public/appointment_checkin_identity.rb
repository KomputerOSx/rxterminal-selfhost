# frozen_string_literal: true

module Public
  class AppointmentCheckinIdentity
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :last_name, :string
    attribute :dob, :string
  end
end
