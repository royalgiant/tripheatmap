require "test_helper"

class OfferMessageTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    # Clear existing data
    OfferMessage.destroy_all
    Offer.destroy_all
    SavedSearch.destroy_all
    Place.destroy_all
    Neighborhood.destroy_all
    User.destroy_all

    # Create users
    @guest = FactoryBot.create(:user, email: "guest@test.com")
    @host = FactoryBot.create(:user, email: "host@test.com")

    # Create neighborhood
    @neighborhood = Neighborhood.create!(
      name: "Downtown",
      slug: "downtown",
      city: "austin",
      state: "TX",
      latitude: 30.2672,
      longitude: -97.7431
    )

    # Create property
    @property = Place.create!(
      name: "Test Property",
      place_type: "airbnb",
      city: "austin",
      average_price: 150,
      rating: 4.8,
      latitude: 30.2672,
      longitude: -97.7431,
      neighborhood: @neighborhood,
      user: @host
    )

    # Create saved search
    @saved_search = SavedSearch.create!(
      user: @guest,
      location: "austin",
      max_price_cents: 20000,
      status: 'active'
    )

    # Create offer
    @offer = Offer.create!(
      place: @property,
      saved_search: @saved_search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent'
    )

    # Clear ActionMailer deliveries
    ActionMailer::Base.deliveries.clear
  end

  # ========== VALIDATION TESTS ==========

  test "valid message from guest to host" do
    message = OfferMessage.new(
      offer: @offer,
      sender: @guest,
      content: "What time is check-in?"
    )

    assert message.valid?
  end

  test "valid message from host to guest" do
    message = OfferMessage.new(
      offer: @offer,
      sender: @host,
      content: "Check-in is at 3 PM"
    )

    assert message.valid?
  end

  test "requires content" do
    message = OfferMessage.new(
      offer: @offer,
      sender: @guest
    )

    assert_not message.valid?
    assert_includes message.errors[:content], "can't be blank"
  end

  test "content must be at least 1 character" do
    message = OfferMessage.new(
      offer: @offer,
      sender: @guest,
      content: ""
    )

    assert_not message.valid?
    assert_includes message.errors[:content], "is too short (minimum is 1 character)"
  end

  test "content cannot exceed 2000 characters" do
    message = OfferMessage.new(
      offer: @offer,
      sender: @guest,
      content: "a" * 2001
    )

    assert_not message.valid?
    assert_includes message.errors[:content], "is too long (maximum is 2000 characters)"
  end

  test "content can be exactly 2000 characters" do
    message = OfferMessage.new(
      offer: @offer,
      sender: @guest,
      content: "a" * 2000
    )

    assert message.valid?
  end

  test "requires offer" do
    message = OfferMessage.new(
      sender: @guest,
      content: "Hello"
    )

    assert_not message.valid?
    assert_includes message.errors[:offer], "must exist"
  end

  test "requires sender" do
    message = OfferMessage.new(
      offer: @offer,
      content: "Hello"
    )

    assert_not message.valid?
    assert_includes message.errors[:sender], "must exist"
  end

  # ========== ASSOCIATION TESTS ==========

  test "belongs to offer" do
    message = OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "Test message"
    )

    assert_equal @offer, message.offer
  end

  test "polymorphic sender works with User" do
    message = OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "Test message"
    )

    assert_equal @guest, message.sender
    assert_equal "User", message.sender_type
  end

  # ========== INSTANCE METHOD TESTS ==========

  test "from_host? returns true when sender is host" do
    message = OfferMessage.create!(
      offer: @offer,
      sender: @host,
      content: "Test from host"
    )

    assert message.from_host?
    assert_not message.from_guest?
  end

  test "from_guest? returns true when sender is guest" do
    message = OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "Test from guest"
    )

    assert message.from_guest?
    assert_not message.from_host?
  end

  test "mark_read! sets read_at timestamp" do
    message = OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "Test message"
    )

    assert_nil message.read_at

    message.mark_read!
    message.reload

    assert_not_nil message.read_at
    assert_instance_of ActiveSupport::TimeWithZone, message.read_at
  end

  test "mark_read! is idempotent (does not update if already read)" do
    message = OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "Test message"
    )

    # Mark as read first time
    message.mark_read!
    message.reload
    first_read_at = message.read_at

    # Try to mark as read again
    message.mark_read!
    message.reload

    # read_at should not change
    assert_equal first_read_at, message.read_at
  end

  # ========== SCOPE TESTS ==========

  test "unread scope returns only messages without read_at" do
    read_message = OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "Read message",
      read_at: Time.current
    )

    unread_message = OfferMessage.create!(
      offer: @offer,
      sender: @host,
      content: "Unread message"
    )

    unread_messages = OfferMessage.unread

    assert_includes unread_messages, unread_message
    assert_not_includes unread_messages, read_message
  end

  test "for_user scope returns all messages for user's offers" do
    guest_message = OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "Message from guest"
    )

    host_message = OfferMessage.create!(
      offer: @offer,
      sender: @host,
      content: "Message from host"
    )

    other_user = FactoryBot.create(:user, email: "other@test.com")
    other_property = Place.create!(
      name: "Other Property",
      place_type: "airbnb",
      city: "austin",
      average_price: 200,
      rating: 4.5,
      latitude: 30.2672,
      longitude: -97.7431,
      neighborhood: @neighborhood,
      user: other_user
    )
    other_search = SavedSearch.create!(
      user: other_user,
      location: "austin",
      max_price_cents: 25000,
      status: 'active'
    )
    other_offer = Offer.create!(
      place: other_property,
      saved_search: other_search,
      offered_price_cents: 20000,
      expires_at: 48.hours.from_now,
      status: 'sent'
    )
    other_message = OfferMessage.create!(
      offer: other_offer,
      sender: other_user,
      content: "Message from other user"
    )

    guest_messages = OfferMessage.for_user(@guest)
    assert_includes guest_messages, guest_message
    assert_includes guest_messages, host_message
    assert_not_includes guest_messages, other_message

    host_messages = OfferMessage.for_user(@host)
    assert_includes host_messages, guest_message
    assert_includes host_messages, host_message
    assert_not_includes host_messages, other_message

    other_user_messages = OfferMessage.for_user(other_user)
    assert_includes other_user_messages, other_message
    assert_not_includes other_user_messages, guest_message
    assert_not_includes other_user_messages, host_message
  end

  # ========== CALLBACK TESTS ==========

  test "sends email notification after create" do
    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      perform_enqueued_jobs do
        OfferMessage.create!(
          offer: @offer,
          sender: @guest,
          content: "What time is check-in?"
        )
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [@host.email], email.to
    assert_match /new message/i, email.subject
  end

  test "notification email sent to host when guest sends message" do
    ActionMailer::Base.deliveries.clear

    perform_enqueued_jobs do
      message = OfferMessage.create!(
        offer: @offer,
        sender: @guest,
        content: "Question from guest"
      )
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [@host.email], email.to
  end

  test "notification email sent to guest when host sends message" do
    ActionMailer::Base.deliveries.clear

    perform_enqueued_jobs do
      message = OfferMessage.create!(
        offer: @offer,
        sender: @host,
        content: "Response from host"
      )
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [@guest.email], email.to
  end

  test "does not send notification on update" do
    message = OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "Original content"
    )

    ActionMailer::Base.deliveries.clear

    assert_no_difference("ActionMailer::Base.deliveries.size") do
      message.update(content: "Updated content")
    end
  end

  # ========== DEPENDENT DESTROY TESTS ==========

  test "messages are deleted when offer is deleted" do
    # Create messages for the offer
    message1 = OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "Message 1"
    )

    message2 = OfferMessage.create!(
      offer: @offer,
      sender: @host,
      content: "Message 2"
    )

    assert_difference("OfferMessage.count", -2) do
      @offer.destroy
    end

    assert_nil OfferMessage.find_by(id: message1.id)
    assert_nil OfferMessage.find_by(id: message2.id)
  end

  # ========== CONVERSATION FLOW TESTS ==========

  test "can create back-and-forth conversation" do
    # Guest sends first message
    message1 = OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "Is parking available?"
    )

    # Host responds
    message2 = OfferMessage.create!(
      offer: @offer,
      sender: @host,
      content: "Yes, free parking is included"
    )

    # Guest replies
    message3 = OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "Great, thank you!"
    )

    assert_equal 3, @offer.messages.count
    assert_equal [message1, message2, message3], @offer.messages.order(:created_at)
  end

  test "messages ordered by created_at" do
    # Create messages out of chronological order
    message2 = OfferMessage.create!(
      offer: @offer,
      sender: @host,
      content: "Second message",
      created_at: 2.hours.ago
    )

    message1 = OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "First message",
      created_at: 3.hours.ago
    )

    message3 = OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "Third message",
      created_at: 1.hour.ago
    )

    ordered_messages = @offer.messages.order(:created_at)
    assert_equal [message1, message2, message3], ordered_messages
  end
end
