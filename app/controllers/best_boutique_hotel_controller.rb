class BestBoutiqueHotelController < ApplicationController
  include CityContext
  before_action :set_city_context, only: [:show]

  def index
    @cities = get_cities_with_hotel_counts
    @cities_grouped = get_cities_grouped_by_location(@cities)
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

    @nearby_restaurants = nearby_places('restaurant', 100)
    @nearby_cafes = nearby_places('cafe', 50)
    @nearby_bars = nearby_places('bar', 50)
    @all_map_places = (@boutique_hotels.to_a + @nearby_restaurants + @nearby_cafes + @nearby_bars)
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
      .where(place_type: 'hotel', category: 'boutique')
      .group('neighborhoods.city')
      .count

    cities.map do |city|
      city.merge(hotel_count: hotel_counts[city[:key]] || 0)
    end.select { |city| city[:hotel_count] > 0 }
  end

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

  def nearby_places(place_type, limit)
    hotel_neighborhoods = @boutique_hotels.map(&:neighborhood_id).uniq

    Place
      .where(neighborhood_id: hotel_neighborhoods, place_type: place_type)
      .where.not(latitude: nil, longitude: nil)
      .select(:id, :name, :place_type, :latitude, :longitude, :address, :rating, :review_count, :trip_affiliate_url)
      .order(rating: :desc, review_count: :desc)
      .limit(limit)
      .to_a
  end
end