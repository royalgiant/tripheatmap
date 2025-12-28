require "test_helper"

class OfferTest < ActiveSupport::TestCase
  setup do
    @guest = FactoryBot.create(:user)
    @host = FactoryBot.create(:user)

    @neighborhood = Neighborhood.create!(
      name: "Test Neighborhood",
      slug: "test-neighborhood",
      city: "chicago",
      state: "IL",
      latitude: 41.8781,
      longitude: -87.6298
    )

    @place = Place.create!(
      name: "Test Property",
      place_type: "airbnb",
      city: "chicago",
      average_price: 200,
      rating: 4.7,
      latitude: 41.8781,
      longitude: -87.6298,
      neighborhood: @neighborhood,
      user: @host
    )

    @saved_search = SavedSearch.create!(
      user: @guest,
      location: "chicago",
      max_price_cents: 25000,  # $250/night
      min_rating: 4.5,
      status: 'active'
    )
  end

  test "valid offer" do
    offer = Offer.new(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,  # $200/night
      expires_at: 48.hours.from_now
    )

    assert offer.valid?
  end

  test "requires offered_price_cents" do
    offer = Offer.new(
      place: @place,
      saved_search: @saved_search,
      expires_at: 48.hours.from_now
    )

    assert_not offer.valid?
    assert_includes offer.errors[:offered_price_cents], "can't be blank"
  end

  test "requires expires_at" do
    offer = Offer.new(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000
    )

    assert_not offer.valid?
    assert_includes offer.errors[:expires_at], "can't be blank"
  end

  test "price must be within budget" do
    offer = Offer.new(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 30000,  # $300 > $250 max budget
      expires_at: 48.hours.from_now
    )

    assert_not offer.valid?
    assert offer.errors[:offered_price_cents].any? { |msg| msg.match?(/must be within guest's budget/) }
  end

  test "expiration must be in future on create" do
    offer = Offer.new(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 1.hour.ago
    )

    assert_not offer.valid?
    assert_includes offer.errors[:expires_at], "must be in the future"
  end

  test "personal message must be under 500 characters" do
    offer = Offer.new(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 48.hours.from_now,
      personal_message: "a" * 501
    )

    assert_not offer.valid?
    assert offer.errors[:personal_message].any? { |msg| msg.match?(/is too long/) }
  end

  test "unique constraint per place and saved_search" do
    Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 48.hours.from_now
    )

    # Try to create duplicate
    assert_raises(ActiveRecord::RecordNotUnique) do
      Offer.create!(
        place: @place,
        saved_search: @saved_search,
        offered_price_cents: 19000,
        expires_at: 48.hours.from_now
      )
    end
  end

  test "discount_description returns correct format" do
    offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      discount_type: 'percentage',
      discount_value: 15,
      expires_at: 48.hours.from_now
    )

    assert_equal "15% off", offer.discount_description
  end

  test "time_remaining shows days" do
    offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 3.days.from_now
    )

    assert_match /days/, offer.time_remaining
  end

  test "time_remaining shows hours" do
    offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 5.hours.from_now
    )

    assert_match /hours/, offer.time_remaining
  end

  test "time_remaining shows Expired for past dates" do
    offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 48.hours.from_now,
      status: 'sent'
    )
    # Bypass validation to set expired date
    offer.update_columns(expires_at: 1.hour.ago, status: 'expired')

    assert_equal "Expired", offer.time_remaining
  end

  test "mark_viewed! sets viewed_at and changes status" do
    offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 48.hours.from_now,
      status: 'sent'
    )

    offer.mark_viewed!
    offer.reload

    assert_not_nil offer.viewed_at
    assert_equal 'viewed', offer.status
  end

  test "perks_list returns comma-separated perks" do
    offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      perks: ["Free parking", "Late checkout"],
      expires_at: 48.hours.from_now
    )

    assert_equal "Free parking, Late checkout", offer.perks_list
  end

  test "host_user delegation works" do
    offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 48.hours.from_now
    )

    assert_equal @host, offer.host_user
  end

  test "guest_user delegation works" do
    offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 48.hours.from_now
    )

    assert_equal @guest, offer.guest_user
  end

  test "active scope returns sent and viewed offers" do
    sent_offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 48.hours.from_now,
      status: 'sent'
    )

    expired_offer = Offer.create!(
      place: @place,
      saved_search: SavedSearch.create!(
        user: @guest,
        location: "chicago",
        max_price_cents: 25000,
        status: 'active'
      ),
      offered_price_cents: 20000,
      expires_at: 48.hours.from_now,
      status: 'expired'
    )

    active_offers = Offer.active
    assert_includes active_offers, sent_offer
    assert_not_includes active_offers, expired_offer
  end
end
