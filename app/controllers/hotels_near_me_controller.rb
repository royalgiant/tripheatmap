class HotelsNearMeController < ApplicationController
  include CityContext
  before_action :set_location, only: [:index]
  before_action :set_city, only: [:show]
  before_action :set_all_cities
  before_action :set_hotels
  before_action :set_other_cities

  def index
    unless @latitude && @longitude && @city_display_name
      @hotels = []
      @city_display_name = "your area"
    end
  end

  def show
  end

  private

  def set_location
    if params[:latitude].present? && params[:longitude].present?
      @latitude = params[:latitude].to_f
      @longitude = params[:longitude].to_f

      nearby_neighborhood = Neighborhood.near([@latitude, @longitude], 50, order: :distance).first
      
      if nearby_neighborhood
        @city_display_name = nearby_neighborhood.city
      else
        nearby_place = Place.near([@latitude, @longitude], 50, order: :distance).first
        @city_display_name = nearby_place&.neighborhood&.city || "your location"
      end
    else
      ip = request.remote_ip
      result = Geocoder.search(ip).first

      if result
        @latitude = result.latitude
        @longitude = result.longitude
        @city_display_name = result.city
      end
    end
  rescue => e
    Rails.logger.error "Geocoding failed: #{e.message}"
    @latitude = nil
    @longitude = nil
  end

  def set_city
    @city_display_name = params[:city]&.titleize

    unless Neighborhood.exists?(city: @city_display_name.downcase)
      redirect_to hotels_near_me_index_path, alert: "City not found"
    end
  end

  def set_all_cities
    @all_cities = Neighborhood.where.not(city: nil)
                              .distinct
                              .order(:city)
                              .pluck(:city)
  end

  def set_hotels
    return unless @city_display_name

    base_query = Place.hotels
                      .joins(:neighborhood)
                      .where(neighborhoods: { city: @city_display_name.downcase })
                      .includes(:neighborhood)

    if params[:latitude].present? && params[:longitude].present? && @latitude && @longitude
      @hotels = base_query.near([@latitude, @longitude], 10, order: :distance).limit(50)
    else
      @hotels = base_query.limit(50)
    end
    if current_user
      @favorites_by_place_id = current_user.favorites.pluck(:place_id, :id).to_h
    else
      @favorites_by_place_id = {}
    end
  end

  def set_other_cities
    if @city_display_name && @city_display_name != "your area"
      @other_cities = Neighborhood.where.not(city: @city_display_name.downcase)
                                  .distinct
                                  .pluck(:city)
                                  .shuffle
                                  .take(20)
    else
      @other_cities = Neighborhood.distinct
                                  .pluck(:city)
                                  .shuffle
                                  .take(20)
    end
  end
end
