require "test_helper"

class NewMessageMailerTest < ActionMailer::TestCase
  test "notify" do
    mail = NewMessageMailer.notify
    assert_equal "Notify", mail.subject
    assert_equal ["to@example.org"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_match "Hi", mail.body.encoded
  end

end
