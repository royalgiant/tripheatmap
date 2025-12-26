require "test_helper"

class RentalsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = create(:user)
    @user.update(role: 'admin') # Grant subscription access
    sign_in @user

    @neighborhood = Neighborhood.first || create_test_neighborhood
    @airbnb_rental = create(:place,
      user: @user,
      place_type: 'airbnb',
      booking_url: 'https://www.airbnb.com/rooms/123',
      neighborhood: @neighborhood
    )
    @vrbo_rental = create(:place,
      user: @user,
      place_type: 'vrbo',
      booking_url: 'https://www.vrbo.com/456',
      neighborhood: @neighborhood
    )
  end

  test "should get index" do
    get rentals_url
    assert_response :success
  end

  test "should get new" do
    get new_rental_url
    assert_response :success
  end

  test "should create airbnb rental" do
    assert_difference('Place.count', 1) do
      post rentals_url, params: {
        place: {
          name: "Test Rental",
          address: "123 Main St",
          latitude: @neighborhood.latitude,
          longitude: @neighborhood.longitude,
          booking_url: "https://www.airbnb.com/rooms/999",
          average_price: 150,
          rental_type: "airbnb"
        }
      }
    end

    assert_redirected_to rentals_path
    rental = Place.last
    assert_equal "airbnb", rental.place_type
    assert_equal "Test Rental", rental.name
    assert_equal 150, rental.average_price
  end

  test "should create vrbo rental" do
    assert_difference('Place.count', 1) do
      post rentals_url, params: {
        place: {
          name: "VRBO Rental",
          address: "456 Oak Ave",
          latitude: @neighborhood.latitude,
          longitude: @neighborhood.longitude,
          booking_url: "https://www.vrbo.com/999",
          average_price: 200,
          rental_type: "vrbo"
        }
      }
    end

    assert_redirected_to rentals_path
    rental = Place.last
    assert_equal "vrbo", rental.place_type
    assert_equal "VRBO Rental", rental.name
    assert_equal 200, rental.average_price
  end

  test "should get edit" do
    get edit_rental_url(@airbnb_rental)
    assert_response :success
  end

  test "should update airbnb rental" do
    patch rental_url(@airbnb_rental), params: {
      place: {
        name: "Updated Name",
        average_price: 175
      }
    }

    assert_redirected_to rentals_path
    @airbnb_rental.reload
    assert_equal "Updated Name", @airbnb_rental.name
    assert_equal 175, @airbnb_rental.average_price
  end

  test "should destroy rental" do
    assert_difference('Place.count', -1) do
      delete rental_url(@airbnb_rental)
    end

    assert_redirected_to rentals_path
  end

  private

  def create_test_neighborhood
    # Create a minimal neighborhood for testing
    Neighborhood.create!(
      name: "Test Neighborhood",
      slug: "test-neighborhood",
      city: "Test City",
      state: "Test State",
      country: "Test Country",
      latitude: 40.7128,
      longitude: -74.0060,
      geom: "POINT(-74.0060 40.7128)"
    )
  end
end
