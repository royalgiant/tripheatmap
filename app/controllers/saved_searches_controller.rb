class SavedSearchesController < ApplicationController
  before_action :check_user_authentication, only: [:new]
  before_action :authenticate_user!, only: [:create, :index, :destroy]
  before_action :set_saved_search, only: [:destroy]

  # GET /saved_searches (Dashboard)
  def index
    @saved_searches = current_user.saved_searches.order(created_at: :desc)
  end

  # GET /saved_searches/new (Modal trigger - Turboframe)
  def new
    @saved_search = current_user.saved_searches.build(search_params_from_url)
    render :new, status: :ok
  end

  # POST /saved_searches
  def create
    @saved_search = current_user.saved_searches.build(saved_search_params)
    @saved_search.original_url = request.referer

    if @saved_search.save
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.update("save_search_modal", "")
        }
        format.html { redirect_back fallback_location: root_path, notice: 'Search saved successfully!' }
      end
    else
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.update("save_search_modal", "")
        }
        format.html { redirect_back fallback_location: root_path }
      end
    end
  end

  # DELETE /saved_searches/:id
  def destroy
    @saved_search.destroy

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.remove("saved_search_#{@saved_search.id}")
      }
      format.html { redirect_to saved_searches_path, notice: 'Saved search deleted.' }
    end
  end

  # PATCH /saved_searches/:id/pause
  def pause
    @saved_search = current_user.saved_searches.find(params[:id])
    new_status = @saved_search.status == 'active' ? 'paused' : 'active'

    if @saved_search.update(status: new_status)
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("saved_search_#{@saved_search.id}",
                                                     partial: "saved_searches/search_row",
                                                     locals: { saved_search: @saved_search })
        }
        format.html { redirect_to saved_searches_path, notice: "Search #{new_status}." }
      end
    end
  end

  private

  def check_user_authentication
    unless user_signed_in?
      cookies[:pending_saved_search] = {
        value: search_params_from_url.to_json,
        expires: 24.hours.from_now
      }

      store_location_for(:user, request.referer || root_path)
      redirect_to new_user_session_path
    end
  end

  def set_saved_search
    @saved_search = current_user.saved_searches.find(params[:id])
  end

  def search_params_from_url
    max_price_dollars = params[:max_price]&.to_f
    max_price_cents = max_price_dollars ? (max_price_dollars * 100).to_i : nil

    location = params[:location] || extract_location_from_referer
    location = location&.downcase
    {
      location: location,
      max_price_cents: max_price_cents,
      min_rating: params[:rating]&.to_f,
      price_range: params[:price],
      neighborhood: params[:neighborhood].is_a?(Array) ? params[:neighborhood].first : params[:neighborhood],
      filters: {
        neighborhood_slugs: Array(params[:neighborhood])
      }.compact_blank
    }.compact_blank
  end

  def saved_search_params
    permitted = params.require(:saved_search).permit(
      :location,
      :max_price_cents,
      :min_rating,
      :price_range,
      :neighborhood,
      :checkin_date,
      :checkout_date,
      :original_url,
      filters: {}
    )
    permitted[:location] = permitted[:location]&.downcase if permitted[:location].present?

    permitted
  end

  def extract_location_from_referer
    return nil unless request.referer

    uri = URI.parse(request.referer)
    parts = uri.path.split('/').reject(&:empty?)

    return parts[2] if parts[0].in?(['best', 'hotels-near']) && parts.length >= 3
    nil
  rescue
    nil
  end
end
