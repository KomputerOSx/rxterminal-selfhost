require "test_helper"

class NotificationMailerTest < ActionMailer::TestCase
  test "notify renders title and body with no click-through link to app content" do
    mail = NotificationMailer.notify(user: users(:one), title: "You've been invited", body: "Join Acme.")

    assert_equal [ users(:one).email ], mail.to
    assert_equal "You've been invited", mail.subject
    assert_match "Join Acme.", mail.text_part.body.to_s
    assert_no_match("You can review this at", mail.html_part.body.to_s)
  end

  test "notify's signature has no url parameter, since it never links out" do
    keyword_names = NotificationMailer.instance_method(:notify).parameters.map { |_, name| name }

    assert_not_includes keyword_names, :url
  end

  test "notify directs the recipient to the main website by name, not a link" do
    mail = NotificationMailer.notify(user: users(:one), title: "Hello", body: "World")

    assert_match "rxterminal.co.uk", mail.text_part.body.to_s
    assert_match "rxterminal.co.uk", mail.html_part.body.to_s
  end

  test "notify greets the recipient by email when no first name is set" do
    mail = NotificationMailer.notify(user: users(:one), title: "Hello", body: "World")

    assert_match "Hi #{users(:one).email}", mail.text_part.body.to_s
  end

  test "notify renders details as a label/value list in both parts when present" do
    mail = NotificationMailer.notify(
      user: users(:one), title: "Hello", body: "World",
      details: [ [ "IP address", "1.2.3.4" ], [ "Browser", "Chrome 120.0" ] ]
    )

    assert_match "IP address: 1.2.3.4", mail.text_part.body.to_s
    assert_match "Browser: Chrome 120.0", mail.text_part.body.to_s
    assert_match "IP address", mail.html_part.body.to_s
    assert_match "1.2.3.4", mail.html_part.body.to_s
    assert_match "Chrome 120.0", mail.html_part.body.to_s
  end

  test "notify omits the details list entirely when there are no details" do
    mail = NotificationMailer.notify(user: users(:one), title: "Hello", body: "World")

    refute_match(/IP address/, mail.html_part.body.to_s)
  end

  test "notify greets the recipient by first name when one is set" do
    users(:one).update!(first_name: "Ramya")
    mail = NotificationMailer.notify(user: users(:one), title: "Hello", body: "World")

    assert_match "Hi Ramya,", mail.text_part.body.to_s
  end
end
