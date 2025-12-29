require "test_helper"

class NewMessageMailerTest < ActionMailer::TestCase
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
      status: 'sent'
    )
  end

  test "sends notification to guest when host sends message" do
    # Build message without saving to avoid triggering callbacks
    message = OfferMessage.new(
      offer: @offer,
      sender: @host,
      content: "Looking forward to hosting you!",
      created_at: Time.current
    )

    mail = NewMessageMailer.notify(message)

    assert_equal "New message from Cozy Studio", mail.subject
    assert_equal ["guest@test.com"], mail.to
    assert_match "Looking forward to hosting you!", mail.body.encoded
  end

  test "sends notification to host when guest sends message" do
    # Build message without saving to avoid triggering callbacks
    message = OfferMessage.new(
      offer: @offer,
      sender: @guest,
      content: "Thank you for the offer!",
      created_at: Time.current
    )

    mail = NewMessageMailer.notify(message)

    assert_equal "New message from Guest", mail.subject
    assert_equal ["host@test.com"], mail.to
    assert_match "Thank you for the offer!", mail.body.encoded
  end
end
