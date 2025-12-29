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
    @messages = @offer.messages.includes(:sender).order(created_at: :asc)
    @new_message = OfferMessage.new
    @can_message = current_user == @offer.guest_user || @messages.any?
  end

  # GET /offers/new?saved_search_id=123
  # Host: Send offer form
  def new
    @saved_search = SavedSearch.find(params[:saved_search_id])

    @my_places = current_user.places
                             .where.not(user_id: nil)
                             .where('city ILIKE ?', "%#{@saved_search.location}%")
    @place = @my_places.first

    existing_offer = Offer.joins(:place)
                          .where(places: { user_id: current_user.id })
                          .find_by(saved_search: @saved_search)
    if existing_offer
      redirect_to offer_path(existing_offer), alert: "You already sent an offer for this search. Delete it first to send a new one."
      return
    end

    @offer = Offer.new(
      saved_search: @saved_search,
      expires_at: 3.days.from_now
    )
  end

  # POST /offers
  # Host: Create new offer
  def create
    @saved_search = SavedSearch.find(params[:offer][:saved_search_id])
    @place = current_user.places.find(params[:offer][:place_id])

    @my_places = current_user.places
                             .where.not(user_id: nil)
                             .where('city ILIKE ?', "%#{@saved_search.location}%")

    @offer = Offer.new(offer_params)
    @offer.place = @place
    @offer.saved_search = @saved_search

    if @offer.save
      redirect_to offers_path, notice: "Offer sent successfully! The guest will be notified."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # POST /offers/:id/accept
  # Guest: Accept an offer
  def accept
    authorize_guest_access!
    return if performed?

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

      guest_preference = @offer.guest_user.email_preference
      if guest_preference&.receive_any_emails
        OfferAcceptedGuestMailer.notify(@offer).deliver_later
      end

      host_preference = @offer.host_user.email_preference
      if host_preference&.receive_any_emails
        OfferAcceptedHostMailer.notify(@offer).deliver_later
      end
    end

    redirect_to offer_path(@offer), notice: "Offer accepted! Check your email for booking instructions."
  end

  # POST /offers/:id/decline
  # Guest: Decline an offer
  def decline
    authorize_guest_access!
    return if performed?

    @offer.update!(status: 'declined')
    redirect_to offers_path, notice: "Offer declined."
  end

  # DELETE /offers/:id
  # Host: Delete a sent offer
  def destroy
    authorize_host_access!
    return if performed?

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
    current_user.has_recurring_subscription?
  end

  def authorize_offer_access!
    unless @offer.guest_user == current_user || @offer.host_user == current_user
      redirect_to root_path, alert: "You don't have access to this offer." and return
    end
  end

  def authorize_guest_access!
    unless @offer.guest_user == current_user
      redirect_to root_path, alert: "Only the guest can perform this action." and return
    end
  end

  def authorize_host_access!
    unless @offer.host_user == current_user
      redirect_to root_path, alert: "Only the host can perform this action." and return
    end
  end

  def render_host_dashboard
    @my_places = current_user.places.where.not(user_id: nil)

    @leads = find_matching_saved_searches(@my_places)
    @leads_count = @leads.count
    @can_see_leads = can_see_lead_details?

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

    searches = SavedSearch.where(status: 'active', accept_offers: true).where.not(user_id: current_user.id)
    place_cities = places.map(&:city).compact.uniq

    if place_cities.any?
      searches = searches.where('location ILIKE ANY (ARRAY[?])', place_cities.map { |city| "%#{city}%" })
    end

    # Filter by price (saved search max_price >= place average_price)
    min_price = places.minimum(:average_price)
    searches = searches.where('max_price_cents >= ?', (min_price || 0) * 100)

    # Filter by rating (saved search min_rating <= place rating)
    max_rating = places.maximum(:rating)
    searches = searches.where('min_rating IS NULL OR min_rating <= ?', max_rating || 5.0)

    # Filter by number of guests (saved search number_of_guests <= place capacity)
    max_guests = places.maximum(:number_of_guests)
    if max_guests.present?
      searches = searches.where('number_of_guests IS NULL OR number_of_guests <= ?', max_guests)
    end

    searches.includes(:user, :offers)
  end
end
