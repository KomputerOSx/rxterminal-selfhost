# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      session_id = cookies.signed[:session_id]
      return nil if session_id.blank?

      Session.active.find_by(id: session_id)&.user
    end
  end
end
