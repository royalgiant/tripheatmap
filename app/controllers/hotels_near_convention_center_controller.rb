class HotelsNearConventionCenterController < ApplicationController
  include CityContext

  before_action :set_city_and_convention_center, only: [:show]

  def index
    @cities_with_convention_centers = cities_with_convention_centers
    @cities_grouped = get_cities_grouped_by_location(@cities_with_convention_centers)
    @seo_title = "Hotels Near Convention Centers (#{Time.current.year}) | Find Conference Hotels"
    @seo_description = "Find hotels near major convention centers and conference venues worldwide. Perfect for business travel, trade shows, and conferences."
    @canonical_url = hotels_near_convention_center_index_url
  end

  def city
    @city_slug = params[:city]
    @city_config = CityDataImporter.city_configs[@city_slug]

    unless @city_config
      redirect_to hotels_near_convention_center_index_path, alert: "City not found" and return
    end

    @city_name = CityDataImporter::CITY_NAMES[@city_slug]
    @city_display_name = CityDataImporter::DISPLAY_NAMES[@city_name]
    @url_slug = @city_slug
    @country = @city_config['country'] || 'United States'

    @convention_centers = Place
      .where(city: @city_name.downcase)
      .where(place_type: ['convention_center'])
      .where.not(name: ['Unnamed', nil, ''])
      .where.not(slug: nil)
      .distinct
      .order('name ASC')

    @seo_title = "Hotels Near Convention Centers in #{@city_display_name} (#{Time.current.year})"
    @seo_description = "Find hotels near #{@convention_centers.count} convention centers in #{@city_display_name}. Perfect for conferences and business events."
    @canonical_url = hotels_near_convention_center_city_url(@city_slug)
  end

  def show
    @hotels = hotels_near_convention_center(@convention_center, radius_km: 3.0)
    @has_hotels = @hotels.any?
    @seo_title = "Hotels near #{@convention_center.name} in #{@city_display_name} (#{Time.current.year}) | Conference Hotels"
    @seo_description = "Find the best hotels near #{@convention_center.name} in #{@city_display_name}. #{@hotels.count} hotels within walking distance of the convention center."
    @canonical_url = hotels_near_convention_center_url(@convention_center.slug, @city_slug)

    @nearby_restaurants = nearby_places('restaurant', 100)
    @nearby_cafes = nearby_places('cafe', 50)
    @nearby_bars = nearby_places('bar', 50)
    @all_map_places = (@hotels.to_a + @nearby_restaurants + @nearby_cafes + @nearby_bars)
    @mapbox_token = Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)

    if current_user
      @favorites_by_place_id = current_user.favorites.pluck(:place_id, :id).to_h
    else
      @favorites_by_place_id = {}
    end
  end

  def show_smart
    slug = params[:slug]

    convention_center = Place.find_by(slug: slug, place_type: 'convention_center')
    if convention_center
      city_name = convention_center.city&.downcase
      city_config = CityDataImporter.city_configs.find { |k, v| (v['city'] || v['name'])&.downcase == city_name }

      if city_config
        params[:city] = city_config.first
        params[:convention_center] = slug
        set_city_and_convention_center
        show
        render :show
        return
      end
    end

    redirect_to hotels_near_convention_center_index_path, alert: "Convention Center or City not found for '#{slug}'"
  end

  private

  def set_city_and_convention_center
    @city_slug = params[:city]
    @convention_center_slug = params[:convention_center]

    @city_config = CityDataImporter.city_configs[@city_slug]

    unless @city_config
      redirect_to hotels_near_convention_center_index_path, alert: "City not found" and return
    end

    @city_name = CityDataImporter::CITY_NAMES[@city_slug]
    @city_display_name = CityDataImporter::DISPLAY_NAMES[@city_name]
    @url_slug = @city_slug
    @country = @city_config['country'] || 'United States'

    @convention_center = Place.find_by(slug: @convention_center_slug)

    unless @convention_center
      redirect_to hotels_near_convention_center_index_path, alert: "Convention center not found" and return
    end

    unless @convention_center.city&.downcase == @city_name.downcase
      redirect_to hotels_near_convention_center_index_path, alert: "Convention center not found in this city" and return
    end
  end

  def hotels_near_convention_center(convention_center, radius_km: 3.0)
    # Use PostGIS to find hotels within radius of convention center
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
      convention_center.longitude,
      convention_center.latitude,
      @city_name.downcase,
      convention_center.longitude,
      convention_center.latitude,
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

  def cities_with_convention_centers
    city_counts = Place
      .where(place_type: ['convention_center'])
      .where.not(name: ['Unnamed', nil, ''])
      .where.not(slug: nil)
      .where.not(city: nil)
      .where.not(country: nil)
      .where.not(continent: nil)
      .select('places.city, places.country, places.continent')
      .select('COUNT(DISTINCT places.id) as convention_center_count')
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
        convention_center_count: result.convention_center_count,
        country: country,
        continent: continent
      }
    end.compact.sort_by { |c| c[:display_name] }
  rescue => e
    Rails.logger.error "Error fetching cities with convention centers: #{e.message}"
    []
  end

  def nearby_places(place_type, limit)
    hotel_neighborhoods = @hotels.map(&:neighborhood_id).compact.uniq

    Place
      .where(neighborhood_id: hotel_neighborhoods, place_type: place_type)
      .where.not(latitude: nil, longitude: nil)
      .select(:id, :name, :place_type, :latitude, :longitude, :address, :rating, :review_count, :trip_affiliate_url)
      .order(rating: :desc, review_count: :desc)
      .limit(limit)
      .to_a
  end
end
