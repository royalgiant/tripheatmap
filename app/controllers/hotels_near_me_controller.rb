class HotelsNearMeController < ApplicationController
  include CityContext
  before_action :set_location, only: [:index]
  before_action :set_city, only: [:show]

  def index
    if @latitude && @longitude && @city_display_name
      @hotels = Place.hotels
                     .joins(:neighborhood)
                     .where(neighborhoods: { city: @city_display_name.downcase })
                     .includes(:neighborhood)
                     .limit(50)

      @other_cities = Neighborhood.where.not(city: @city_display_name.downcase)
                                  .distinct
                                  .pluck(:city)
                                  .shuffle
                                  .take(20)
    else
      @hotels = []
      @city_display_name = "your area"
      @other_cities = Neighborhood.distinct
                                  .pluck(:city)
                                  .shuffle
                                  .take(20)
    end
  end

  def show
    @hotels = Place.hotels
                   .joins(:neighborhood)
                   .where(neighborhoods: { city: @city_display_name.downcase })
                   .includes(:neighborhood)
                   .limit(50)

    @other_cities = Neighborhood.where.not(city: @city_display_name.downcase)
                                .distinct
                                .pluck(:city)
                                .shuffle
                                .take(20)
  end

  private

  def set_location
    ip = request.remote_ip

    result = Geocoder.search(ip).first

    if result
      @latitude = result.latitude
      @longitude = result.longitude
      @city_display_name = result.city
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
end
