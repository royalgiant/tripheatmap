class DailyLeadAndOfferDigestJob < ApplicationJob
  queue_as :default

  def perform
    # This job runs daily at 9 PM
    # 1. Notify hosts of new matching saved searches
    # 2. Notify guests of new offers they received

    notify_hosts_of_new_leads
    notify_guests_of_new_offers
  end

  private

  def notify_hosts_of_new_leads
    # Find all saved searches created in the last 24 hours
    new_searches = SavedSearch
      .where(status: 'active')
      .where('created_at >= ?', 24.hours.ago)

    return if new_searches.empty?

    # Group hosts by their matching searches
    hosts_to_notify = {}

    new_searches.find_each do |search|
      # Find places that match this search
      matching_places = find_matching_places(search)

      matching_places.each do |place|
        next unless place.user.present? # Only notify places with owners
        next unless place.user.has_recurring_subscription? # Only recurring subscribers

        hosts_to_notify[place.user] ||= []
        hosts_to_notify[place.user] << search
      end
    end

    # Send one digest email per host with all their new leads
    hosts_to_notify.each do |host, searches|
      NewLeadAvailableMailer.daily_digest(host, searches).deliver_later
    end

    Rails.logger.info "[DailyLeadDigest] Notified #{hosts_to_notify.keys.count} hosts of #{new_searches.count} new searches"
  end

  def notify_guests_of_new_offers
    # Find all offers created in the last 24 hours
    new_offers = Offer
      .where('created_at >= ?', 24.hours.ago)
      .where(status: ['sent', 'viewed'])
      .includes(:saved_search, :place)

    return if new_offers.empty?

    # Group offers by guest user
    guests_to_notify = {}

    new_offers.each do |offer|
      guest = offer.guest_user
      guests_to_notify[guest] ||= []
      guests_to_notify[guest] << offer
    end

    # Send one digest email per guest with all their new offers
    guests_to_notify.each do |guest, offers|
      NewOfferReceivedMailer.daily_digest(guest, offers).deliver_later
    end

    Rails.logger.info "[DailyOfferDigest] Notified #{guests_to_notify.keys.count} guests of #{new_offers.count} new offers"
  end

  def find_matching_places(search)
    places = Place.where.not(user_id: nil)

    # Match by location
    if search.location.present?
      places = places.joins(:neighborhood).where('neighborhoods.city ILIKE ?', "%#{search.location}%")
    end

    # Match by neighborhood if specified
    if search.neighborhood.present?
      neighborhood_ids = search.neighborhood.is_a?(Array) ? search.neighborhood : JSON.parse(search.neighborhood)
      places = places.where(neighborhood_id: neighborhood_ids)
    end

    # Match by price
    if search.max_price_cents.present?
      places = places.where('average_price <= ?', search.max_price_cents / 100.0)
    end

    # Match by rating
    if search.min_rating.present?
      places = places.where('rating >= ?', search.min_rating)
    end

    # Match by guest count (if search specifies it)
    if search.number_of_guests.present?
      # TODO: Add max_guests column to places table
      # places = places.where('max_guests >= ?', search.number_of_guests)
    end

    places
  end
end
