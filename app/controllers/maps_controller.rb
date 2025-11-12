class MapsController < ApplicationController
  def index
    setup_city_data
    @mapbox_token = mapbox_token
  end

  def city
    @city = params[:city]
    @posts = RedditPost.analyzed
      .where(city: @city)
      .where.not(lat: nil, lon: nil)
      .order(created_at: :desc)
    @mapbox_token = mapbox_token
  end

  def places
    setup_city_data
    @mapbox_token = mapbox_token
  end

  private

  def normalize_city_param
    (params[:city] || 'new york').downcase.gsub(/[.-]/, ' ')
  end

  # Look up canonical city name from city key
  def lookup_city_name(city_param)
    CityDataImporter::CITY_NAMES[city_param] || city_param
  end

  # Get display name for city (properly capitalized)
  def lookup_city_display_name(city_name)
    CityDataImporter::DISPLAY_NAMES[city_name] || city_name.titleize
  end

  # Fetch neighborhoods for a city
  def fetch_neighborhoods(city_name)
    Neighborhood.for_city(city_name)
  end

  # Calculate total amenities for a city
  def calculate_total_amenities(city_name)
    NeighborhoodPlacesStat.joins(:neighborhood)
      .where(neighborhoods: { city: city_name })
      .sum(:total_amenities)
  end

  # Set up all city-related instance variables
  def setup_city_data
    city_param = normalize_city_param
    @city = lookup_city_name(city_param)
    @city_display = lookup_city_display_name(@city)
    @neighborhoods = fetch_neighborhoods(@city)
    @total_amenities = calculate_total_amenities(@city)
  end

  # Get Mapbox token for current environment
  def mapbox_token
    Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)
  end
end
