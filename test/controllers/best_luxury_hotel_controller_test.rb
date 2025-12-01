require "test_helper"

class BestLuxuryHotelControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get best_luxury_hotel_index_url
    assert_response :success
  end

  test "should get show" do
    get best_luxury_hotel_show_url
    assert_response :success
  end
end
