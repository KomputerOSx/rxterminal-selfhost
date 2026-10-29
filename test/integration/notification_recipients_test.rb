require "test_helper"

class NotificationRecipientsTest < ActionDispatch::IntegrationTest
  test "a user can only mark_read/destroy their own notification recipient rows" do
    notification = Notification.deliver!(title: "Hello", body: "World", to: users(:two))
    other_recipient = notification.notification_recipients.first

    post login_path, params: { email: users(:one).email, password: "password123" }
    assert_redirected_to dashboard_path

    patch mark_read_notification_recipient_path(other_recipient)
    assert_response :not_found
  end

  test "mark_all_read zeroes the current user's unread count without touching other users'" do
    Notification.deliver!(title: "Mine", body: "Body", to: users(:one))
    Notification.deliver!(title: "Theirs", body: "Body", to: users(:two))

    post login_path, params: { email: users(:one).email, password: "password123" }
    assert_redirected_to dashboard_path

    assert_equal 1, users(:one).unread_notification_count

    patch mark_all_read_notification_recipients_path

    assert_equal 0, users(:one).unread_notification_count
    assert_equal 1, users(:two).unread_notification_count
  end

  test "index paginates the inbox at 20 per page with daisyUI pagination controls" do
    25.times { |i| Notification.deliver!(title: "Notice #{i}", body: "Body", to: users(:one)) }

    post login_path, params: { email: users(:one).email, password: "password123" }
    assert_redirected_to dashboard_path

    get notification_recipients_path
    assert_select "ul.divide-y > li", 20
    assert_select "nav[aria-label=Pagination] .join a[href=?]", notification_recipients_path(page: 2)

    get notification_recipients_path, params: { page: 2 }
    assert_select "ul.divide-y > li", 5
  end

  test "destroying a notification on a paginated inbox re-renders valid pagination links" do
    25.times { |i| Notification.deliver!(title: "Notice #{i}", body: "Body", to: users(:one)) }
    recipient = users(:one).notification_recipients.first

    post login_path, params: { email: users(:one).email, password: "password123" }
    assert_redirected_to dashboard_path

    delete notification_recipient_path(recipient), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_select "nav[aria-label=Pagination] .join a[href=?]", notification_recipients_path(page: 2)
  end

  test "destroy dismisses the notification for the current user only" do
    notification = Notification.deliver!(title: "Hello", body: "World", to: [ users(:one), users(:two) ])
    recipient = users(:one).notification_recipients.find_by(notification: notification)

    post login_path, params: { email: users(:one).email, password: "password123" }
    assert_redirected_to dashboard_path

    delete notification_recipient_path(recipient)

    assert_not_includes users(:one).notification_recipients.inbox.map(&:notification), notification
    assert_includes users(:two).notification_recipients.inbox.map(&:notification), notification
  end
end
