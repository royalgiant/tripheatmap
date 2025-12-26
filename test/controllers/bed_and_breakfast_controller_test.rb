require "test_helper"

class BedAndBreakfastControllerTest < ActionDispatch::IntegrationTest
  setup do
    @neighborhood = Neighborhood.create!(
      name: "Downtown Atlanta",
      city: "atlanta",
      state: "georgia",
      slug: "atlanta",
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

  # Index tests
  test "should get index" do
    get bed_and_breakfast_index_path
    assert_response :success
    assert_select "h1", "Bed and Breakfast by City"
  end

  test "index should show cities with B&B counts" do
    get bed_and_breakfast_index_path
    assert_response :success
    assert_match /Atlanta/, response.body
  end

  # Location (In) pattern: bed-and-breakfast/in/[city]
  test "should show B&Bs with location-in pattern" do
    get bed_and_breakfast_in_city_path(city: "atlanta")
    assert_response :success
    assert_match /Bed and Breakfast in Atlanta/, response.body
  end

  test "location-in pattern should have canonical URL" do
    get bed_and_breakfast_in_city_path(city: "atlanta")
    assert_response :success
    assert_match /<link rel="canonical" href=".*bed-and-breakfast\/in\/atlanta"/, response.body
  end

  # Location (Pre) pattern: bed-and-breakfast/[city]/[state]
  test "should show B&Bs with location-pre pattern" do
    get bed_and_breakfast_city_state_path(city: "atlanta", state: "georgia")
    assert_response :success
    assert_match /Bed and Breakfast in Atlanta/, response.body
  end

  test "location-pre pattern should redirect to canonical" do
    get bed_and_breakfast_city_state_path(city: "atlanta", state: "georgia")
    assert_response :success
    # Should have canonical URL pointing to "location-in" pattern
    assert_match /<link rel="canonical" href=".*bed-and-breakfast\/in\/atlanta"/, response.body
  end

  # Location (Post) pattern: [city]/bed-and-breakfast
  test "should show B&Bs with location-post pattern" do
    get city_bed_and_breakfast_path(city: "atlanta")
    assert_response :success
    assert_match /Bed and Breakfast in Atlanta/, response.body
  end

  test "location-post pattern should redirect to canonical" do
    get city_bed_and_breakfast_path(city: "atlanta")
    assert_response :success
    # Should have canonical URL pointing to "location-in" pattern
    assert_match /<link rel="canonical" href=".*bed-and-breakfast\/in\/atlanta"/, response.body
  end

  # Test that all patterns point to same canonical
  test "all three patterns should have same canonical URL" do
    # Get canonical from each pattern
    get bed_and_breakfast_in_city_path(city: "atlanta")
    canonical_in = response.body.match(/<link rel="canonical" href="([^"]+)"/)&.[](1)

    get bed_and_breakfast_city_state_path(city: "atlanta", state: "georgia")
    canonical_pre = response.body.match(/<link rel="canonical" href="([^"]+)"/)&.[](1)

    get city_bed_and_breakfast_path(city: "atlanta")
    canonical_post = response.body.match(/<link rel="canonical" href="([^"]+)"/)&.[](1)

    # All should be the same
    assert_equal canonical_in, canonical_pre
    assert_equal canonical_in, canonical_post
  end

  test "should redirect for non-existent city" do
    get bed_and_breakfast_in_city_path(city: "nonexistent")
    assert_redirected_to bnb_near_me_index_path
    assert_equal "City not found", flash[:alert]
  end

  test "should show empty state when no bnbs found" do
    empty_neighborhood = Neighborhood.create!(
      name: "Emptyville",
      city: "emptyville",
      state: "pennsylvania",
      slug: "emptyville",
      latitude: 40.0,
      longitude: -75.0
    )

    get bed_and_breakfast_in_city_path(city: "emptyville")
    assert_response :success
    assert_match /No Bed and Breakfasts Found/, response.body
  end

  test "should include explore cities section" do
    # Create another city for exploration
    Neighborhood.create!(
      name: "Boston",
      city: "boston",
      state: "massachusetts",
      slug: "boston",
      latitude: 42.3601,
      longitude: -71.0589
    )

    get bed_and_breakfast_in_city_path(city: "atlanta")
    assert_response :success
    assert_match /Explore Other Cities/, response.body
  end
end
