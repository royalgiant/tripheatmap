require "test_helper"

class HotelsNearLandmarkControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get hotels_near_landmark_index_path
    assert_response :success
  end

  test "should get show" do
    # This test requires valid city and landmark data
    # Update with actual test data when available
    skip "Need valid city and landmark test data"
  end
end
