require "test_helper"

class OrgQueueTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @service = @organization.services.create!(
      internal_name: "flu-jab",
      display_name: "Flu Jab",
      estimated_duration: 15
    )
    @waiting_request = create_service_request(@service, status: "waiting", queue_number: "1")
    @in_progress_request = create_service_request(@service, status: "in_progress", queue_number: "2", called_at: 5.minutes.ago)
  end

  test "an owner can view the queue dashboard" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_queue_path
    assert_response :success
    assert_match @waiting_request.queue_number, response.body
    assert_match @in_progress_request.queue_number, response.body
    assert_match "turbo-cable-stream-source", response.body
    assert_match "skeleton-in-progress-template", response.body
    assert_match "optimistic-update", response.body
    assert_match "keyboard-nav", response.body
    assert_match "sound-alert", response.body
    assert_match "voice-announcement-target=\"toggleIcon\"", response.body
  end

  test "a user role member can view and manage the queue" do
    user_role = Role.find_by!(scope: :app, name: Role::APP_USER)
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(user_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    get org_queue_path
    assert_response :success

    post org_call_next_queue_path
    assert_redirected_to org_queue_path
    assert_equal "in_progress", @waiting_request.reload.status
  end

  test "a member without app.queue.view is denied" do
    limited_role = Role.create!(scope: :app, name: "limited_#{SecureRandom.hex(4)}")
    member = @organization.memberships.create!(user: users(:two))
    member.grant_role!(limited_role)

    post login_path, params: { email: users(:two).email, password: "password123" }

    get org_queue_path
    assert_redirected_to root_path
  end

  test "completing a waiting entry via update_status" do
    post login_path, params: { email: @owner.email, password: "password123" }

    patch org_update_status_queue_path(@waiting_request), params: { status: "completed" }, as: :turbo_stream

    assert_response :success
    assert_equal "completed", @waiting_request.reload.status
    assert_not_nil @waiting_request.completed_at
  end

  test "revert_completed restores the previous status" do
    @in_progress_request.update!(status: "completed", completed_at: Time.current, previous_status: "in_progress", previous_called_at: 10.minutes.ago)

    post login_path, params: { email: @owner.email, password: "password123" }

    patch org_revert_completed_queue_path(@in_progress_request), as: :turbo_stream

    assert_response :success
    assert_equal "in_progress", @in_progress_request.reload.status
    assert_nil @in_progress_request.completed_at
  end

  test "poll returns turbo stream updates" do
    post login_path, params: { email: @owner.email, password: "password123" }

    get org_poll_queue_path, as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.body
    assert_match "waiting-cards", response.body
  end

  test "call next with an empty queue is silent for turbo stream requests" do
    @waiting_request.destroy!

    post login_path, params: { email: @owner.email, password: "password123" }

    post org_call_next_queue_path, as: :turbo_stream

    assert_response :success
    assert_empty response.body
  end

  test "queue manage actions create audit logs" do
    post login_path, params: { email: @owner.email, password: "password123" }

    assert_difference -> { AuditLog.where(event_type: :customer_called).count }, 1 do
      post org_call_next_queue_path
    end

    called_log = AuditLog.where(event_type: :customer_called).last
    assert_equal @owner.id, called_log.user_id
    assert_equal @waiting_request.id, called_log.resource_id
    assert_equal @organization.id, called_log.metadata["organization_id"]
    assert_equal "1", called_log.metadata["queue_number"]

    assert_difference -> { AuditLog.where(event_type: :customer_status_updated).count }, 1 do
      patch org_update_status_queue_path(@in_progress_request), params: { status: "completed" }, as: :turbo_stream
    end

    status_log = AuditLog.where(event_type: :customer_status_updated).last
    assert_equal "in_progress", status_log.metadata["previous_status"]
    assert_equal "completed", status_log.metadata["new_status"]

    @waiting_request.update!(status: "cancelled")

    assert_difference -> { AuditLog.where(event_type: :customer_reactivated).count }, 1 do
      patch org_undo_last_cancelled_queue_path, as: :turbo_stream
    end

    @in_progress_request.update!(status: "completed", completed_at: Time.current, previous_status: "in_progress")

    assert_difference -> { AuditLog.where(event_type: :customer_reverted).count }, 1 do
      patch org_revert_completed_queue_path(@in_progress_request), as: :turbo_stream
    end

    @organization.update_feature!(:waiting_time, enabled: true)

    assert_difference -> { AuditLog.where(event_type: :wait_timer_reset).count }, 1 do
      post org_reset_wait_timer_queue_path, as: :turbo_stream
    end

    timer_log = AuditLog.where(event_type: :wait_timer_reset).last
    assert_equal @organization.id, timer_log.resource_id
    assert_equal "Organization", timer_log.resource_type
  end

  private

  def create_service_request(service, attrs = {})
    defaults = {
      first_name: "JOHN",
      last_name: "SMITH",
      dob: Date.new(1990, 1, 15),
      postcode: "SW1A 1AA",
      request_type: "immediate",
      queue_date: Date.current
    }

    service.organization.service_requests.create!(defaults.merge(attrs).merge(service: service))
  end
end
