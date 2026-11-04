module SetupGate
  extend ActiveSupport::Concern

  included do
    before_action :enforce_setup!
  end

  private

  def enforce_setup!
    redirect_to instance_setup_path if Setup.required?
  end
end
