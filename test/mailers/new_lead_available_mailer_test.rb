require "test_helper"

class NewLeadAvailableMailerTest < ActionMailer::TestCase
  test "daily_digest" do
    mail = NewLeadAvailableMailer.daily_digest
    assert_equal "Daily digest", mail.subject
    assert_equal ["to@example.org"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_match "Hi", mail.body.encoded
  end

end
