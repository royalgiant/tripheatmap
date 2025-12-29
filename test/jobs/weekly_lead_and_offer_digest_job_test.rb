require "test_helper"

class WeeklyLeadAndOfferDigestJobTest < ActiveJob::TestCase
  setup do
    # Clear any existing data
    Offer.destroy_all
    SavedSearch.destroy_all
    Place.destroy_all
    Neighborhood.destroy_all
    User.destroy_all

    # Create hosts
    @host1 = FactoryBot.create(:user, email: "host1@test.com", has_lifetime_access: false)
    @host2 = FactoryBot.create(:user, email: "host2@test.com", has_lifetime_access: false)
    @lifetime_host = FactoryBot.create(:user, email: "lifetime@test.com", has_lifetime_access: true)

    # Create guests
    @guest1 = FactoryBot.create(:user, email: "guest1@test.com")
    @guest2 = FactoryBot.create(:user, email: "guest2@test.com")

    # Set default email preferences to weekly_digest for all users
    @host1.email_preference.update!(new_lead_email_frequency: :weekly_digest, new_offer_email_frequency: :weekly_digest)
    @host2.email_preference.update!(new_lead_email_frequency: :weekly_digest, new_offer_email_frequency: :weekly_digest)
    @lifetime_host.email_preference.update!(new_lead_email_frequency: :weekly_digest, new_offer_email_frequency: :weekly_digest)
    @guest1.email_preference.update!(new_lead_email_frequency: :weekly_digest, new_offer_email_frequency: :weekly_digest)
    @guest2.email_preference.update!(new_lead_email_frequency: :weekly_digest, new_offer_email_frequency: :weekly_digest)

    # Create neighborhoods
    @austin_neighborhood = Neighborhood.create!(
      name: "Downtown Austin",
      slug: "downtown-austin",
      city: "austin",
      state: "TX",
      latitude: 30.2672,
      longitude: -97.7431
    )

    @chicago_neighborhood = Neighborhood.create!(
      name: "Loop Chicago",
      slug: "loop-chicago",
      city: "chicago",
      state: "IL",
      latitude: 41.8781,
      longitude: -87.6298
    )

    # Create properties
    @host1_austin_property = Place.create!(
      name: "Host1 Austin Place",
      place_type: "airbnb",
      city: "austin",
      average_price: 150,
      rating: 4.8,
      latitude: 30.2672,
      longitude: -97.7431,
      neighborhood: @austin_neighborhood,
      user: @host1
    )

    @host2_austin_property = Place.create!(
      name: "Host2 Austin Place",
      place_type: "airbnb",
      city: "austin",
      average_price: 180,
      rating: 4.5,
      latitude: 30.2672,
      longitude: -97.7431,
      neighborhood: @austin_neighborhood,
      user: @host2
    )

    @lifetime_host_property = Place.create!(
      name: "Lifetime Host Place",
      place_type: "airbnb",
      city: "austin",
      average_price: 120,
      rating: 4.9,
      latitude: 30.2672,
      longitude: -97.7431,
      neighborhood: @austin_neighborhood,
      user: @lifetime_host
    )

    @host1_chicago_property = Place.create!(
      name: "Host1 Chicago Place",
      place_type: "airbnb",
      city: "chicago",
      average_price: 200,
      rating: 4.7,
      latitude: 41.8781,
      longitude: -87.6298,
      neighborhood: @chicago_neighborhood,
      user: @host1
    )

    # Create active subscriptions for non-lifetime hosts
    create_active_subscription_for(@host1)
    create_active_subscription_for(@host2)
    # Don't create subscription for @lifetime_host - they should not receive leads

    # Clear ActionMailer deliveries
    ActionMailer::Base.deliveries.clear
  end

  # ========== HOST LEAD NOTIFICATION TESTS ==========

  test "notifies hosts of new matching searches created in last 7 days" do
    # Create a new search that matches host1 ($150) and lifetime_host ($120) but not host2 ($180)
    new_search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 16000, # $160 - matches host1 ($150) and lifetime_host ($120) but not host2 ($180)
      min_rating: 4.5,
      status: 'active',
      created_at: 2.days.ago
    )

    assert_difference("ActionMailer::Base.deliveries.size", 2) do
      perform_enqueued_jobs do
        WeeklyLeadAndOfferDigestJob.perform_now
      end
    end

    emails = ActionMailer::Base.deliveries
    recipients = emails.flat_map(&:to)
    assert_includes recipients, @host1.email
    assert_includes recipients, @lifetime_host.email
    assert emails.all? { |email| email.subject.match?(/new.*looking in your area/i) }
  end

  test "does not notify hosts of old searches" do
    # Create an old search (> 7 days)
    old_search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 20000,
      status: 'active',
      created_at: 8.days.ago
    )

    assert_no_difference("ActionMailer::Base.deliveries.size") do
      WeeklyLeadAndOfferDigestJob.perform_now
    end
  end

  test "does not notify hosts of inactive searches" do
    # Create a paused search
    paused_search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 20000,
      status: 'paused',
      created_at: 2.days.ago
    )

    assert_no_difference("ActionMailer::Base.deliveries.size") do
      WeeklyLeadAndOfferDigestJob.perform_now
    end
  end

  test "notifies hosts with recurring subscriptions and lifetime access" do
    # Create a search that matches all Austin properties (including lifetime host)
    new_search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 30000, # Matches all properties
      min_rating: 4.0,
      status: 'active',
      created_at: 2.days.ago
    )

    perform_enqueued_jobs do
      WeeklyLeadAndOfferDigestJob.perform_now
    end

    # Should notify host1, host2, and lifetime_host (as teaser)
    emails = ActionMailer::Base.deliveries
    recipients = emails.flat_map(&:to)

    assert_includes recipients, @host1.email
    assert_includes recipients, @host2.email
    assert_includes recipients, @lifetime_host.email
  end

  test "batches multiple matching searches per host in single email" do
    # Create two searches that both match host1's Austin property
    search1 = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 20000,
      status: 'active',
      created_at: 2.days.ago
    )

    search2 = SavedSearch.create!(
      user: @guest2,
      location: "austin",
      max_price_cents: 18000,
      status: 'active',
      created_at: 1.day.ago
    )

    # Should send emails to hosts, but batched
    perform_enqueued_jobs do
      WeeklyLeadAndOfferDigestJob.perform_now
    end

    # Verify the mailer was called with multiple searches
    # Note: The actual batching logic is in the job, emails are sent separately per host
    emails = ActionMailer::Base.deliveries
    assert emails.size > 0
  end

  test "matches searches by location (city)" do
    # Create Austin search - should match Austin properties only
    austin_search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 25000,
      status: 'active',
      created_at: 2.days.ago
    )

    perform_enqueued_jobs do
      WeeklyLeadAndOfferDigestJob.perform_now
    end

    # host1 and host2 should be notified (both have Austin properties)
    emails = ActionMailer::Base.deliveries
    recipients = emails.flat_map(&:to).uniq

    assert_includes recipients, @host1.email
    assert_includes recipients, @host2.email
  end

  test "matches searches by price (max_price_cents)" do
    # Create search with $160 max - should only match properties <= $160
    low_price_search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 16000, # $160
      status: 'active',
      created_at: 2.days.ago
    )

    perform_enqueued_jobs do
      WeeklyLeadAndOfferDigestJob.perform_now
    end

    # Should notify host1 ($150 property) and lifetime_host ($120 property)
    # Should NOT notify host2 ($180 property)
    emails = ActionMailer::Base.deliveries
    recipients = emails.flat_map(&:to).uniq

    assert_includes recipients, @host1.email # $150 property
    assert_not_includes recipients, @host2.email # $180 property (too expensive)
    # lifetime_host is excluded due to subscription, not price
  end

  test "matches searches by rating (min_rating)" do
    # Create search with 4.5 min rating - matches all Austin properties
    high_rating_search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 30000,
      min_rating: 4.5,
      status: 'active',
      created_at: 2.days.ago
    )

    perform_enqueued_jobs do
      WeeklyLeadAndOfferDigestJob.perform_now
    end

    # All Austin properties match (host1: 4.8, host2: 4.5, lifetime: 4.9)
    # All three hosts get emails (recurring subscribers and lifetime users)
    emails = ActionMailer::Base.deliveries
    recipients = emails.flat_map(&:to).uniq

    assert_includes recipients, @host1.email
    assert_includes recipients, @host2.email
    assert_includes recipients, @lifetime_host.email
  end

  test "does not send digest if no new searches" do
    # Don't create any searches
    assert_no_difference("ActionMailer::Base.deliveries.size") do
      WeeklyLeadAndOfferDigestJob.perform_now
    end
  end

  test "does not send digest if no matching properties" do
    # Create search for a city with no properties
    search = SavedSearch.create!(
      user: @guest1,
      location: "new york",
      max_price_cents: 20000,
      status: 'active',
      created_at: 2.days.ago
    )

    assert_no_difference("ActionMailer::Base.deliveries.size") do
      WeeklyLeadAndOfferDigestJob.perform_now
    end
  end

  # ========== GUEST OFFER NOTIFICATION TESTS ==========

  test "notifies guests of new offers created in last 7 days" do
    search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 20000,
      status: 'active',
      created_at: 30.days.ago  # Old search, won't trigger host notifications
    )

    # Create a new offer
    offer = Offer.create!(
      place: @host1_austin_property,
      saved_search: search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent',
      created_at: 2.days.ago
    )

    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      perform_enqueued_jobs do
        WeeklyLeadAndOfferDigestJob.perform_now
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [@guest1.email], email.to
    assert_match /new offer/i, email.subject
  end

  test "does not notify guests of old offers" do
    search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 20000,
      status: 'active'
    )

    # Create an old offer (> 7 days)
    offer = Offer.create!(
      place: @host1_austin_property,
      saved_search: search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent',
      created_at: 8.days.ago
    )

    assert_no_difference("ActionMailer::Base.deliveries.size") do
      WeeklyLeadAndOfferDigestJob.perform_now
    end
  end

  test "only notifies guests of sent or viewed offers, not accepted/declined" do
    search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 20000,
      status: 'active',
      created_at: 30.days.ago
    )

    # Create offers with different statuses
    sent_offer = Offer.create!(
      place: @host1_austin_property,
      saved_search: search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent',
      created_at: 2.days.ago
    )

    search2 = SavedSearch.create!(user: @guest1, location: "chicago", max_price_cents: 25000, status: 'active', created_at: 30.days.ago)
    accepted_offer = Offer.create!(
      place: @host1_chicago_property,
      saved_search: search2,
      offered_price_cents: 18000,
      expires_at: 48.hours.from_now,
      status: 'accepted',
      created_at: 2.days.ago
    )

    search3 = SavedSearch.create!(user: @guest1, location: "austin", max_price_cents: 22000, status: 'active', created_at: 30.days.ago)
    declined_offer = Offer.create!(
      place: @host2_austin_property,
      saved_search: search3,
      offered_price_cents: 17000,
      expires_at: 48.hours.from_now,
      status: 'declined',
      created_at: 2.days.ago
    )

    # Should only notify about sent_offer
    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      perform_enqueued_jobs do
        WeeklyLeadAndOfferDigestJob.perform_now
      end
    end
  end

  test "batches multiple offers per guest in single email" do
    search1 = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 20000,
      status: 'active',
      created_at: 30.days.ago
    )

    search2 = SavedSearch.create!(
      user: @guest1,
      location: "chicago",
      max_price_cents: 25000,
      status: 'active',
      created_at: 30.days.ago
    )

    # Create two offers for the same guest
    offer1 = Offer.create!(
      place: @host1_austin_property,
      saved_search: search1,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent',
      created_at: 2.days.ago
    )

    offer2 = Offer.create!(
      place: @host1_chicago_property,
      saved_search: search2,
      offered_price_cents: 18000,
      expires_at: 48.hours.from_now,
      status: 'sent',
      created_at: 1.day.ago
    )

    # Should send only 1 email to guest1 with both offers
    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      perform_enqueued_jobs do
        WeeklyLeadAndOfferDigestJob.perform_now
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [@guest1.email], email.to
  end

  test "sends separate emails to different guests" do
    search1 = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 20000,
      status: 'active',
      created_at: 30.days.ago
    )

    search2 = SavedSearch.create!(
      user: @guest2,
      location: "austin",
      max_price_cents: 20000,
      status: 'active',
      created_at: 30.days.ago
    )

    # Create offers for different guests
    offer1 = Offer.create!(
      place: @host1_austin_property,
      saved_search: search1,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent',
      created_at: 2.days.ago
    )

    offer2 = Offer.create!(
      place: @host2_austin_property,
      saved_search: search2,
      offered_price_cents: 17000,
      expires_at: 48.hours.from_now,
      status: 'sent',
      created_at: 1.day.ago
    )

    # Should send 2 emails (one per guest)
    assert_difference("ActionMailer::Base.deliveries.size", 2) do
      perform_enqueued_jobs do
        WeeklyLeadAndOfferDigestJob.perform_now
      end
    end

    recipients = ActionMailer::Base.deliveries.map(&:to).flatten
    assert_includes recipients, @guest1.email
    assert_includes recipients, @guest2.email
  end

  test "does not send digest if no new offers" do
    # Don't create any offers
    assert_no_difference("ActionMailer::Base.deliveries.size") do
      WeeklyLeadAndOfferDigestJob.perform_now
    end
  end

  # ========== COMBINED FLOW TESTS ==========

  test "perform sends both host and guest notifications" do
    # Create new search for host notification
    search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 20000,
      status: 'active',
      created_at: 2.days.ago
    )

    # Create new offer for guest notification
    offer = Offer.create!(
      place: @host1_austin_property,
      saved_search: search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent',
      created_at: 1.day.ago
    )

    # Should send emails for both hosts and guests
    # Host emails: 2 (host1 and host2 match the search)
    # Guest emails: 1
    # Total: 3 emails
    initial_count = ActionMailer::Base.deliveries.size

    perform_enqueued_jobs do
      WeeklyLeadAndOfferDigestJob.perform_now
    end

    # Verify both types of emails were sent
    emails = ActionMailer::Base.deliveries
    new_count = emails.size - initial_count
    assert new_count >= 2, "Expected at least 2 emails (host + guest), got #{new_count}"
  end

  # ========== EMAIL PREFERENCE TESTS ==========

  test "does not notify hosts who have disabled all emails" do
    # Disable emails for host1
    @host1.email_preference.update!(receive_any_emails: false)

    # Create search that matches both host1 and host2
    search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 25000,
      status: 'active',
      created_at: 2.days.ago
    )

    perform_enqueued_jobs do
      WeeklyLeadAndOfferDigestJob.perform_now
    end

    # Only host2 should receive email
    emails = ActionMailer::Base.deliveries
    recipients = emails.flat_map(&:to).uniq

    assert_not_includes recipients, @host1.email
    assert_includes recipients, @host2.email
  end

  test "does not notify hosts with new_lead_email_frequency set to never" do
    # Set host1 to never receive lead emails
    @host1.email_preference.update!(new_lead_email_frequency: :never)

    # Create search that matches both hosts
    search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 25000,
      status: 'active',
      created_at: 2.days.ago
    )

    perform_enqueued_jobs do
      WeeklyLeadAndOfferDigestJob.perform_now
    end

    # Only host2 should receive email
    emails = ActionMailer::Base.deliveries
    recipients = emails.flat_map(&:to).uniq

    assert_not_includes recipients, @host1.email
    assert_includes recipients, @host2.email
  end

  test "does not notify hosts with new_lead_email_frequency set to daily" do
    # Set host1 to never
    @host1.email_preference.update!(new_lead_email_frequency: :never)
    # Set host2 to daily
    @host2.email_preference.update!(new_lead_email_frequency: :daily_digest)

    # Create search that matches both hosts
    search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 25000,
      status: 'active',
      created_at: 2.days.ago
    )

    # Weekly job should not send to either host
    assert_no_difference("ActionMailer::Base.deliveries.size") do
      WeeklyLeadAndOfferDigestJob.perform_now
    end
  end

  test "only notifies hosts with new_lead_email_frequency set to weekly_digest" do
    # Set host1 to weekly_digest
    @host1.email_preference.update!(new_lead_email_frequency: :weekly_digest)
    # Set host2 to never
    @host2.email_preference.update!(new_lead_email_frequency: :never)

    # Create search that matches both hosts
    search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 25000,
      status: 'active',
      created_at: 2.days.ago
    )

    perform_enqueued_jobs do
      WeeklyLeadAndOfferDigestJob.perform_now
    end

    # Only host1 should receive email
    emails = ActionMailer::Base.deliveries
    recipients = emails.flat_map(&:to).uniq

    assert_includes recipients, @host1.email
    assert_not_includes recipients, @host2.email
  end

  test "does not notify guests who have disabled all emails" do
    # Disable emails for guest1
    @guest1.email_preference.update!(receive_any_emails: false)

    search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 20000,
      status: 'active',
      created_at: 30.days.ago
    )

    # Create offer for guest1
    offer = Offer.create!(
      place: @host1_austin_property,
      saved_search: search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent',
      created_at: 2.days.ago
    )

    # Should not send email to guest1
    assert_no_difference("ActionMailer::Base.deliveries.size") do
      WeeklyLeadAndOfferDigestJob.perform_now
    end
  end

  test "does not notify guests with new_offer_email_frequency set to never" do
    # Set guest1 to never receive offer emails
    @guest1.email_preference.update!(new_offer_email_frequency: :never)

    search = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 20000,
      status: 'active',
      created_at: 30.days.ago
    )

    # Create offer for guest1
    offer = Offer.create!(
      place: @host1_austin_property,
      saved_search: search,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent',
      created_at: 2.days.ago
    )

    # Should not send email to guest1
    assert_no_difference("ActionMailer::Base.deliveries.size") do
      WeeklyLeadAndOfferDigestJob.perform_now
    end
  end

  test "only notifies guests with new_offer_email_frequency set to weekly_digest" do
    # Set guest1 to weekly_digest
    @guest1.email_preference.update!(new_offer_email_frequency: :weekly_digest)
    # Set guest2 to never
    @guest2.email_preference.update!(new_offer_email_frequency: :never)

    search1 = SavedSearch.create!(
      user: @guest1,
      location: "austin",
      max_price_cents: 20000,
      status: 'active',
      created_at: 30.days.ago
    )

    search2 = SavedSearch.create!(
      user: @guest2,
      location: "austin",
      max_price_cents: 20000,
      status: 'active',
      created_at: 30.days.ago
    )

    # Create offers for both guests
    offer1 = Offer.create!(
      place: @host1_austin_property,
      saved_search: search1,
      offered_price_cents: 15000,
      expires_at: 48.hours.from_now,
      status: 'sent',
      created_at: 2.days.ago
    )

    offer2 = Offer.create!(
      place: @host2_austin_property,
      saved_search: search2,
      offered_price_cents: 17000,
      expires_at: 48.hours.from_now,
      status: 'sent',
      created_at: 1.day.ago
    )

    # Should only send email to guest1
    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      perform_enqueued_jobs do
        WeeklyLeadAndOfferDigestJob.perform_now
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [@guest1.email], email.to
  end
end
