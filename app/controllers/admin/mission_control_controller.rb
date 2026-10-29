module Admin
  class MissionControlController < BaseController
    before_action { authorize :system, :manage_billing?, policy_class: SystemPolicy }
  end
end
