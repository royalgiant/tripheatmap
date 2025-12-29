require "test_helper"

class EmailPreferenceTest < ActiveSupport::TestCase
  setup do
    @user = FactoryBot.create(:user)
  end

  test "user automatically gets email preferences on creation" do
    new_user = User.create!(
      email: "test@example.com",
      password: "password123",
      first_name: "Test",
      last_name: "User"
    )

    assert_not_nil new_user.email_preference
    assert new_user.email_preference.receive_any_emails
    assert new_user.email_preference.new_lead_daily_digest?
    assert new_user.email_preference.new_offer_daily_digest?
    assert new_user.email_preference.receive_message_emails
    assert new_user.email_preference.receive_offer_expiring_soon_emails
  end

  test "email preference has correct default values" do
    preference = @user.email_preference || @user.create_email_preference

    assert_equal true, preference.receive_any_emails
    assert_equal "daily_digest", preference.new_lead_email_frequency
    assert_equal "daily_digest", preference.new_offer_email_frequency
    assert_equal true, preference.receive_message_emails
    assert_equal true, preference.receive_offer_expiring_soon_emails
  end

  test "can update email frequency preferences" do
    preference = @user.email_preference || @user.create_email_preference

    preference.update!(new_lead_email_frequency: :never)
    assert preference.new_lead_never?

    preference.update!(new_lead_email_frequency: :daily_digest)
    assert preference.new_lead_daily_digest?

    preference.update!(new_lead_email_frequency: :weekly_digest)
    assert preference.new_lead_weekly_digest?
  end

  test "can disable all emails" do
    preference = @user.email_preference || @user.create_email_preference

    preference.update!(receive_any_emails: false)
    assert_not preference.receive_any_emails
  end

  test "validates user presence and uniqueness" do
    preference = EmailPreference.new
    assert_not preference.valid?
    assert_includes preference.errors[:user], "must exist"

    # Create preference for user
    @user.create_email_preference unless @user.email_preference

    # Try to create duplicate
    duplicate = EmailPreference.new(user: @user)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user], "has already been taken"
  end

  test "enum methods work correctly" do
    preference = @user.email_preference || @user.create_email_preference

    # Test new_lead enum methods
    preference.new_lead_email_frequency = :never
    assert preference.new_lead_never?
    assert_not preference.new_lead_daily_digest?
    assert_not preference.new_lead_weekly_digest?

    # Test new_offer enum methods
    preference.new_offer_email_frequency = :daily_digest
    assert preference.new_offer_daily_digest?
    assert_not preference.new_offer_never?
    assert_not preference.new_offer_weekly_digest?
  end
end
