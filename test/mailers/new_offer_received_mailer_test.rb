require "test_helper"

class NewOfferReceivedMailerTest < ActionMailer::TestCase
  setup do
    @guest = FactoryBot.create(:user, email: "guest@test.com")
    @host = FactoryBot.create(:user, email: "host@test.com")

    @neighborhood = Neighborhood.create!(
      name: "Test Neighborhood",
      slug: "test-neighborhood",
      city: "Chicago",
      state: "IL",
      latitude: 41.8781,
      longitude: -87.6298
    )

    @place = Place.create!(
      name: "Cozy Studio",
      place_type: "airbnb",
      city: "Chicago",
      average_price: 150,
      rating: 4.8,
      latitude: 41.8781,
      longitude: -87.6298,
      neighborhood: @neighborhood,
      user: @host
    )

    @saved_search1 = SavedSearch.create!(
      user: @guest,
      location: "Chicago",
      max_price_cents: 20000,
      status: 'active'
    )

    @saved_search2 = SavedSearch.create!(
      user: @guest,
      location: "Chicago",
      max_price_cents: 25000,
      status: 'active'
    )

    @offer1 = Offer.create!(
      place: @place,
      saved_search: @saved_search1,
      offered_price_cents: 15000,
      expires_at: 2.days.from_now,
      status: 'sent'
    )

    @offer2 = Offer.create!(
      place: @place,
      saved_search: @saved_search2,
      offered_price_cents: 14000,
      expires_at: 2.days.from_now,
      status: 'sent'
    )

    @offers = [@offer1, @offer2]
  end

  test "sends daily digest to guest with multiple offers" do
    mail = NewOfferReceivedMailer.daily_digest(@guest, @offers)

    assert_equal "You received 2 new offers for your saved searches", mail.subject
    assert_equal ["guest@test.com"], mail.to
    assert_match "Cozy Studio", mail.body.encoded
  end

  test "sends daily digest with singular offer" do
    mail = NewOfferReceivedMailer.daily_digest(@guest, [@offer1])

    assert_equal "You received 1 new offer for your saved searches", mail.subject
    assert_equal ["guest@test.com"], mail.to
  end
end
