require "test_helper"

class OfferCleanupJobTest < ActiveJob::TestCase
  setup do
    # Clear existing data
    Offer.destroy_all
    SavedSearch.destroy_all
    Place.destroy_all
    Neighborhood.destroy_all
    User.destroy_all

    # Create test users
    @host = FactoryBot.create(:user, email: "host@test.com")
    @guest = FactoryBot.create(:user, email: "guest@test.com")

    # Create neighborhood
    @neighborhood = Neighborhood.create!(
      name: "Downtown",
      slug: "downtown",
      city: "austin",
      state: "TX",
      latitude: 30.2672,
      longitude: -97.7431
    )

    # Create property
    @property = Place.create!(
      name: "Test Property",
      place_type: "airbnb",
      city: "austin",
      average_price: 150,
      rating: 4.8,
      latitude: 30.2672,
      longitude: -97.7431,
      neighborhood: @neighborhood,
      user: @host
    )

    # Create saved search
    @saved_search = SavedSearch.create!(
      user: @guest,
      location: "austin",
      max_price_cents: 20000,
      status: 'active'
    )
  end

  test "deletes expired offers older than 90 days" do
    # Create old expired offer (> 90 days)
    old_expired = Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent'
    )
    old_expired.update_columns(expires_at: 100.days.ago, status: 'expired', updated_at: 95.days.ago)

    # Create recent expired offer (< 90 days)
    recent_search = SavedSearch.create!(user: @guest, location: "austin", max_price_cents: 21000, status: 'active')
    recent_expired = Offer.create!(
      place: @property,
      saved_search: recent_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent'
    )
    recent_expired.update_columns(expires_at: 10.days.ago, status: 'expired', updated_at: 10.days.ago)

    assert_difference("Offer.count", -1) do
      OfferCleanupJob.perform_now
    end

    # Old expired should be deleted
    assert_nil Offer.find_by(id: old_expired.id)

    # Recent expired should still exist
    assert_not_nil Offer.find_by(id: recent_expired.id)
  end

  test "deletes declined offers older than 90 days" do
    # Create old declined offer (> 90 days)
    old_declined = Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'declined'
    )
    old_declined.update_columns(updated_at: 95.days.ago)

    # Create recent declined offer (< 90 days)
    recent_search = SavedSearch.create!(user: @guest, location: "austin", max_price_cents: 22000, status: 'active')
    recent_declined = Offer.create!(
      place: @property,
      saved_search: recent_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'declined'
    )
    recent_declined.update_columns(updated_at: 10.days.ago)

    assert_difference("Offer.count", -1) do
      OfferCleanupJob.perform_now
    end

    # Old declined should be deleted
    assert_nil Offer.find_by(id: old_declined.id)

    # Recent declined should still exist
    assert_not_nil Offer.find_by(id: recent_declined.id)
  end

  test "keeps accepted offers regardless of age" do
    # Create old accepted offer (> 90 days)
    old_accepted = Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'accepted',
      accepted_at: 95.days.ago
    )
    old_accepted.update_columns(updated_at: 95.days.ago)

    assert_no_difference("Offer.count") do
      OfferCleanupJob.perform_now
    end

    # Accepted offer should still exist
    assert_not_nil Offer.find_by(id: old_accepted.id)
  end

  test "keeps sent offers regardless of age" do
    # Create old sent offer (> 90 days)
    old_sent = Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent'
    )
    old_sent.update_columns(updated_at: 95.days.ago)

    assert_no_difference("Offer.count") do
      OfferCleanupJob.perform_now
    end

    # Sent offer should still exist
    assert_not_nil Offer.find_by(id: old_sent.id)
  end

  test "keeps viewed offers regardless of age" do
    # Create old viewed offer (> 90 days)
    old_viewed = Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'viewed',
      viewed_at: 95.days.ago
    )
    old_viewed.update_columns(updated_at: 95.days.ago)

    assert_no_difference("Offer.count") do
      OfferCleanupJob.perform_now
    end

    # Viewed offer should still exist
    assert_not_nil Offer.find_by(id: old_viewed.id)
  end

  test "deletes multiple old expired and declined offers in single run" do
    # Create 3 old expired offers
    3.times do |i|
      search = SavedSearch.create!(user: @guest, location: "austin", max_price_cents: (25000 + i * 1000), status: 'active')
      offer = Offer.create!(
        place: @property,
        saved_search: search,
        offered_price_cents: 15000,
        expires_at: 48.hours.from_now,
        status: 'sent'
      )
      offer.update_columns(expires_at: 100.days.ago, status: 'expired', updated_at: (95 + i).days.ago)
    end

    # Create 2 old declined offers
    2.times do |i|
      search = SavedSearch.create!(user: @guest, location: "austin", max_price_cents: (28000 + i * 1000), status: 'active')
      offer = Offer.create!(
        place: @property,
        saved_search: search,
        offered_price_cents: 15000,
        expires_at: 48.hours.from_now,
        status: 'declined'
      )
      offer.update_columns(updated_at: (95 + i).days.ago)
    end

    # Should delete all 5 old offers
    assert_difference("Offer.count", -5) do
      OfferCleanupJob.perform_now
    end
  end

  test "does not delete if no old offers exist" do
    # Create only recent offers
    Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent'
    )

    assert_no_difference("Offer.count") do
      OfferCleanupJob.perform_now
    end
  end

  test "uses updated_at for age check, not created_at" do
    # Create offer with old created_at but recent updated_at
    offer = Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'expired'
    )

    # Set created_at old but updated_at recent
    offer.update_columns(
      created_at: 100.days.ago,
      updated_at: 10.days.ago
    )

    # Should NOT delete (updated_at is recent)
    assert_no_difference("Offer.count") do
      OfferCleanupJob.perform_now
    end

    assert_not_nil Offer.find_by(id: offer.id)
  end

  test "exactly 90 days old offers are not deleted" do
    # Create offer exactly 90 days old (plus 1 second to avoid edge case)
    timestamp = 90.days.ago + 1.second
    offer = Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'expired'
    )
    offer.update_columns(updated_at: timestamp)

    # Should NOT delete (must be OLDER than 90 days, not equal)
    assert_no_difference("Offer.count") do
      OfferCleanupJob.perform_now
    end

    assert_not_nil Offer.find_by(id: offer.id)
  end

  test "90 days + 1 second old offers are deleted" do
    # Create offer 90 days + 1 second old
    offer = Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'expired'
    )
    offer.update_columns(updated_at: 90.days.ago - 1.second)

    # Should delete
    assert_difference("Offer.count", -1) do
      OfferCleanupJob.perform_now
    end

    assert_nil Offer.find_by(id: offer.id)
  end

  test "deletes both expired and declined but not other statuses in mixed scenario" do
    # Create one of each status, all old
    statuses = ['expired', 'declined', 'accepted', 'sent', 'viewed']
    offers = statuses.map.with_index do |status, i|
      search = SavedSearch.create!(user: @guest, location: "austin", max_price_cents: (30000 + i * 1000), status: 'active')
      offer = Offer.create!(
        place: @property,
        saved_search: search,
        offered_price_cents: 15000,
        expires_at: 48.hours.from_now,
        status: status
      )
      offer.update_columns(updated_at: 95.days.ago)
      offer
    end

    # Should delete only expired and declined (2 offers)
    assert_difference("Offer.count", -2) do
      OfferCleanupJob.perform_now
    end

    # Verify correct offers were deleted
    assert_nil Offer.find_by(id: offers[0].id) # expired - deleted
    assert_nil Offer.find_by(id: offers[1].id) # declined - deleted
    assert_not_nil Offer.find_by(id: offers[2].id) # accepted - kept
    assert_not_nil Offer.find_by(id: offers[3].id) # sent - kept
    assert_not_nil Offer.find_by(id: offers[4].id) # viewed - kept
  end
end
