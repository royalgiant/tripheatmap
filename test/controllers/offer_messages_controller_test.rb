require "test_helper"

class OfferMessagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @guest = FactoryBot.create(:user)
    @host = FactoryBot.create(:user, has_lifetime_access: true)

    @neighborhood = Neighborhood.create!(
      name: "Test Neighborhood",
      slug: "test-neighborhood",
      city: "Chicago",
      state: "IL",
      latitude: 41.8781,
      longitude: -87.6298
    )

    @place = Place.create!(
      name: "Test Property",
      place_type: "airbnb",
      city: "Chicago",
      average_price: 200,
      rating: 4.7,
      latitude: 41.8781,
      longitude: -87.6298,
      neighborhood: @neighborhood,
      user: @host
    )

    @saved_search = SavedSearch.create!(
      user: @guest,
      location: "Chicago",
      max_price_cents: 25000,
      status: 'active'
    )

    @offer = Offer.create!(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: 20000,
      expires_at: 48.hours.from_now,
      status: 'sent'
    )
  end

  # ========== CREATE ==========
  test "guest can send message to host" do
    sign_in @guest

    assert_difference('OfferMessage.count', 1) do
      post offer_messages_path(@offer), params: {
        offer_message: {
          content: "What time is check-in?"
        }
      }
    end

    assert_redirected_to offer_path(@offer)

    message = OfferMessage.last
    assert_equal "What time is check-in?", message.content
    assert_equal @guest, message.sender
    assert_equal @offer, message.offer
  end

  test "host cannot send first message" do
    sign_in @host

    assert_no_difference('OfferMessage.count') do
      post offer_messages_path(@offer), params: {
        offer_message: {
          content: "Check-in is at 3 PM"
        }
      }
    end

    assert_redirected_to offer_path(@offer)
    assert_equal "Guest must send the first message.", flash[:alert]
  end

  test "host can reply after guest sends first message" do
    # Guest sends first message
    OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "What time is check-in?"
    )

    sign_in @host

    assert_difference('OfferMessage.count', 1) do
      post offer_messages_path(@offer), params: {
        offer_message: {
          content: "Check-in is at 3 PM"
        }
      }
    end

    assert_redirected_to offer_path(@offer)

    message = OfferMessage.last
    assert_equal "Check-in is at 3 PM", message.content
    assert_equal @host, message.sender
    assert_equal @offer, message.offer
  end

  test "unauthorized user cannot send message" do
    other_user = FactoryBot.create(:user)
    sign_in other_user

    assert_no_difference('OfferMessage.count') do
      post offer_messages_path(@offer), params: {
        offer_message: {
          content: "Unauthorized message"
        }
      }
    end

    assert_redirected_to root_path
  end

  test "message requires content" do
    sign_in @guest

    assert_no_difference('OfferMessage.count') do
      post offer_messages_path(@offer), params: {
        offer_message: {
          content: ""
        }
      }
    end

    # Should redirect back with error
    assert_redirected_to offer_path(@offer)
  end

  test "message content cannot exceed 2000 characters" do
    sign_in @guest
    long_content = "a" * 2001

    assert_no_difference('OfferMessage.count') do
      post offer_messages_path(@offer), params: {
        offer_message: {
          content: long_content
        }
      }
    end

    assert_redirected_to offer_path(@offer)
  end

  test "guest can view messages on offer page" do
    # Create some messages (guest must message first)
    OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "Thank you! What time is check-in?",
      created_at: 2.hours.ago
    )
    OfferMessage.create!(
      offer: @offer,
      sender: @host,
      content: "Welcome! Check-in is at 3 PM.",
      created_at: 1.hour.ago
    )

    sign_in @guest
    get offer_path(@offer)

    assert_response :success
    assert_select ".max-w-lg", count: 2 # Should show 2 message bubbles
  end

  test "host can view messages on offer page" do
    # Create a message
    OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "What time is check-in?",
      created_at: 1.hour.ago
    )

    sign_in @host
    get offer_path(@offer)

    assert_response :success
    assert_select "h2", text: /Messages/i
  end

  test "messages are displayed in chronological order" do
    # Create messages out of order (guest must message first)
    msg1 = OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "First message",
      created_at: 5.hours.ago
    )
    msg2 = OfferMessage.create!(
      offer: @offer,
      sender: @host,
      content: "Second message",
      created_at: 4.hours.ago
    )
    msg3 = OfferMessage.create!(
      offer: @offer,
      sender: @host,
      content: "Third message",
      created_at: 3.hours.ago
    )

    sign_in @guest
    get offer_path(@offer)

    assert_response :success
    # Messages should be loaded in ascending order (oldest first)
    assert_equal [msg1, msg2, msg3], assigns(:messages)
  end

  test "sending message triggers email notification" do
    sign_in @guest

    assert_enqueued_emails 1 do
      post offer_messages_path(@offer), params: {
        offer_message: {
          content: "What time is check-in?"
        }
      }
    end
  end

  # ========== EMAIL PREFERENCE TESTS ==========

  test "does not send email when recipient has disabled all emails" do
    @host.email_preference.update!(receive_any_emails: false)

    sign_in @guest

    assert_enqueued_emails 0 do
      post offer_messages_path(@offer), params: {
        offer_message: {
          content: "What time is check-in?"
        }
      }
    end
  end

  test "does not send email when recipient has disabled message emails" do
    @host.email_preference.update!(receive_message_emails: false)

    sign_in @guest

    assert_enqueued_emails 0 do
      post offer_messages_path(@offer), params: {
        offer_message: {
          content: "What time is check-in?"
        }
      }
    end
  end

  test "sends email when recipient has message emails enabled" do
    @host.email_preference.update!(receive_any_emails: true, receive_message_emails: true)

    sign_in @guest

    assert_enqueued_emails 1 do
      post offer_messages_path(@offer), params: {
        offer_message: {
          content: "What time is check-in?"
        }
      }
    end
  end

  test "respects guest email preferences when host replies" do
    OfferMessage.create!(
      offer: @offer,
      sender: @guest,
      content: "What time is check-in?"
    )

    @guest.email_preference.update!(receive_message_emails: false)

    sign_in @host

    assert_enqueued_emails 0 do
      post offer_messages_path(@offer), params: {
        offer_message: {
          content: "Check-in is at 3 PM"
        }
      }
    end
  end
end
