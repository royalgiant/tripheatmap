require "test_helper"

class Users::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    OmniAuth.config.test_mode = true
    Rails.application.env_config["devise.mapping"] = Devise.mappings[:user]
  end

  teardown do
    OmniAuth.config.test_mode = false
    Rails.application.env_config.delete("omniauth.auth")
  end

  test "should sign in existing user via oauth" do
    existing_user = FactoryBot.create(:user, :oauth_user,
      email: "oauth@example.com",
      provider: "google_oauth2",
      uid: "123456789"
    )

    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "123456789",
      info: {
        email: "oauth@example.com",
        first_name: "OAuth",
        last_name: "User",
        name: "OAuth User"
      }
    })
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]

    get user_google_oauth2_omniauth_callback_path

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "should create new user via oauth" do
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "newuser123",
      info: {
        email: "newuser@example.com",
        first_name: "New",
        last_name: "User",
        name: "New User"
      }
    })
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]

    assert_difference("User.count", 1) do
      get user_google_oauth2_omniauth_callback_path
    end

    user = User.last
    assert_equal "newuser@example.com", user.email
    assert_equal "google_oauth2", user.provider
    assert_equal "newuser123", user.uid
    assert_redirected_to root_path
  end

  test "should redirect to stored location after oauth sign in" do
    existing_user = FactoryBot.create(:user, :oauth_user,
      email: "oauth@example.com",
      provider: "google_oauth2",
      uid: "123456789"
    )

    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "123456789",
      info: { email: "oauth@example.com", first_name: "OAuth", last_name: "User", name: "OAuth User" }
    })
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]

    stored_path = "/hotels-near/universities/washington/georgetown?price=$$$&rating=4.0"
    
    get new_saved_search_url(location: "Washington", price: "$$$"), 
        headers: { "HTTP_REFERER" => stored_path }
    
    assert_redirected_to new_user_session_url

    get user_google_oauth2_omniauth_callback_path

    assert_redirected_to stored_path
  end

  test "should redirect to root when no stored location" do
    existing_user = FactoryBot.create(:user, :oauth_user,
      email: "oauth@example.com",
      provider: "google_oauth2",
      uid: "123456789"
    )

    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "123456789",
      info: { email: "oauth@example.com", first_name: "OAuth", last_name: "User", name: "OAuth User" }
    })
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]

    get user_google_oauth2_omniauth_callback_path

    assert_redirected_to root_path
  end

  test "should handle oauth failure" do
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials

    get user_google_oauth2_omniauth_callback_path
    follow_redirect! if response.redirect?

    # Should redirect to login or show error
    assert_response :success # On the login/error page
  end
end
