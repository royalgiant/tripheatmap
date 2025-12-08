class HotelsNearAirportController < ApplicationController
  include CityContext

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
    @hotels = hotels_near_airport(@airport, radius_km: 5.0)
    @has_hotels = @hotels.any?
    @seo_title = "Hotels near #{@airport.name} in #{@city_display_name} (#{Time.current.year}) | Airport Hotels"
    @seo_description = "Find the best hotels near #{@airport.name} in #{@city_display_name}. #{@hotels.count} hotels within short distance of the terminal."
    @canonical_url = hotels_near_airport_url(@airport.slug, @city_slug)
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
            ST_SetSRID(ST_MakePoint(places.lon, places.lat), 4326)::geography,
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
            ST_SetSRID(ST_MakePoint(places.lon, places.lat), 4326)::geography,
            ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
            ?
          )
        ORDER BY distance_meters ASC, rating DESC NULLS LAST, review_count DESC NULLS LAST
      SQL
      airport.lon,
      airport.lat,
      @city_name.downcase,
      airport.lon,
      airport.lat,
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
