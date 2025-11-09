class MapsController < ApplicationController
  def index
    @mapbox_token = Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)
  end

  def city
    @city = params[:city]
    @posts = RedditPost.analyzed
      .where(city: @city)
      .where.not(lat: nil, lon: nil)
      .order(created_at: :desc)
    @mapbox_token = Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)
  end

  def places
    # Normalize city name to lowercase for consistent querying
    city_param = (params[:city] || 'dallas').downcase.gsub('-', ' ')
    @city = CityDataImporter::CITY_NAMES[city_param] || city_param
    @city_display = CityDataImporter::DISPLAY_NAMES[@city] || @city.titleize
    @mapbox_token = Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)

    @neighborhoods = Neighborhood.for_city(@city)
    @total_amenities = NeighborhoodPlacesStat.joins(:neighborhood)
      .where(neighborhoods: { city: @city })
      .sum(:total_amenities)
  end
end
