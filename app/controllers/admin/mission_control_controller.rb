module Admin
  class MissionControlController < BaseController
    before_action { authorize :system, :manage_jobs?, policy_class: SystemPolicy }
  end
end
