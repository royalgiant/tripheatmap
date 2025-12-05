class HotelsNearController < ApplicationController
  include CityContext

  before_action :set_city_and_neighborhood, only: [:show]

  def show
    @hotels = hotels_in_neighborhood
    @has_hotels = @hotels.any?
    @seo_title = "Hotels in #{@city_display_name} near #{@neighborhood.name} (#{Time.current.year}) | Best Stays"
    @seo_description = "Find the best hotels in #{@city_display_name} near #{@neighborhood.name}. #{@hotels.count} hotels to choose from."
    @canonical_url = hotels_near_url(@city_slug, @neighborhood_slug)
  end

  private

  def set_city_and_neighborhood
    @city_slug = params[:city]
    @neighborhood_slug = params[:neighborhood]

    @city_config = CityDataImporter.city_configs[@city_slug]

    unless @city_config
      redirect_to where_to_stay_index_path, alert: "City not found" and return
    end

    @city_name = CityDataImporter::CITY_NAMES[@city_slug]
    @city_display_name = CityDataImporter::DISPLAY_NAMES[@city_name]
    @url_slug = @city_slug
    @country = @city_config['country'] || 'United States'

    @neighborhood = Neighborhood.find_by(slug: @neighborhood_slug)

    unless @neighborhood
      redirect_to where_to_stay_path(@city_slug), alert: "Neighborhood not found" and return
    end

    unless @neighborhood.city.downcase == @city_name.downcase
      redirect_to where_to_stay_path(@city_slug), alert: "Neighborhood not found in this city" and return
    end
  end

  def hotels_in_neighborhood
    Place
      .where(neighborhood: @neighborhood)
      .where(place_type: ['hotel', 'hostel'])
      .order(rating: :desc, review_count: :desc)
  end
end
