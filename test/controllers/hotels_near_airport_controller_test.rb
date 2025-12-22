require "test_helper"

class HotelsNearAirportControllerTest < ActionDispatch::IntegrationTest
  setup do
    @city = Neighborhood.create!(
      name: "Test Neighborhood",
      slug: "test-neighborhood",
      city: "toronto",
      state: "ON",
      latitude: 43.6532,
      longitude: -79.3832
    )
    @city.update_column(:city, "toronto")

    @airport = Place.create!(
      name: "Test Airport",
      place_type: "airport",
      slug: "test-airport",
      city: "toronto",
      latitude: 43.6532,
      longitude: -79.3832,
      neighborhood: @city
    )
    @airport.update_column(:city, "toronto")

    @hotel_1 = Place.create!(
      name: "Airport Hotel 1",
      place_type: "hotel",
      price_range: "$",
      rating: 4.5,
      review_count: 100,
      latitude: 43.6532,
      longitude: -79.3832, # Same location, distance 0
      neighborhood: @city,
      city: "toronto"
    )
    @hotel_1.update_column(:city, "toronto")

    @hotel_2 = Place.create!(
      name: "Airport Hotel 2",
      place_type: "hotel",
      price_range: "$$",
      rating: 4.0,
      review_count: 50,
      latitude: 43.6532,
      longitude: -79.3832,
      neighborhood: @city,
      city: "toronto"
    )
    @hotel_2.update_column(:city, "toronto")
  end

  test "should get index" do
    get hotels_near_airport_index_path
    assert_response :success
  end

  test "should get city index" do
    get hotels_near_airport_city_path('toronto')
    assert_response :success
  end

  test "should get show for airport" do
    get hotels_near_airport_path('toronto', @airport.slug)
    assert_response :success
  end

  test "should filter by price range" do
    get hotels_near_airport_path('toronto', @airport.slug, price: '$')
    assert_response :success
    assert_select 'title', /budget/i
  end

  test "should filter by rating" do
    get hotels_near_airport_path('toronto', @airport.slug, rating: '4.5')
    assert_response :success
    assert_select 'title', /4.5\+ rated/i
  end

  test "should filter by max price" do
    get hotels_near_airport_path('toronto', @airport.slug, max_price: 100)
    assert_response :success
    assert_select 'title', /under \$100/i
  end

  test "canonical URL should include filter params" do
    get hotels_near_airport_path('toronto', @airport.slug, price: '$$')
    assert_response :success
    assert_select 'link[rel=canonical][href*="price"]'
  end

  test "should preserve checked filter state from URL params" do
    get hotels_near_airport_path('toronto', @airport.slug, price: '$$')
    assert_response :success
    assert_select 'input[name="price"][value="$$"][checked]'
  end
end