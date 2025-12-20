class BestLuxuryHotelController < ApplicationController
  include CityContext

  before_action :set_city_context, only: [:show]

  def index
    @cities = get_cities_with_hotel_counts
    @cities_grouped = get_cities_grouped_by_location(@cities)
  end

  def show
    @city_display_name = city_display_name
    @country = @city_config['country'] || 'United States'
    @luxury_hotels = luxury_hotels
    @has_hotels = @luxury_hotels.any?
    @related_cities = fetch_related_cities
    @seo_title = "Best Luxury Hotels in #{@city_display_name} (#{Time.current.year}) | Top 5 Star Stays"
    @seo_description = "Discover the most exclusive and highly-rated luxury hotels in #{@city_display_name}. Find 5-star accommodations and top-tier service."
    @nearby_restaurants = nearby_places('restaurant', 100)
    @nearby_cafes = nearby_places('cafe', 50)
    @nearby_bars = nearby_places('bar', 50)
    @all_map_places = (@luxury_hotels.to_a + @nearby_restaurants + @nearby_cafes + @nearby_bars)
    @mapbox_token = Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)

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
      .where(place_type: 'hotel', category: 'luxury')
      .group('neighborhoods.city')
      .count

    cities.map do |city|
      city.merge(hotel_count: hotel_counts[city[:key]] || 0)
    end.select { |city| city[:hotel_count] > 0 }
  end

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

  def nearby_places(place_type, limit)
    hotel_neighborhoods = @luxury_hotels.map(&:neighborhood_id).uniq

    Place
      .where(neighborhood_id: hotel_neighborhoods, place_type: place_type)
      .where.not(latitude: nil, longitude: nil)
      .select(:id, :name, :place_type, :latitude, :longitude, :address, :rating, :review_count, :trip_affiliate_url)
      .order(rating: :desc, review_count: :desc)
      .limit(limit)
      .to_a
  end
end
