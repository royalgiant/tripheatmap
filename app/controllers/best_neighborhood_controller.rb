class BestNeighborhoodController < ApplicationController
  include CityContext
  before_action :set_city_context, only: [:show]

  def index
    @cities = get_cities
    @cities_grouped = get_cities_grouped_by_location
  end

  def show
    @city_display_name = city_display_name
    @country = @city_config['country'] || 'United States'
    @neighborhoods = high_vibrancy_neighborhoods
    @has_neighborhoods = @neighborhoods.any?
    @related_cities = fetch_related_cities
    @seo_title = "Best Neighborhoods in #{@city_display_name} (#{Time.current.year}) | Top Rated Areas"
    @seo_description = "Discover the best neighborhoods in #{@city_display_name} ranked by vibrancy, safety, and amenities. Find the perfect place to stay based on data."
    @canonical_url = best_neighborhood_url(@url_slug)
  end

  private

  def high_vibrancy_neighborhoods
    neighborhoods = Neighborhood
      .for_city(city_name.downcase)
      .includes(:neighborhood_places_stat, :places)
      .where.not(neighborhood_places_stats: { id: nil })

    neighborhoods
      .select { |n| n.neighborhood_places_stat.vibrancy_index > 6.0 }
      .sort_by { |n| -n.neighborhood_places_stat.vibrancy_index }
  end

  def related_city_path(slug)
    best_neighborhood_path(slug)
  end
end
