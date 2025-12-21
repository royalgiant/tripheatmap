require "test_helper"

class BestBoutiqueHotelControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create test data
    @city = Neighborhood.create!(
      name: "Test Neighborhood",
      slug: "test-neighborhood",
      city: "toronto",
      latitude: 43.6532,
      longitude: -79.3832
    )

    @boutique_hotel_cheap = Place.create!(
      name: "Budget Boutique Hotel",
      place_type: "hotel",
      category: "boutique",
      price_range: "$",
      average_price: 80,
      rating: 4.5,
      review_count: 100,
      latitude: 43.6532,
      longitude: -79.3832,
      neighborhood: @city
    )

    @boutique_hotel_expensive = Place.create!(
      name: "Luxury Boutique Hotel",
      place_type: "hotel",
      category: "boutique",
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
    get boutique_hotels_index_path
    assert_response :success
  end

  test "should get show for city" do
    get boutique_hotels_path('toronto')
    assert_response :success
  end

  test "should filter by price range" do
    get boutique_hotels_path('toronto', price: ['$'])
    assert_response :success
    assert_select 'title', /budget/i
  end

  test "should filter by rating" do
    get boutique_hotels_path('toronto', rating: ['4.5'])
    assert_response :success
    assert_select 'title', /4.5\+ rated/i
  end

  test "should filter by neighborhood slug" do
    get boutique_hotels_path('toronto', neighborhood: [@city.slug])
    assert_response :success
    assert_select 'title', /#{@city.name}/i
  end

  test "should filter by max price" do
    get boutique_hotels_path('toronto', max_price: 100)
    assert_response :success
    assert_select 'title', /under \$100/i
  end

  test "should combine multiple filters" do
    get boutique_hotels_path('toronto', price: ['$'], rating: ['4.5'])
    assert_response :success
    # Should have both filter terms in title
    assert_select 'title', /budget/i
    assert_select 'title', /4.5\+ rated/i
  end

  test "canonical URL should include filter params" do
    get boutique_hotels_path('toronto', price: ['$$'])
    assert_response :success
    assert_select 'link[rel=canonical][href*="price"]'
  end

  test "pagination should preserve filter params" do
    # Create enough hotels to trigger pagination
    25.times do |i|
      Place.create!(
        name: "Test Hotel #{i}",
        place_type: "hotel",
        category: "boutique",
        price_range: "$$",
        rating: 4.0,
        review_count: 50,
        latitude: 43.6532,
        longitude: -79.3832,
        neighborhood: @city
      )
    end

    get boutique_hotels_path('toronto', price: ['$$'], page: 1)
    assert_response :success
    # Check that the next page link includes filter params
    assert_select 'turbo-frame[src*="price"]'
  end

  test "should handle invalid filter params gracefully" do
    get boutique_hotels_path('toronto', price: ['invalid'], rating: [-5])
    assert_response :success
    # Should still load page even with invalid params
  end

  test "should preserve checked filter state from URL params" do
    get boutique_hotels_path('toronto', price: ['$$'])
    assert_response :success
    assert_select 'input[name="price[]"][value="$$"][checked]'
  end

  test "should use neighborhood slugs in URLs not IDs" do
    get boutique_hotels_path('toronto', neighborhood: [@city.slug])
    assert_response :success
    # Check that checkbox values use slugs, not IDs
    assert_select "input[name='neighborhood[]'][value='#{@city.slug}'][checked]"
  end

  test "canonical URL should use neighborhood slugs" do
    get boutique_hotels_path('toronto', neighborhood: [@city.slug])
    assert_response :success
    assert_select "link[rel=canonical][href*='neighborhood=#{@city.slug}']"
  end
end
