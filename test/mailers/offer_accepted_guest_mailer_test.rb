require "test_helper"

class OfferAcceptedGuestMailerTest < ActionMailer::TestCase
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

    @saved_search = SavedSearch.create!(
      user: @guest,
      location: "Chicago",
      max_price_cents: 20000,
      status: 'active'
    )

    @offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 2.days.from_now,
      status: 'accepted',
      accepted_at: Time.current
    )
  end

  test "sends notification to guest with correct details" do
    mail = OfferAcceptedGuestMailer.notify(@offer)

    assert_equal "Offer accepted: Cozy Studio", mail.subject
    assert_equal ["guest@test.com"], mail.to
    assert_match "Cozy Studio", mail.body.encoded
    assert_match "$150", mail.body.encoded
  end
end
