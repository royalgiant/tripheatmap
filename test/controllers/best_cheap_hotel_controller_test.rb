require "test_helper"

class BestCheapHotelControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create test data
    @city = Neighborhood.create!(
      name: "Test Neighborhood",
      slug: "test-neighborhood",
      city: "toronto",
      state: "ON",
      latitude: 43.6532,
      longitude: -79.3832
    )
    @city.update_column(:city, "toronto")

    # Cheap hotels must have price_range '$' or '$$'
    @cheap_hotel_1 = Place.create!(
      name: "Budget Hotel 1",
      place_type: "hotel",
      price_range: "$",
      average_price: 80,
      rating: 4.5,
      review_count: 100,
      latitude: 43.6532,
      longitude: -79.3832,
      neighborhood: @city,
      city: "toronto"
    )
    @cheap_hotel_1.update_column(:city, "toronto")

    @cheap_hotel_2 = Place.create!(
      name: "Budget Hotel 2",
      place_type: "hotel",
      price_range: "$$",
      average_price: 150,
      rating: 4.0,
      review_count: 50,
      latitude: 43.6532,
      longitude: -79.3832,
      neighborhood: @city,
      city: "toronto"
    )
    @cheap_hotel_2.update_column(:city, "toronto")

    # Should not be included in index but good for testing filters if it were
    @expensive_hotel = Place.create!(
      name: "Expensive Hotel",
      place_type: "hotel",
      price_range: "$$$",
      average_price: 350,
      rating: 4.8,
      review_count: 200,
      latitude: 43.6532,
      longitude: -79.3832,
      neighborhood: @city,
      city: "toronto"
    )
    @expensive_hotel.update_column(:city, "toronto")
  end

  test "should get index" do
    get best_cheap_hotels_index_path
    assert_response :success
  end

  test "should get show for city" do
    get best_cheap_hotels_path('toronto')
    assert_response :success
  end

  test "should filter by price range" do
    get best_cheap_hotels_path('toronto', price: '$')
    assert_response :success
    assert_select 'title', /budget/i
  end

  test "should filter by rating" do
    get best_cheap_hotels_path('toronto', rating: '4.5')
    assert_response :success
    assert_select 'title', /4.5\+ rated/i
  end

  test "should filter by neighborhood slug" do
    get best_cheap_hotels_path('toronto', neighborhood: [@city.slug])
    assert_response :success
    assert_select 'title', /#{@city.name}/i
  end

  test "should filter by max price" do
    get best_cheap_hotels_path('toronto', max_price: 100)
    assert_response :success
    assert_select 'title', /under \$100/i
  end

  test "should combine multiple filters" do
    get best_cheap_hotels_path('toronto', price: '$', rating: '4.5')
    assert_response :success
    assert_select 'title', /budget/i
    assert_select 'title', /4.5\+ rated/i
  end

  test "canonical URL should include filter params" do
    get best_cheap_hotels_path('toronto', price: '$$')
    assert_response :success
    assert_select 'link[rel=canonical][href*="price"]'
  end

  test "should handle invalid filter params gracefully" do
    get best_cheap_hotels_path('toronto', price: 'invalid', rating: -5)
    assert_response :success
  end

  test "should preserve checked filter state from URL params" do
    get best_cheap_hotels_path('toronto', price: '$$')
    assert_response :success
    assert_select 'input[name="price"][value="$$"][checked]'
  end

  test "should use neighborhood slugs in URLs not IDs" do
    get best_cheap_hotels_path('toronto', neighborhood: [@city.slug])
    assert_response :success
    assert_select "input[name='neighborhood[]'][value='#{@city.slug}'][checked]"
  end

  test "canonical URL should use neighborhood slugs" do
    get best_cheap_hotels_path('toronto', neighborhood: [@city.slug])
    assert_response :success
    assert_select "link[rel=canonical][href*='neighborhood']"
    assert_select "link[rel=canonical][href*='#{@city.slug}']"
  end
end
