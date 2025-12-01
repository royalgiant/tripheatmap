class BestLuxuryHotelController < ApplicationController
  include CityContext

  before_action :set_city_context, only: [:show]

  def index
    @cities = get_cities
    @cities_grouped = get_cities_grouped_by_location
  end

  def show
    @city_display_name = city_display_name
    @country = @city_config['country'] || 'United States'
    @luxury_hotels = luxury_hotels
    @has_hotels = @luxury_hotels.any?
    @related_cities = fetch_related_cities
    @seo_title = "Best Luxury Hotels in #{@city_display_name} (#{Time.current.year}) | Top 5 Star Stays"
    @seo_description = "Discover the most exclusive and highly-rated luxury hotels in #{@city_display_name}. Find 5-star accommodations and top-tier service."
    @canonical_url = best_luxury_hotels_url(@url_slug)
  end

  private

  def luxury_hotels
    Place
      .joins(:neighborhood)
      .where(neighborhoods: { city: city_name.downcase })
      .where(place_type: 'hotel', category: 'luxury')
      .order(rating: :desc, review_count: :desc)
  end

  def related_city_path(slug)
    best_luxury_hotels_path(slug)
  end
end
