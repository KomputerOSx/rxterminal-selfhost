# frozen_string_literal: true

require "test_helper"

class AdminMissionControlTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @organization = Organization.create_personal_for!(@admin)
    @previous_queue_adapter = ActiveJob::Base.queue_adapter
    @previous_solid_queue_connects_to = Rails.application.config.solid_queue.connects_to
    Rails.application.config.solid_queue.connects_to = { database: { writing: :queue } }
    SolidQueue::Record.establish_connection(:queue)
    ActiveJob::Base.queue_adapter = :solid_queue
    sign_in_as_billing_admin(@admin)
  end

  teardown do
    ActiveJob::Base.queue_adapter = @previous_queue_adapter
    Rails.application.config.solid_queue.connects_to = @previous_solid_queue_connects_to
    SolidQueue::Record.establish_connection(:primary)
  end

  test "billing admin can access job inspector" do
    get "/admin/jobs"

    assert_response :success
  end

  test "user without system.billing.manage cannot access job inspector" do
    sign_out
    user = users(:two)
    role = Role.find_or_create_by!(scope: :system, name: Role::SYSTEM_USER) { |r| r.permanent = true }
    user.grant_role!(role)
    post login_path, params: { email: user.email, password: "password123" }

    get "/admin/jobs"

    assert_redirected_to root_path
  end

  test "failed jobs page is reachable for billing admins" do
    get "/admin/jobs/failed/jobs"

    assert_response :success
  end

  test "enqueued reconcile job is recorded in solid queue" do
    SolidQueue::FailedExecution.delete_all
    SolidQueue::Job.delete_all

    Billing::ReconcileOrganizationJob.perform_later(@organization.id)

    job = SolidQueue::Job.find_by!(class_name: "Billing::ReconcileOrganizationJob")
    assert_equal "default", job.queue_name
  end

  private

  def sign_in_as_billing_admin(user)
    role = Role.find_or_create_by!(scope: :system, name: Role::SYSTEM_ADMIN) { |r| r.permanent = true }
    user.grant_role!(role)
    post login_path, params: { email: user.email, password: "password123" }
  end

  def sign_out
    delete logout_path
  end
end
