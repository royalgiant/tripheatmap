class BestBoutiqueHotelController < ApplicationController
  include CityContext
  include HotelFiltering
  before_action :set_city_context, only: [:show]

  def index
    @cities = get_cities_with_hotel_counts
    @cities_grouped = get_cities_grouped_by_location(@cities)
  end

  def show
    @city_display_name = city_display_name
    @country = @city_config['country'] || 'United States'

    all_hotels = boutique_hotels
    all_hotels = apply_filters(all_hotels)

    @total_count = all_hotels.count
    @has_hotels = @total_count > 0
    neighborhood_counts = all_hotels
      .group_by(&:neighborhood)
      .transform_values(&:count)
      .sort_by { |k, v| -v }
    @top_neighborhoods = neighborhood_counts.first(2).map { |neighborhood, count| neighborhood&.name }.compact

    @related_cities = fetch_related_cities

    # Generate SEO metadata based on filters
    seo_data = generate_seo_metadata(
      base_title: "Best Boutique Hotels in #{@city_display_name}",
      base_description: "Find the most charming and unique boutique hotels in #{@city_display_name}",
      fallback_title: "Best Boutique Hotels in #{@city_display_name} (#{Time.current.year}) | Charming Stays",
      fallback_description: "Find the most charming and unique boutique hotels in #{@city_display_name}. Curated list of highly-rated properties for an authentic stay."
    )
    @seo_title = seo_data[:title]
    @seo_description = seo_data[:description]
    @canonical_url = canonical_url_with_filters(:best_boutique_hotels_url, @url_slug)

    @page = params[:page]&.to_i || 1
    @per_page = 200
    @has_more = @total_count > (@page * @per_page)

    @boutique_hotels = all_hotels.limit(@per_page).offset((@page - 1) * @per_page)
    @nearby_restaurants = nearby_places('restaurant', 100)
    @nearby_cafes = nearby_places('cafe', 50)
    @nearby_bars = nearby_places('bar', 50)
    @all_map_places = (all_hotels.select(:id, :name, :place_type, :latitude, :longitude, :address, :trip_affiliate_url, :average_price, :neighborhood_id).to_a + @nearby_restaurants + @nearby_cafes + @nearby_bars)
    @mapbox_token = Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)

    if current_user
      @favorites_by_place_id = current_user.favorites.pluck(:place_id, :id).to_h
    else
      @favorites_by_place_id = {}
    end

    if request.headers["Turbo-Frame"].present? && @page > 1
      render partial: "hotels_page", locals: {
        hotels: @boutique_hotels,
        city_display_name: @city_display_name,
        page: @page,
        has_more: @has_more,
        url_slug: @url_slug,
        path_helper: :best_boutique_hotels_path,
        filter_params: @filter_params
      }
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
      .includes(:neighborhood)
      .joins(:neighborhood)
      .where(neighborhoods: { city: city_name.downcase })
      .where(place_type: 'hotel', category: 'boutique')
      .order(rating: :desc, review_count: :desc)
  end

  def related_city_path(slug)
    best_boutique_hotels_path(slug)
  end

  def nearby_places(place_type, limit)
    hotel_neighborhood_ids = @boutique_hotels.map(&:neighborhood_id).compact.uniq

    return [] if hotel_neighborhood_ids.empty?

    target_neighborhoods = hotel_neighborhood_ids.first(20)

    # Calculate how many places per neighborhood to approximate the total limit
    # Ensure at least 3-20
    per_hood_limit = (limit / target_neighborhoods.size.to_f).ceil.clamp(3, 20)

    sql = <<~SQL
      SELECT sub.* FROM (
        SELECT id, name, place_type, latitude, longitude, address, rating, review_count, trip_affiliate_url, neighborhood_id,
               ROW_NUMBER() OVER (
                 PARTITION BY neighborhood_id
                 ORDER BY rating DESC, review_count DESC
               ) as rn
        FROM places
        WHERE neighborhood_id IN (?)
          AND place_type = ?
          AND latitude IS NOT NULL AND longitude IS NOT NULL
      ) sub
      WHERE rn <= ?
    SQL

    query = ActiveRecord::Base.sanitize_sql_array([sql, target_neighborhoods, place_type, per_hood_limit])
    Place.find_by_sql(query)
  end

end