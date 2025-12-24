require "test_helper"

class SavedSearchTest < ActiveSupport::TestCase
  setup do
    @user = FactoryBot.create(:user)
  end

  test "should be valid with required fields" do
    search = SavedSearch.new(
      user: @user,
      location: "new york",
      max_price_cents: 15000
    )

    assert search.valid?
  end

  test "should be invalid without max_price_cents" do
    search = SavedSearch.new(
      user: @user,
      location: "new york",
      max_price_cents: nil,
      min_rating: 4.0
    )

    assert_not search.valid?
    assert_includes search.errors[:max_price_cents], "can't be blank"
  end

  test "should be valid with additional filters" do
    search = SavedSearch.new(
      user: @user,
      location: "chicago",
      max_price_cents: 20000,
      min_rating: 4.0,
      price_range: "$$"
    )

    assert search.valid?
  end

  test "should require location" do
    search = SavedSearch.new(
      user: @user,
      location: nil,
      max_price_cents: 15000
    )

    assert_not search.valid?
    assert_includes search.errors[:location], "can't be blank"
  end

  test "should require user" do
    search = SavedSearch.new(
      user: nil,
      location: "new york",
      max_price_cents: 15000
    )

    assert_not search.valid?
    assert_includes search.errors[:user], "must exist"
  end

  test "should normalize location to lowercase" do
    search = FactoryBot.create(:saved_search,
      user: @user,
      location: "New York City"
    )

    assert_equal "new york city", search.location
  end

  test "should require max_price_cents to be greater than 0" do
    search = SavedSearch.new(
      user: @user,
      location: "new york",
      max_price_cents: 0
    )

    assert_not search.valid?
    assert_includes search.errors[:max_price_cents], "must be greater than 0"
  end

  # ========== STATUS TESTS ==========
  test "should default status to active" do
    search = FactoryBot.create(:saved_search, user: @user)

    assert_equal "active", search.status
  end

  test "can toggle between active and paused" do
    search = FactoryBot.create(:saved_search, user: @user)

    search.update!(status: "paused")
    assert_equal "paused", search.status

    search.update!(status: "active")
    assert_equal "active", search.status
  end

  # ========== ASSOCIATION TESTS ==========
  test "should belong to user" do
    search = FactoryBot.create(:saved_search, user: @user)

    assert_equal @user, search.user
  end

  test "should be destroyed when user is destroyed" do
    search = FactoryBot.create(:saved_search, user: @user)

    assert_difference("SavedSearch.count", -1) do
      @user.destroy
    end
  end

  # ========== PRICE CONVERSION TESTS ==========
  test "should store price in cents" do
    search = FactoryBot.create(:saved_search,
      user: @user,
      max_price_cents: 20000
    )

    assert_equal 20000, search.max_price_cents
    assert_equal 200.0, search.max_price
  end

  test "should convert dollars to cents using max_price= setter" do
    search = SavedSearch.new(
      user: @user,
      location: "boston"
    )
    search.max_price = 150

    assert_equal 15000, search.max_price_cents
  end

  # ========== FILTER COMBINATIONS ==========
  test "should allow multiple filters" do
    search = FactoryBot.create(:saved_search,
      user: @user,
      location: "san francisco",
      max_price_cents: 25000,
      min_rating: 4.5,
      price_range: "$$$",
      neighborhood: "downtown-san-francisco-ca"
    )

    assert search.valid?
    assert_equal 25000, search.max_price_cents
    assert_equal 4.5, search.min_rating
    assert_equal "$$$", search.price_range
    assert_equal "downtown-san-francisco-ca", search.neighborhood
  end

  # ========== DATE TESTS ==========
  test "should allow optional check-in and check-out dates" do
    search = FactoryBot.create(:saved_search, :with_dates,
      user: @user
    )

    assert search.checkin_date.present?
    assert search.checkout_date.present?
    assert search.checkout_date > search.checkin_date
  end

  test "should be valid without dates" do
    search = FactoryBot.create(:saved_search,
      user: @user,
      checkin_date: nil,
      checkout_date: nil
    )

    assert search.valid?
  end

  # ========== RATING VALIDATION ==========
  test "should only allow valid rating values" do
    search = SavedSearch.new(
      user: @user,
      location: "seattle",
      max_price_cents: 18000,
      min_rating: 4.2
    )

    assert_not search.valid?
    assert_includes search.errors[:min_rating], "is not included in the list"
  end

  test "should allow nil rating" do
    search = SavedSearch.new(
      user: @user,
      location: "seattle",
      max_price_cents: 18000,
      min_rating: nil
    )

    assert search.valid?
  end
end
