class BestCheapHotelController < ApplicationController
  include CityContext

  before_action :set_city_context, only: [:show]

  def index
    @cities = get_cities_with_hotel_counts
    @cities_grouped = get_cities_grouped_by_location(@cities)
  end

  def show
    @city_display_name = city_display_name
    @country = @city_config['country'] || 'United States'
    @cheap_hotels = cheap_hotels
    @has_hotels = @cheap_hotels.any?
    @related_cities = fetch_related_cities
    @seo_title = "Best Cheap Hotels in #{@city_display_name} (#{Time.current.year}) | Budget & Affordable Stays"
    @seo_description = "Find the best budget-friendly and affordable hotels in #{@city_display_name}. Quality accommodations at great prices."
    @canonical_url = best_cheap_hotels_url(@url_slug)
    if current_user
      @favorites_by_place_id = current_user.favorites.pluck(:place_id, :id).to_h
    else
      @favorites_by_place_id = {}
    end
  end

  private

  def get_cities_with_hotel_counts
    cities = get_cities

    hotel_counts = Place
      .joins(:neighborhood)
      .where(place_type: ['hotel', 'hostel'])
      .where(price_range: ['$', '$$'])
      .group('neighborhoods.city')
      .count

    cities.map do |city|
      city.merge(hotel_count: hotel_counts[city[:key]] || 0)
    end.select { |city| city[:hotel_count] > 0 }
  end

  def cheap_hotels
    Place
      .joins(:neighborhood)
      .where(neighborhoods: { city: city_name.downcase })
      .where(place_type: ['hotel', 'hostel'])
      .where(price_range: ['$', '$$'])
      .order(rating: :desc, review_count: :desc)
  end

  def related_city_path(slug)
    best_cheap_hotels_path(slug)
  end
end
