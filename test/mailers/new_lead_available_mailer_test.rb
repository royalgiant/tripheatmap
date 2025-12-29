require "test_helper"

class NewLeadAvailableMailerTest < ActionMailer::TestCase
  setup do
    @host = FactoryBot.create(:user, email: "host@test.com")
    @guest1 = FactoryBot.create(:user, email: "guest1@test.com")
    @guest2 = FactoryBot.create(:user, email: "guest2@test.com")

    @saved_search1 = SavedSearch.create!(
      user: @guest1,
      location: "Chicago",
      max_price_cents: 20000,
      status: 'active'
    )

    @saved_search2 = SavedSearch.create!(
      user: @guest2,
      location: "Chicago",
      max_price_cents: 25000,
      status: 'active'
    )

    @saved_searches = [@saved_search1, @saved_search2]
  end

  test "sends daily digest to host with multiple leads" do
    mail = NewLeadAvailableMailer.daily_digest(@host, @saved_searches)

    assert_equal "2 new travelers are looking in your area", mail.subject
    assert_equal ["host@test.com"], mail.to
    assert_match "Chicago", mail.body.encoded
  end

  test "sends daily digest with singular lead" do
    mail = NewLeadAvailableMailer.daily_digest(@host, [@saved_search1])

    assert_equal "1 new traveler is looking in your area", mail.subject
    assert_equal ["host@test.com"], mail.to
  end
end
