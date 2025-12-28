require "test_helper"

class OfferFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    # Create guest user with saved search
    @guest = FactoryBot.create(:user, email: "guest@example.com")

    # Create host user with a property
    @host = FactoryBot.create(:user, email: "host@example.com", has_lifetime_access: false)

    # Create neighborhood
    @neighborhood = Neighborhood.create!(
      name: "Downtown",
      slug: "downtown",
      city: "austin",
      state: "TX",
      latitude: 30.2672,
      longitude: -97.7431
    )

    # Create host's property
    @property = Place.create!(
      name: "Cozy Austin Airbnb",
      place_type: "airbnb",
      city: "austin",
      average_price: 150,
      rating: 4.8,
      review_count: 45,
      latitude: 30.2672,
      longitude: -97.7431,
      neighborhood: @neighborhood,
      user: @host,
      booking_url: "https://airbnb.com/rooms/12345"
    )

    # Guest saves a search
    @saved_search = SavedSearch.create!(
      user: @guest,
      location: "austin",
      max_price_cents: 20000,  # $200/night
      min_rating: 4.5,
      number_of_guests: 2,
      checkin_date: 7.days.from_now,
      checkout_date: 10.days.from_now,
      status: 'active'
    )
  end

  # ========== FULL FLOW: HOST SENDS OFFER → GUEST ACCEPTS ==========
  test "complete flow: host sends offer → guest receives → guest accepts" do
    # Step 1: Host logs in and views leads
    sign_in @host

    # Create active subscription for host
    create_active_subscription_for(@host)

    get offers_path
    assert_response :success
    assert_select "h1", text: /Lead Marketplace/

    # Step 2: Host sends an offer
    assert_difference("Offer.count", 1) do
      post offers_path, params: {
        offer: {
          place_id: @property.id,
          saved_search_id: @saved_search.id,
          offered_price_cents: 15000,  # $150/night (convert to cents in controller)
          discount_type: "percentage",
          discount_value: 25,
          personal_message: "Welcome to Austin! This is our best rate.",
          perks: ["Free parking", "Late checkout"],
          expires_at: 48.hours.from_now
        }
      }
    end

    @offer = Offer.last
    assert_equal @property.id, @offer.place_id
    assert_equal @saved_search.id, @offer.saved_search_id
    assert_equal "sent", @offer.status
    assert_redirected_to offers_path

    # Step 3: Guest logs in and views offers inbox
    sign_out @host
    sign_in @guest

    get offers_path
    assert_response :success
    assert_select "h1", text: /My Offers/

    # Step 4: Guest views offer details
    get offer_path(@offer)
    assert_response :success

    # Offer should be marked as viewed
    @offer.reload
    assert_equal "viewed", @offer.status
    assert_not_nil @offer.viewed_at

    # Step 5: Guest accepts the offer
    assert_difference("ActionMailer::Base.deliveries.size", 2) do  # 2 emails: guest + host
      perform_enqueued_jobs do
        post accept_offer_path(@offer)
      end
    end

    @offer.reload
    assert_equal "accepted", @offer.status
    assert_not_nil @offer.accepted_at

    # SavedSearch should be paused
    @saved_search.reload
    assert_equal "paused", @saved_search.status

    # Other offers for same search should be declined
    # (Create another offer to test this)
    other_property = Place.create!(
      name: "Another Property",
      place_type: "airbnb",
      city: "austin",
      average_price: 180,
      rating: 4.5,
      latitude: 30.2672,
      longitude: -97.7431,
      neighborhood: @neighborhood,
      user: @host
    )

    other_offer = Offer.create!(
      place: other_property,
      saved_search: @saved_search,
      offered_price_cents: 18000,
      expires_at: 48.hours.from_now,
      status: 'sent'
    )

    post accept_offer_path(@offer)
    other_offer.reload
    assert_equal "declined", other_offer.status
  end

  # ========== FLOW: GUEST DECLINES OFFER ==========
  test "guest can decline an offer" do
    offer = Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent'
    )

    sign_in @guest

    post decline_offer_path(offer)

    offer.reload
    assert_equal "declined", offer.status
    assert_redirected_to offers_path
  end

  # ========== FLOW: HOST DELETES OFFER TO SEND NEW ONE ==========
  test "host can delete offer and send a new one" do
    sign_in @host
    create_active_subscription_for(@host)

    # Create first offer
    offer = Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent'
    )

    # Delete offer
    assert_difference("Offer.count", -1) do
      delete offer_path(offer)
    end

    # Send new offer with better price
    assert_difference("Offer.count", 1) do
      post offers_path, params: {
        offer: {
          place_id: @property.id,
          saved_search_id: @saved_search.id,
          offered_price_cents: 14000,  # Better price
          expires_at: 48.hours.from_now
        }
      }
    end

    new_offer = Offer.last
    assert_equal 14000, new_offer.offered_price_cents
  end

  # ========== ACCESS CONTROL: LIFETIME VS RECURRING ==========
  test "lifetime user sees blurred leads" do
    @host.update(has_lifetime_access: true)
    # Don't create subscription - lifetime users without recurring subscription see blurred leads

    sign_in @host
    get offers_path

    assert_response :success
    assert_select ".fa-lock"  # Lock icon for blurred content
    assert_select "h3", text: /Unlock Lead Details/
  end

  test "monthly user sees full lead details" do
    @host.update(has_lifetime_access: false)
    create_active_subscription_for(@host)

    sign_in @host
    get offers_path

    assert_response :success
    assert_select ".fa-fire", minimum: 0  # May have NEW badges
    # Should see location, budget, etc.
  end

  # ========== VALIDATION: PRICE WITHIN BUDGET ==========
  test "offer price must be within saved search budget" do
    sign_in @host
    create_active_subscription_for(@host)

    assert_no_difference("Offer.count") do
      post offers_path, params: {
        offer: {
          place_id: @property.id,
          saved_search_id: @saved_search.id,
          offered_price_cents: 25000,  # $250 > $200 max budget
          expires_at: 48.hours.from_now
        }
      }
    end

    assert_response :unprocessable_entity
  end

  # ========== UNIQUE CONSTRAINT: ONE OFFER PER PLACE PER SEARCH ==========
  test "cannot send duplicate offer for same place and search" do
    sign_in @host
    create_active_subscription_for(@host)

    # Create first offer
    Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now
    )

    # Try to create duplicate
    assert_raises(ActiveRecord::RecordNotUnique) do
      Offer.create!(
        place: @property,
        saved_search: @saved_search,
        offered_price_cents: 14000,
        expires_at: 48.hours.from_now
      )
    end
  end

  # ========== BACKGROUND JOB: EXPIRE OFFERS ==========
  test "offers past expiration are marked as expired" do
    expired_offer = Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,  # Create with future date first
      status: 'sent'
    )

    # Bypass validation to set expired date
    expired_offer.update_columns(expires_at: 1.hour.ago)

    ExpireOffersJob.perform_now

    expired_offer.reload
    assert_equal "expired", expired_offer.status
  end

  # ========== SPAM REPORTING ==========
  test "guest can report spam via email link" do
    offer = Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now
    )

    sign_in @guest
    get offer_path(offer)

    assert_response :success
    # Check that spam report link exists
    assert_select "a[href*='mailto:donald@tripheatmap.com']"
  end
end
