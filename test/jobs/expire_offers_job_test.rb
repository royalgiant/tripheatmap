require "test_helper"

class ExpireOffersJobTest < ActiveJob::TestCase
  setup do
    @guest = FactoryBot.create(:user)
    @host = FactoryBot.create(:user)

    @neighborhood = Neighborhood.create!(
      name: "Test Neighborhood",
      slug: "test-neighborhood",
      city: "Chicago",
      state: "IL",
      latitude: 41.8781,
      longitude: -87.6298
    )

    @place = Place.create!(
      name: "Test Property",
      place_type: "airbnb",
      city: "Chicago",
      average_price: 200,
      rating: 4.7,
      latitude: 41.8781,
      longitude: -87.6298,
      neighborhood: @neighborhood,
      user: @host
    )

    @saved_search = SavedSearch.create!(
      user: @guest,
      location: "Chicago",
      max_price_cents: 25000,
      status: 'active'
    )
  end

  test "marks expired sent offers as expired" do
    expired_offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 2.hours.from_now,
      status: 'sent'
    )

    # Bypass validation to set expired date
    expired_offer.update_columns(expires_at: 2.hours.ago)

    assert_equal 'sent', expired_offer.status

    ExpireOffersJob.perform_now

    expired_offer.reload
    assert_equal 'expired', expired_offer.status
  end

  test "marks expired viewed offers as expired" do
    expired_offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 2.hours.from_now,
      status: 'viewed'
    )

    # Bypass validation to set expired date
    expired_offer.update_columns(expires_at: 2.hours.ago)

    assert_equal 'viewed', expired_offer.status

    ExpireOffersJob.perform_now

    expired_offer.reload
    assert_equal 'expired', expired_offer.status
  end

  test "does not affect offers that have not expired yet" do
    active_offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 2.hours.from_now,
      status: 'sent'
    )

    assert_equal 'sent', active_offer.status

    ExpireOffersJob.perform_now

    active_offer.reload
    assert_equal 'sent', active_offer.status
  end

  test "does not affect accepted offers even if past expiration" do
    accepted_offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 2.hours.from_now,
      status: 'sent'
    )

    # Accept it then set expired date
    accepted_offer.update!(status: 'accepted', accepted_at: 1.hour.ago)
    accepted_offer.update_columns(expires_at: 2.hours.ago)

    ExpireOffersJob.perform_now

    accepted_offer.reload
    assert_equal 'accepted', accepted_offer.status
  end

  test "does not affect declined offers even if past expiration" do
    declined_offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 2.hours.from_now,
      status: 'sent'
    )

    # Decline it then set expired date
    declined_offer.update!(status: 'declined')
    declined_offer.update_columns(expires_at: 2.hours.ago)

    ExpireOffersJob.perform_now

    declined_offer.reload
    assert_equal 'declined', declined_offer.status
  end

  test "does not affect already expired offers" do
    already_expired = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 2.hours.from_now,
      status: 'sent'
    )

    # Mark as expired then set expired date
    already_expired.update!(status: 'expired')
    already_expired.update_columns(expires_at: 2.hours.ago)

    ExpireOffersJob.perform_now

    already_expired.reload
    assert_equal 'expired', already_expired.status
  end

  test "marks multiple expired offers in one run" do
    # Create multiple expired offers
    offer1 = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 2.hours.from_now,
      status: 'sent'
    )
    offer1.update_columns(expires_at: 2.hours.ago)

    # Create another saved search for second offer
    saved_search2 = SavedSearch.create!(
      user: @guest,
      location: "Chicago",
      max_price_cents: 30000,
      status: 'active'
    )

    offer2 = Offer.create!(
      place: @place,
      saved_search: saved_search2,
      offered_price_cents: 18000,
      expires_at: 2.hours.from_now,
      status: 'viewed'
    )
    offer2.update_columns(expires_at: 1.hour.ago)

    ExpireOffersJob.perform_now

    offer1.reload
    offer2.reload
    assert_equal 'expired', offer1.status
    assert_equal 'expired', offer2.status
  end

  test "logs the count of expired offers" do
    # Create two expired offers
    offer1 = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 2.hours.from_now,
      status: 'sent'
    )
    offer1.update_columns(expires_at: 2.hours.ago)

    saved_search2 = SavedSearch.create!(
      user: @guest,
      location: "Chicago",
      max_price_cents: 30000,
      status: 'active'
    )

    offer2 = Offer.create!(
      place: @place,
      saved_search: saved_search2,
      offered_price_cents: 18000,
      expires_at: 2.hours.from_now,
      status: 'sent'
    )
    offer2.update_columns(expires_at: 1.hour.ago)

    # Capture log output
    assert_changes -> { Offer.where(status: 'expired').count }, from: 0, to: 2 do
      ExpireOffersJob.perform_now
    end
  end

  test "handles edge case when no offers need expiring" do
    # Create only active offers (not expired)
    Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 2.hours.from_now,
      status: 'sent'
    )

    assert_no_changes -> { Offer.where(status: 'expired').count } do
      ExpireOffersJob.perform_now
    end
  end
end
