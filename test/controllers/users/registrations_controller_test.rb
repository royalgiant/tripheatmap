require "test_helper"

class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "should store location when accessing sign up with return_to parameter" do
    stored_path = "/hotels-near/universities/washington/georgetown-university?price=$$$&rating=4.0"

    get new_user_registration_url(return_to: stored_path)

    assert_response :success
    assert_equal stored_path, session["user_return_to"]
  end

  test "should not store location when return_to parameter is absent" do
    get new_user_registration_url

    assert_response :success
    assert_nil session["user_return_to"]
  end

  test "should create new user and redirect to root by default" do
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

    assert_redirected_to root_path
    assert_match /check your email/i, flash[:notice]
  end

  test "should redirect to stored location after sign up" do
    stored_path = "/best/boutique-hotels/toronto?price=$$&rating=4.0"

    get new_user_registration_url(return_to: stored_path)

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

    assert_redirected_to stored_path
    assert_match /check your email/i, flash[:notice]
  end

  test "should handle validation errors on sign up" do
    assert_no_difference("User.count") do
      post user_registration_url, params: {
        user: {
          email: "",
          password: "pass",
          password_confirmation: "pass",
          first_name: "",
          last_name: ""
        },
        "cf-turnstile-response": "dummy_token"
      }
    end

    assert_response :unprocessable_entity
  end
end
