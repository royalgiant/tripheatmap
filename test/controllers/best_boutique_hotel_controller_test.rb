require "test_helper"

class BestBoutiqueHotelControllerTest < ActionDispatch::IntegrationTest
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

    # Use exact price ranges from radio buttons
    @boutique_hotel_cheap = Place.create!(
      name: "Budget Boutique Hotel",
      place_type: "hotel",
      category: "boutique",
      city: "toronto",
      price_range: "$",
      average_price: 80,
      rating: 4.5,
      review_count: 100,
      latitude: 43.6532,
      longitude: -79.3832,
      neighborhood: @city
    )

    @boutique_hotel_mid = Place.create!(
      name: "Mid-Range Boutique Hotel",
      place_type: "hotel",
      category: "boutique",
      city: "toronto",
      price_range: "$$",
      average_price: 150,
      rating: 4.0,
      review_count: 50,
      latitude: 43.6532,
      longitude: -79.3832,
      neighborhood: @city
    )

    @boutique_hotel_expensive = Place.create!(
      name: "Luxury Boutique Hotel",
      place_type: "hotel",
      category: "boutique",
      city: "toronto",
      price_range: "$$$$",
      average_price: 350,
      rating: 4.8,
      review_count: 200,
      latitude: 43.6532,
      longitude: -79.3832,
      neighborhood: @city
    )
  end

  test "should get index" do
    get best_boutique_hotels_index_path
    assert_response :success
  end

  test "should get show for city" do
    get best_boutique_hotels_path('toronto')
    assert_response :success
  end

  test "should filter by price range" do
    get best_boutique_hotels_path('toronto', price: '$')
    assert_response :success
    assert_select 'title', /budget/i
  end

  test "should filter by rating" do
    get best_boutique_hotels_path('toronto', rating: '4.5')
    assert_response :success
    assert_select 'title', /4.5\+ rated/i
  end

  test "should filter by neighborhood slug" do
    get best_boutique_hotels_path('toronto', neighborhood: [@city.slug])
    assert_response :success
    assert_select 'title', /#{@city.name}/i
  end

  test "should filter by max price" do
    get best_boutique_hotels_path('toronto', max_price: 100)
    assert_response :success
    assert_select 'title', /under \$100/i
  end

  test "should combine multiple filters" do
    get best_boutique_hotels_path('toronto', price: '$', rating: '4.5')
    assert_response :success
    # Should have both filter terms in title
    assert_select 'title', /budget/i
    assert_select 'title', /4.5\+ rated/i
  end

  test "canonical URL should include filter params" do
    get best_boutique_hotels_path('toronto', price: '$$')
    assert_response :success
    assert_select 'link[rel=canonical][href*="price"]'
  end

  test "should handle invalid filter params gracefully" do
    get best_boutique_hotels_path('toronto', price: 'invalid', rating: -5)
    assert_response :success
    # Should still load page even with invalid params
  end

  test "should preserve checked filter state from URL params" do
    get best_boutique_hotels_path('toronto', price: '$$')
    assert_response :success
    # The view uses name="price" for radio buttons
    assert_select 'input[name="price"][value="$$"][checked]'
  end

  test "should use neighborhood slugs in URLs not IDs" do
    get best_boutique_hotels_path('toronto', neighborhood: [@city.slug])
    assert_response :success
    # Check that checkbox values use slugs, not IDs
    assert_select "input[name='neighborhood[]'][value='#{@city.slug}'][checked]"
  end

  test "canonical URL should use neighborhood slugs" do
    get best_boutique_hotels_path('toronto', neighborhood: [@city.slug])
    assert_response :success
    assert_select "link[rel=canonical][href*='neighborhood']"
    assert_select "link[rel=canonical][href*='#{@city.slug}']"
  end
end