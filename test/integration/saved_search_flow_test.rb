require "test_helper"

class SavedSearchFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = FactoryBot.create(:user)
    
    @city = Neighborhood.create!(
      name: "Test Neighborhood",
      slug: "test-neighborhood",
      city: "washington",
      state: "DC",
      latitude: 38.9072,
      longitude: -77.0369
    )

    @hotel = Place.create!(
      name: "Test Hotel",
      place_type: "hotel",
      city: "washington",
      price_range: "$$$",
      average_price: 200,
      rating: 4.0,
      review_count: 100,
      latitude: 38.9072,
      longitude: -77.0369,
      neighborhood: @city
    )
  end

  test "full flow: save search → login with email → redirected back → save search" do
    # Step 1: User is not logged in and tries to save a search
    referer_url = hotels_near_university_url("washington", "test-university", price: "$$$", rating: "4.0")
    
    get new_saved_search_url(
      location: "Washington",
      price: "$$$",
      rating: "4.0"
    ), headers: { "HTTP_REFERER" => referer_url }

    # Should redirect to login and store location
    assert_redirected_to new_user_session_url
    stored_location = session["user_return_to"]
    assert stored_location.present?, "Location should be stored in session"

    # Step 2: User logs in with email/password
    post user_session_url, params: {
      user: {
        email: @user.email,
        password: @user.password
      }
    }

    # Should redirect back to the referer URL
    assert_redirected_to referer_url

    # Step 3: Now user can save the search
    sign_in @user
    assert_difference("SavedSearch.count", 1) do
      post saved_searches_url, params: {
        saved_search: {
          location: "washington",
          max_price_cents: 25000,
          min_rating: 4.0,
          price_range: "$$$"
        }
      }, as: :turbo_stream
    end

    saved_search = SavedSearch.last
    assert_equal @user.id, saved_search.user_id
    assert_equal "washington", saved_search.location
    assert_equal "$$$", saved_search.price_range
    assert_equal 4.0, saved_search.min_rating
  end

  # ========== FULL FLOW: OAUTH LOGIN ==========
  test "full flow: save search → oauth login → redirected back" do
    # Setup OAuth
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "oauth123",
      info: {
        email: "oauthuser@example.com",
        first_name: "OAuth",
        last_name: "User",
        name: "OAuth User"
      }
    })
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]

    # Step 1: User tries to save search (not logged in)
    referer_url = "/best/boutique-hotels/toronto?price=$$&rating=4.5"
    
    get new_saved_search_url(
      location: "Toronto",
      price: "$$",
      rating: "4.5"
    ), headers: { "HTTP_REFERER" => referer_url }

    assert_redirected_to new_user_session_url

    # Step 2: User signs in with OAuth
    post user_google_oauth2_omniauth_authorize_path
    follow_redirect!

    assert_redirected_to referer_url

    OmniAuth.config.test_mode = false
    Rails.application.env_config.delete("omniauth.auth")
  end

  # ========== FULL FLOW: SIGN UP ==========
  test "full flow: save search → sign up → redirected back" do
    # Step 1: User tries to save search (not logged in)
    referer_url = "/hotels-near/airports/new-york/jfk?price=$&rating=3.5"
    
    get new_saved_search_url(
      location: "New York",
      price: "$",
      rating: "3.5"
    ), headers: { "HTTP_REFERER" => referer_url }

    assert_redirected_to new_user_session_url

    # Step 2: User clicks "Sign up" 
    get new_user_registration_url(return_to: referer_url)
    assert_response :success

    # Step 3: User signs up
    assert_difference("User.count", 1) do
      post user_registration_url, params: {
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123",
          first_name: "New",
          last_name: "User"
        },
        "cf-turnstile-response": "dummy_token"
      }
    end

    # Should redirect back to the referer URL (after_inactive_sign_up_path_for)
    assert_redirected_to referer_url
  end

  # ========== EDGE CASES ==========
  test "should preserve query parameters through login redirect" do
    # URL with multiple query params
    referer_url = "/hotels-near/universities/washington/georgetown?price=$$$&rating=4.0&neighborhood=downtown&max_price=300"
    
    get new_saved_search_url(
      location: "Washington",
      price: "$$$",
      rating: "4.0",
      neighborhood: ["downtown"],
      max_price: "300"
    ), headers: { "HTTP_REFERER" => referer_url }

    # Login
    post user_session_url, params: {
      user: { email: @user.email, password: @user.password }
    }

    # Should redirect to URL with all params preserved
    assert_redirected_to referer_url
  end

  test "should handle saved search creation when logged in" do
    sign_in @user
    get new_saved_search_url(location: "Chicago", price: "$$")
    assert_response :success
  end
end
