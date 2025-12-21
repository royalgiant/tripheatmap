class HotelsNearAirportController < ApplicationController
  include CityContext
  include HotelFiltering

  before_action :set_city_and_airport, only: [:show]

  def index
    @cities_with_airports = cities_with_airports
    @cities_grouped = get_cities_grouped_by_location(@cities_with_airports)
    @seo_title = "Hotels Near Major Airports (#{Time.current.year}) | Find Airport Hotels"
    @seo_description = "Find hotels near major international and domestic airports in cities worldwide. Perfect for layovers and business travel."
    @canonical_url = hotels_near_airport_index_url
  end

  def city
    @city_slug = params[:city]
    @city_config = CityDataImporter.city_configs[@city_slug]

    unless @city_config
      redirect_to hotels_near_airport_index_path, alert: "City not found" and return
    end

    @city_name = CityDataImporter::CITY_NAMES[@city_slug]
    @city_display_name = CityDataImporter::DISPLAY_NAMES[@city_name]
    @url_slug = @city_slug
    @country = @city_config['country'] || 'United States'

    @airports = Place
      .where(city: @city_name.downcase)
      .where(place_type: ['airport'])
      .where.not(name: ['Unnamed', nil, ''])
      .where.not(slug: nil)
      .distinct
      .order('name ASC')

    @seo_title = "Hotels Near Airports in #{@city_display_name} (#{Time.current.year})"
    @seo_description = "Find hotels near #{@airports.count} airports in #{@city_display_name}. Compare prices and book your stay near the terminal."
    @canonical_url = hotels_near_airport_city_url(@city_slug)
  end

  def show
    all_hotels = hotels_near_airport(@airport, radius_km: 5.0)
    all_hotels = apply_filters(all_hotels)
    @total_count = all_hotels.count
    @has_hotels = @total_count > 0
    neighborhood_counts = all_hotels
      .group_by(&:neighborhood)
      .transform_values(&:count)
      .sort_by { |k, v| -v }
    @top_neighborhoods = neighborhood_counts.first(2).map { |neighborhood, count| neighborhood&.name }.compact

    seo_data = generate_seo_metadata(
      base_title: "Hotels near #{@airport.name} in #{@city_display_name}",
      base_description: "Find the best hotels near #{@airport.name} in #{@city_display_name}. #{@total_count} hotels within short distance of the terminal",
      fallback_title: "Hotels near #{@airport.name} in #{@city_display_name} (#{Time.current.year}) | Airport Hotels",
      fallback_description: "Find the best hotels near #{@airport.name} in #{@city_display_name}. #{@total_count} hotels within short distance of the terminal."
    )
    @seo_title = seo_data[:title]
    @seo_description = seo_data[:description]
    @canonical_url = canonical_url_with_filters(:hotels_near_airport_url, @city_slug, @airport.slug)

    @page = params[:page]&.to_i || 1
    @per_page = 200
    @has_more = @total_count > (@page * @per_page)

    start_index = (@page - 1) * @per_page
    @hotels = all_hotels[start_index, @per_page] || []
    @nearby_restaurants = nearby_places('restaurant', 100)
    @nearby_cafes = nearby_places('cafe', 50)
    @nearby_bars = nearby_places('bar', 50)

    all_hotels_for_map = all_hotels.map do |h|
      { id: h.id, name: h.name, place_type: h.place_type, latitude: h.latitude, longitude: h.longitude, address: h.address, trip_affiliate_url: h.trip_affiliate_url, average_price: h.average_price }
    end
    @all_map_places = (all_hotels_for_map + @nearby_restaurants + @nearby_cafes + @nearby_bars)
    @mapbox_token = Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)

    if current_user
      @favorites_by_place_id = current_user.favorites.pluck(:place_id, :id).to_h
    else
      @favorites_by_place_id = {}
    end

    if request.headers["Turbo-Frame"].present? && @page > 1
      render partial: "hotels_page", locals: {
        hotels: @hotels,
        city_display_name: @city_display_name,
        page: @page,
        has_more: @has_more,
        airport_slug: @airport.slug,
        city_slug: @city_slug,
        filter_params: @filter_params
      }
    end
  end

  def show_smart
    slug = params[:slug]

    airport = Place.find_by(slug: slug, place_type: 'airport')
    if airport
      city_name = airport.city&.downcase
      city_config = CityDataImporter.city_configs.find { |k, v| (v['city'] || v['name'])&.downcase == city_name }
      
      if city_config
        params[:city] = city_config.first
        params[:airport] = slug
        set_city_and_airport
        show
        render :show
        return
      end
    end

    redirect_to hotels_near_airport_index_path, alert: "Airport or City not found for '#{slug}'"
  end

  private

  def set_city_and_airport
    @city_slug = params[:city]
    @airport_slug = params[:airport]

    @city_config = CityDataImporter.city_configs[@city_slug]

    unless @city_config
      redirect_to hotels_near_airport_index_path, alert: "City not found" and return
    end

    @city_name = CityDataImporter::CITY_NAMES[@city_slug]
    @city_display_name = CityDataImporter::DISPLAY_NAMES[@city_name]
    @url_slug = @city_slug
    @country = @city_config['country'] || 'United States'

    @airport = Place.find_by(slug: @airport_slug)

    unless @airport
      redirect_to hotels_near_airport_index_path, alert: "Airport not found" and return
    end

    unless @airport.city&.downcase == @city_name.downcase
      redirect_to hotels_near_airport_index_path, alert: "Airport not found in this city" and return
    end
  end

  def hotels_near_airport(airport, radius_km: 5.0)
    # Use PostGIS to find hotels within radius of airport
    # ST_DWithin uses meters for geography type
    radius_meters = radius_km * 1000

    sql = ActiveRecord::Base.sanitize_sql_array([
      <<~SQL,
        SELECT
          places.*,
          ST_Distance(
            ST_SetSRID(ST_MakePoint(places.longitude, places.latitude), 4326)::geography,
            ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
          ) AS distance_meters
        FROM places
        INNER JOIN neighborhoods ON neighborhoods.id = places.neighborhood_id
        WHERE neighborhoods.city = ?
          AND places.place_type IN ('hotel', 'hostel')
          AND places.name IS NOT NULL
          AND places.name != 'Unnamed'
          AND places.name != ''
          AND ST_DWithin(
            ST_SetSRID(ST_MakePoint(places.longitude, places.latitude), 4326)::geography,
            ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
            ?
          )
        ORDER BY distance_meters ASC, rating DESC NULLS LAST, review_count DESC NULLS LAST
      SQL
      airport.longitude,
      airport.latitude,
      @city_name.downcase,
      airport.longitude,
      airport.latitude,
      radius_meters
    ])

    hotels = Place.find_by_sql(sql)
    neighborhood_ids = hotels.map(&:neighborhood_id).compact.uniq
    neighborhoods = Neighborhood.where(id: neighborhood_ids).index_by(&:id)

    hotels.each do |hotel|
      hotel.association(:neighborhood).target = neighborhoods[hotel.neighborhood_id]
    end

    hotels
  end

  def nearby_places(place_type, limit)
    hotel_neighborhood_ids = @hotels.map(&:neighborhood_id).compact.uniq
    
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

  def nearby_places_for_hotels(place_type, limit, hotels)
    hotel_neighborhoods = hotels.map(&:neighborhood_id).compact.uniq

    Place
      .where(neighborhood_id: hotel_neighborhoods, place_type: place_type)
      .where.not(latitude: nil, longitude: nil)
      .select(:id, :name, :place_type, :latitude, :longitude, :address, :rating, :review_count, :trip_affiliate_url)
      .order(rating: :desc, review_count: :desc)
      .limit(limit)
      .to_a
  end

  def cities_with_airports
    city_counts = Place
      .where(place_type: ['airport'])
      .where.not(name: ['Unnamed', nil, ''])
      .where.not(slug: nil)
      .where.not(city: nil)
      .where.not(country: nil)
      .where.not(continent: nil)
      .select('places.city, places.country, places.continent')
      .select('COUNT(DISTINCT places.id) as airport_count')
      .group('places.city, places.country, places.continent')
      .having('COUNT(DISTINCT places.id) >= 1')
      .order('places.city')

    return [] if city_counts.empty?

    city_config_lookup = CityDataImporter.city_configs.each_with_object({}) do |(key, config), hash|
      city_name = (config['city'] || config['name'])&.downcase
      hash[city_name] = { slug: key, config: config } if city_name
    end

    city_counts.map do |result|
      city = result.city
      city_config = city_config_lookup[city.downcase]

      next unless city_config

      display_name = CityDataImporter::DISPLAY_NAMES[city]
      country = result.country || city_config[:config]['country'] || 'United States'
      continent = result.continent || 'Other'

      {
        city: city,
        display_name: display_name,
        slug: city_config[:slug],
        airport_count: result.airport_count,
        country: country,
        continent: continent
      }
    end.compact.sort_by { |c| c[:display_name] }
  rescue => e
    Rails.logger.error "Error fetching cities with airports: #{e.message}"
    []
  end
end
