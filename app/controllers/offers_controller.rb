class OffersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_offer, only: [:show, :accept, :decline, :destroy]
  before_action :check_subscription_access, only: [:new, :create]

  # GET /offers
  # Dual purpose: Shows host dashboard OR guest inbox depending on user type
  def index
    if is_host?
      render_host_dashboard
    else
      render_guest_inbox
    end
  end

  # GET /offers/:id
  # Show offer details (for both host and guest)
  def show
    authorize_offer_access!
    @offer.mark_viewed! if current_user == @offer.guest_user
  end

  # GET /offers/new?saved_search_id=123
  # Host: Send offer form
  def new
    @saved_search = SavedSearch.find(params[:saved_search_id])
    @place = current_user.places.where.not(user_id: nil).first

    # Check if offer already exists
    existing_offer = Offer.find_by(place: @place, saved_search: @saved_search)
    if existing_offer
      redirect_to offer_path(existing_offer), alert: "You already sent an offer for this search. Delete it first to send a new one."
      return
    end

    @offer = Offer.new(
      place: @place,
      saved_search: @saved_search,
      offered_price_cents: @place.average_price * 100,
      expires_at: 48.hours.from_now
    )
  end

  # POST /offers
  # Host: Create new offer
  def create
    @place = current_user.places.find(params[:offer][:place_id])
    @saved_search = SavedSearch.find(params[:offer][:saved_search_id])

    @offer = Offer.new(offer_params)
    @offer.place = @place
    @offer.saved_search = @saved_search

    if @offer.save
      # Notification will be sent via DailyLeadAndOfferDigestJob
      redirect_to offers_path, notice: "Offer sent successfully! The guest will be notified."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # POST /offers/:id/accept
  # Guest: Accept an offer
  def accept
    authorize_guest_access!

    ActiveRecord::Base.transaction do
      # Mark this offer as accepted
      @offer.update!(status: 'accepted', accepted_at: Time.current)

      # Decline all other offers for this saved search
      Offer.where(saved_search_id: @offer.saved_search_id)
           .where.not(id: @offer.id)
           .where(status: ['sent', 'viewed'])
           .update_all(status: 'declined')

      # Pause the saved search
      @offer.saved_search.update!(status: 'paused')

      # Send confirmation emails
      OfferAcceptedGuestMailer.notify(@offer).deliver_later
      OfferAcceptedHostMailer.notify(@offer).deliver_later
    end

    redirect_to offer_path(@offer), notice: "Offer accepted! Check your email for booking instructions."
  end

  # POST /offers/:id/decline
  # Guest: Decline an offer
  def decline
    authorize_guest_access!

    @offer.update!(status: 'declined')
    redirect_to offers_path, notice: "Offer declined."
  end

  # DELETE /offers/:id
  # Host: Delete a sent offer
  def destroy
    authorize_host_access!

    @offer.destroy
    redirect_to offers_path, notice: "Offer deleted. You can now send a new offer to this search."
  end

  private

  def set_offer
    @offer = Offer.find(params[:id])
  end

  def offer_params
    params.require(:offer).permit(
      :place_id,
      :saved_search_id,
      :offered_price_cents,
      :discount_type,
      :discount_value,
      :personal_message,
      :expires_at,
      perks: []
    )
  end

  def is_host?
    current_user.has_lifetime_access? || current_user.has_recurring_subscription?
  end

  def check_subscription_access
    # Allow access if user has any subscription (lifetime or recurring)
    unless current_user.has_lifetime_access? || current_user.has_recurring_subscription?
      redirect_to root_path, alert: "Please subscribe to access the lead marketplace."
    end
  end

  def can_see_lead_details?
    # Only recurring subscribers can see unblurred leads
    current_user.has_recurring_subscription?
  end

  def authorize_offer_access!
    unless @offer.guest_user == current_user || @offer.host_user == current_user
      redirect_to root_path, alert: "You don't have access to this offer."
    end
  end

  def authorize_guest_access!
    unless @offer.guest_user == current_user
      redirect_to root_path, alert: "Only the guest can perform this action."
    end
  end

  def authorize_host_access!
    unless @offer.host_user == current_user
      redirect_to root_path, alert: "Only the host can perform this action."
    end
  end

  def render_host_dashboard
    @my_places = current_user.places.where.not(user_id: nil)

    # Find matching saved searches
    if can_see_lead_details?
      @leads = find_matching_saved_searches(@my_places)
      @can_see_leads = true
    else
      # Lifetime users see blurred leads
      @leads_count = find_matching_saved_searches(@my_places).count
      @can_see_leads = false
    end

    # Sent offers
    @sent_offers = Offer.where(place: @my_places)
                        .includes(:saved_search, :place)
                        .order(created_at: :desc)

    # Messages
    @messages = OfferMessage.joins(:offer)
                           .where(offers: { place_id: @my_places.pluck(:id) })
                           .order(created_at: :desc)
                           .limit(20)

    render 'offers/host_dashboard'
  end

  def render_guest_inbox
    @saved_searches = current_user.saved_searches.includes(:offers)
    @offers = current_user.received_offers
                         .includes(:place, :saved_search)
                         .order(created_at: :desc)

    # Filter by status if provided
    if params[:status].present?
      case params[:status]
      when 'active'
        @offers = @offers.where(status: ['sent', 'viewed'])
      when 'expired'
        @offers = @offers.where(status: 'expired')
      when 'accepted'
        @offers = @offers.where(status: 'accepted')
      end
    end

    render 'offers/guest_inbox'
  end

  def find_matching_saved_searches(places)
    return SavedSearch.none if places.empty?

    # Get all active saved searches
    searches = SavedSearch.where(status: 'active')

    # Filter by location match
    place_cities = places.map { |p| p.neighborhood&.city }.compact.uniq

    if place_cities.any?
      searches = searches.where('location ILIKE ANY (ARRAY[?])', place_cities.map { |city| "%#{city}%" })
    end

    # Filter by price (saved search max_price >= place average_price)
    min_price = places.minimum(:average_price)
    searches = searches.where('max_price_cents >= ?', (min_price || 0) * 100)

    # Filter by rating (saved search min_rating <= place rating)
    max_rating = places.maximum(:rating)
    searches = searches.where('min_rating IS NULL OR min_rating <= ?', max_rating || 5.0)

    # Filter by number of guests if places have max_guests
    # TODO: Add max_guests to places table if needed

    searches.includes(:user, :offers)
  end
end
