require "test_helper"

class BestNeighborhoodControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get best_neighborhood_show_url
    assert_response :success
  end
end
