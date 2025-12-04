require "test_helper"

class BestCheapHotelControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get best_cheap_hotels_index_url
    assert_response :success
  end

  test "should get show" do
    get best_cheap_hotels_url("boston")
    assert_response :success
  end
end
