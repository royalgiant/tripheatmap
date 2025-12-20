class HotelsNearLandmarkController < ApplicationController
  include CityContext

  before_action :set_city_and_landmark, only: [:show]

  def index
    @cities_with_landmarks = cities_with_popular_landmarks
    @cities_grouped = get_cities_grouped_by_location(@cities_with_landmarks)
    @seo_title = "Hotels Near Popular Landmarks (#{Time.current.year}) | Find Hotels Near Attractions"
    @seo_description = "Find hotels near popular landmarks, attractions, airports, and points of interest in major cities worldwide."
    @canonical_url = hotels_near_landmark_index_url
  end

  def city
    @city_slug = params[:city]
    @city_config = CityDataImporter.city_configs[@city_slug]

    unless @city_config
      redirect_to hotels_near_landmark_index_path, alert: "City not found" and return
    end

    @city_name = CityDataImporter::CITY_NAMES[@city_slug]
    @city_display_name = CityDataImporter::DISPLAY_NAMES[@city_name]
    @url_slug = @city_slug
    @country = @city_config['country'] || 'United States'

    @landmarks = Place
      .includes(:neighborhood)
      .joins(:neighborhood)
      .where(neighborhoods: { city: @city_name.downcase })
      .where(place_type: ['attraction', 'museum', 'monument', 'theme_park'])
      .where.not(name: ['Unnamed', nil, ''])
      .where.not(slug: nil)
      .where("places.name ~ '^[A-Z]'")
      .where("LENGTH(places.name) > 3")
      .where("places.name !~ '[\\\\]'")
      .distinct
      .order('places.name ASC')

    @seo_title = "Hotels Near Popular Landmarks in #{@city_display_name} (#{Time.current.year})"
    @seo_description = "Find hotels near #{@landmarks.count} popular landmarks in #{@city_display_name}. Explore attractions, museums, monuments, and points of interest."
    @canonical_url = hotels_near_landmark_city_url(@city_slug)
  end

  def show
    @hotels = hotels_near_landmark(@landmark, radius_km: 5.0)
    @has_hotels = @hotels.any?
    @seo_title = "Hotels near #{@landmark.name} in #{@city_display_name} (#{Time.current.year}) | Best Stays"
    @seo_description = "Find the best hotels near #{@landmark.name} in #{@city_display_name}. #{@hotels.count} hotels within walking distance."
    @canonical_url = hotels_near_landmark_url(@city_slug, @landmark.slug)
    if current_user
      @favorites_by_place_id = current_user.favorites.pluck(:place_id, :id).to_h
    else
      @favorites_by_place_id = {}
    end
  end

  private

  def set_city_and_landmark
    @city_slug = params[:city]
    @landmark_slug = params[:landmark]

    @city_config = CityDataImporter.city_configs[@city_slug]

    unless @city_config
      redirect_to hotels_near_landmark_index_path, alert: "City not found" and return
    end

    @city_name = CityDataImporter::CITY_NAMES[@city_slug]
    @city_display_name = CityDataImporter::DISPLAY_NAMES[@city_name]
    @url_slug = @city_slug
    @country = @city_config['country'] || 'United States'

    @landmark = Place.find_by(slug: @landmark_slug)

    unless @landmark
      redirect_to hotels_near_landmark_index_path, alert: "Landmark not found" and return
    end

    unless @landmark.neighborhood&.city&.downcase == @city_name.downcase
      redirect_to hotels_near_landmark_index_path, alert: "Landmark not found in this city" and return
    end
  end

  def hotels_near_landmark(landmark, radius_km: 5.0)
    # Use PostGIS to find hotels within radius of landmark
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
      landmark.longitude,
      landmark.latitude,
      @city_name.downcase,
      landmark.longitude,
      landmark.latitude,
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

  def cities_with_popular_landmarks
    city_counts = Place
      .where(place_type: ['attraction', 'museum', 'monument', 'theme_park'])
      .where.not(name: ['Unnamed', nil, ''])
      .where.not(slug: nil)
      .where.not(city: nil)
      .where("places.name ~ '^[A-Z]'")
      .where("LENGTH(places.name) > 3")
      .where("places.name !~ '[\\\\]'")
      .select('places.city, places.country, places.continent')
      .select('COUNT(DISTINCT places.id) as landmark_count')
      .group('places.city, places.country, places.continent')
      .having('COUNT(DISTINCT places.id) >= 3')
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
        landmark_count: result.landmark_count,
        country: country,
        continent: continent
      }
    end.compact.sort_by { |c| c[:display_name] }
  rescue => e
    Rails.logger.error "Error fetching cities with landmarks: #{e.message}"
    []
  end
end
