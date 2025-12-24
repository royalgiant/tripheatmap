require "test_helper"

class SavedSearchesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = FactoryBot.create(:user)
    @saved_search = FactoryBot.create(:saved_search, user: @user)
  end

  test "should get index when logged in" do
    sign_in @user
    get saved_searches_url
    assert_response :success
  end

  test "should redirect to login when not logged in" do
    get saved_searches_url
    assert_redirected_to new_user_session_url
  end

  test "new should redirect to login and store location when not logged in" do
    referer_url = "http://www.example.com/hotels-near/universities/washington/georgetown-university?price=$$$&rating=4.0"

    get new_saved_search_url(
      location: "Washington",
      price: "$$$",
      rating: "4.0"
    ), headers: { "HTTP_REFERER" => referer_url }

    assert_redirected_to new_user_session_url
    assert session["user_return_to"].present?, "Expected stored location in session"
  end

  test "new should render form when logged in" do
    sign_in @user

    get new_saved_search_url(
      location: "Washington",
      price: "$$$",
      rating: "4.0"
    )

    assert_response :success
  end

  test "should create saved_search with valid params" do
    sign_in @user

    assert_difference("SavedSearch.count", 1) do
      post saved_searches_url, params: {
        saved_search: {
          location: "chicago",
          max_price_cents: 20000,
          min_rating: 4.5,
          price_range: "$$$"
        }
      }, as: :turbo_stream
    end

    saved_search = SavedSearch.last
    assert_equal "chicago", saved_search.location
    assert_equal 20000, saved_search.max_price_cents
    assert_equal 4.5, saved_search.min_rating
    assert_equal "$$$", saved_search.price_range
  end

  test "should not create saved_search without filters" do
    sign_in @user

    assert_no_difference("SavedSearch.count") do
      post saved_searches_url, params: {
        saved_search: {
          location: "chicago",
          max_price_cents: nil,
          min_rating: nil,
          price_range: nil,
          neighborhood: nil
        }
      }, as: :turbo_stream
    end
  end

  test "should require authentication for create" do
    assert_no_difference("SavedSearch.count") do
      post saved_searches_url, params: {
        saved_search: {
          location: "chicago",
          max_price_cents: 20000
        }
      }
    end

    assert_redirected_to new_user_session_url
  end

  test "create should clear modal on success" do
    sign_in @user

    post saved_searches_url, params: {
      saved_search: {
        location: "chicago",
        max_price_cents: 20000,
        min_rating: 4.0
      }
    }, as: :turbo_stream

    assert_response :success
    assert_match /save_search_modal/, response.body
  end

  test "should destroy saved_search" do
    sign_in @user

    assert_difference("SavedSearch.count", -1) do
      delete saved_search_url(@saved_search), as: :turbo_stream
    end

    assert_response :success
  end

  test "should not destroy another user's saved_search" do
    other_user = FactoryBot.create(:user)
    other_search = FactoryBot.create(:saved_search, user: other_user)
    sign_in @user

    assert_no_difference("SavedSearch.count") do
      assert_raises(ActiveRecord::RecordNotFound) do
        delete saved_search_url(other_search)
      end
    end
  end

  test "should pause active saved_search" do
    sign_in @user
    @saved_search.update!(status: "active")

    patch pause_saved_search_url(@saved_search), as: :turbo_stream

    assert_response :success
    assert_equal "paused", @saved_search.reload.status
  end

  test "should activate paused saved_search" do
    sign_in @user
    @saved_search.update!(status: "paused")

    patch pause_saved_search_url(@saved_search), as: :turbo_stream

    assert_response :success
    assert_equal "active", @saved_search.reload.status
  end
end
