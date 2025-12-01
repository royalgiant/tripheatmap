require "test_helper"

class BestBoutiqueHotelControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get best_boutique_hotel_index_url
    assert_response :success
  end

  test "should get show" do
    get best_boutique_hotel_show_url
    assert_response :success
  end
end
