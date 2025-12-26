class BedAndBreakfastController < ApplicationController
  include NearMeSearch

  before_action :set_canonical_url, only: [:show]

  def index
    @cities = get_cities_with_bnb_counts
    @cities_grouped = get_cities_grouped_by_location(@cities)
  end

  private

  def get_cities_with_bnb_counts
    cities = get_cities

    bnb_counts = Place
      .joins(:neighborhood)
      .bed_and_breakfasts
      .group('neighborhoods.city')
      .count

    cities.map do |city|
      city.merge(bnb_count: bnb_counts[city[:key]] || 0)
    end.select { |city| city[:bnb_count] > 0 }
  end

  def place_scope
    Place.bed_and_breakfasts
  end

  def places_variable_name
    "bed_and_breakfasts"
  end

  def index_path
    # Fallback to main B&B near me page
    bnb_near_me_index_path
  end

  # Override set_city to handle all three URL patterns
  def set_city
    city_param = params[:city]
    @state = params[:state]&.gsub('-', ' ')&.titleize if params[:state]

    # Normalize the city param (e.g., "st-paul" -> "st paul")
    normalized_city = city_param&.gsub('-', ' ')&.downcase

    # Find the actual city in the database (handles variations like "st. paul" vs "st paul")
    # Database stores cities lowercased with periods (e.g., "st. paul", "st. louis")
    neighborhood = Neighborhood.where(
      "LOWER(REPLACE(city, '.', '')) = ?",
      normalized_city&.gsub('.', '')
    ).first

    unless neighborhood
      redirect_to index_path, alert: "City not found"
      return
    end

    # Store the actual database city name for querying, and a display version
    @city_name_db = neighborhood.city  # e.g., "st. paul"
    @city_display_name = neighborhood.city.split.map(&:capitalize).join(' ')  # e.g., "St. Paul"
  end

  # Set canonical URL to avoid duplicate content penalties
  # Always canonicalize to "Location (In)" pattern
  def set_canonical_url
    city_slug = params[:city]
    @canonical_url = bed_and_breakfast_in_city_url(city: city_slug)
  end
end
