require "test_helper"

class OffersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @guest = FactoryBot.create(:user)
    @host = FactoryBot.create(:user, has_lifetime_access: true)

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
      min_rating: 4.5,
      status: 'active',
      accept_offers: true
    )

    @offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 48.hours.from_now
    )
  end

  # ========== INDEX ==========
  test "guest can view their offers inbox" do
    sign_in @guest
    get offers_path
    assert_response :success
    assert_select "h1", text: /My Offers/i
  end

  test "host can view their offers dashboard" do
    sign_in @host
    get offers_path
    assert_response :success
  end

  test "redirects to login when not authenticated" do
    get offers_path
    assert_redirected_to new_user_session_path
  end

  # ========== SHOW ==========
  test "guest can view their received offer" do
    sign_in @guest
    get offer_path(@offer)
    assert_response :success
  end

  test "host can view their sent offer" do
    sign_in @host
    get offer_path(@offer)
    assert_response :success
  end

  test "cannot view offer that doesn't belong to user" do
    other_user = FactoryBot.create(:user)
    sign_in other_user
    get offer_path(@offer)
    assert_redirected_to root_path
  end

  # ========== NEW ==========
  test "host with subscription can access new offer form" do
    # Create a new saved search without an existing offer
    new_search = SavedSearch.create!(
      user: @guest,
      location: "Chicago",
      max_price_cents: 30000,
      status: 'active',
      accept_offers: true
    )

    sign_in @host
    get new_offer_path(saved_search_id: new_search.id)
    assert_response :success
  end

  test "host without subscription cannot access new offer form" do
    host_without_subscription = FactoryBot.create(:user)
    sign_in host_without_subscription
    get new_offer_path(saved_search_id: @saved_search.id)
    assert_redirected_to root_path
  end

  test "redirects when trying to send duplicate offer" do
    sign_in @host
    # Offer already exists from setup
    get new_offer_path(saved_search_id: @saved_search.id)
    assert_redirected_to offer_path(@offer)
  end

  # ========== CREATE ==========
  test "host can create offer" do
    # Create new saved search for this test
    new_search = SavedSearch.create!(
      user: @guest,
      location: "Chicago",
      max_price_cents: 30000,
      status: 'active',
      accept_offers: true
    )

    sign_in @host
    assert_difference('Offer.count', 1) do
      post offers_path, params: {
        offer: {
          place_id: @place.id,
          saved_search_id: new_search.id,
          offered_price_cents: 22000,
          expires_at: 3.days.from_now
        }
      }
    end
    assert_redirected_to offers_path
  end

  # ========== ACCEPT ==========
  test "guest can accept offer" do
    sign_in @guest
    post accept_offer_path(@offer)
    assert_redirected_to offer_path(@offer)
    @offer.reload
    assert_equal 'accepted', @offer.status
  end

  test "host cannot accept their own offer" do
    sign_in @host
    post accept_offer_path(@offer)
    assert_redirected_to root_path
  end

  # ========== DECLINE ==========
  test "guest can decline offer" do
    sign_in @guest
    post decline_offer_path(@offer)
    assert_redirected_to offers_path
    @offer.reload
    assert_equal 'declined', @offer.status
  end

  test "host cannot decline their own offer" do
    sign_in @host
    post decline_offer_path(@offer)
    assert_redirected_to root_path
  end

  # ========== DESTROY ==========
  test "host can delete their own offer" do
    sign_in @host
    assert_difference('Offer.count', -1) do
      delete offer_path(@offer)
    end
    assert_redirected_to offers_path
  end

  test "guest cannot delete offer" do
    sign_in @guest
    assert_no_difference('Offer.count') do
      delete offer_path(@offer)
    end
    assert_redirected_to root_path
  end
end
