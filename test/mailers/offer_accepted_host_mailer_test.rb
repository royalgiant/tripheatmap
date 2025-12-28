require "test_helper"

class OfferAcceptedHostMailerTest < ActionMailer::TestCase
  test "notify" do
    mail = OfferAcceptedHostMailer.notify
    assert_equal "Notify", mail.subject
    assert_equal ["to@example.org"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_match "Hi", mail.body.encoded
  end

end
