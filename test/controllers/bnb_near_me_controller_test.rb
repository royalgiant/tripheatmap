require "test_helper"

class BnbNearMeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @neighborhood = Neighborhood.create!(
      name: "Downtown Atlanta",
      city: "atlanta",
      state: "georgia",
      slug: "downtown-atlanta-ga",
      latitude: 33.7490,
      longitude: -84.3880
    )
    @bnb = FactoryBot.create(:place,
      place_type: "hostel",
      name: "Cozy Bed & Breakfast",
      neighborhood: @neighborhood,
      latitude: 33.7490,
      longitude: -84.3880
    )
  end

  test "should get index" do
    get bnb_near_me_index_path
    assert_response :success
    assert_select "h1", "Bed and Breakfast Near Me"
  end

  test "should get index with location params" do
    get bnb_near_me_index_path(latitude: 33.7490, longitude: -84.3880)
    assert_response :success
  end

  test "should show city" do
    get bnb_near_me_path(city: "atlanta")
    assert_response :success
    assert_match /atlanta/i, response.body
  end

  test "should redirect for non-existent city" do
    get bnb_near_me_path(city: "nonexistent-city")
    assert_redirected_to bnb_near_me_index_path
    assert_equal "City not found", flash[:alert]
  end

  test "should display bed and breakfasts" do
    # Ensure the B&B appears in the scope by checking the query
    bnbs = Place.bed_and_breakfasts.where(neighborhood: @neighborhood)
    assert bnbs.include?(@bnb), "B&B should be in the bed_and_breakfasts scope"

    get bnb_near_me_path(city: "atlanta")
    assert_response :success
  end

  test "should show empty state when no bnbs found" do
    # Create a city with no B&Bs
    Neighborhood.create!(
      name: "Emptyville",
      city: "emptyville",
      state: "pennsylvania",
      slug: "emptyville",
      latitude: 40.0,
      longitude: -75.0
    )

    get bnb_near_me_path(city: "emptyville")
    assert_response :success
    assert_match /No Bed and Breakfasts Found/, response.body
  end

  test "should include other cities for exploration" do
    # Create more cities
    Neighborhood.create!(
      name: "Boston",
      city: "boston",
      state: "massachusetts",
      slug: "boston",
      latitude: 42.3601,
      longitude: -71.0589
    )
    Neighborhood.create!(
      name: "Chicago",
      city: "chicago",
      state: "illinois",
      slug: "chicago",
      latitude: 41.8781,
      longitude: -87.6298
    )

    get bnb_near_me_path(city: "atlanta")
    assert_response :success
    assert_match /Explore Other Cities/, response.body
  end
end
