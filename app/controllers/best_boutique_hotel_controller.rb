class BestBoutiqueHotelController < ApplicationController
  include CityContext
  before_action :set_city_context, only: [:show]

  def index
    @cities = get_cities
    @cities_grouped = get_cities_grouped_by_location
  end

  def show
    @city_display_name = city_display_name
    @country = @city_config['country'] || 'United States'
    @boutique_hotels = boutique_hotels
    @has_hotels = @boutique_hotels.any?
    @related_cities = fetch_related_cities
    @seo_title = "Best Boutique Hotels in #{@city_display_name} (#{Time.current.year}) | Charming Stays"
    @seo_description = "Find the most charming and unique boutique hotels in #{@city_display_name}. Curated list of highly-rated properties for an authentic stay."
    @canonical_url = best_boutique_hotels_url(@url_slug)
  end

  private

  def boutique_hotels
    Place
      .joins(:neighborhood)
      .where(neighborhoods: { city: city_name.downcase })
      .where(place_type: 'hotel', category: 'boutique')
      .order(rating: :desc, review_count: :desc)
  end

  def related_city_path(slug)
    best_boutique_hotels_path(slug)
  end
end