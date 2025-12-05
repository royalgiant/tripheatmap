class HotelsNearLandmarkController < ApplicationController
  include CityContext

  before_action :set_city_and_landmark, only: [:show]

  def index
    @cities_with_landmarks = cities_with_popular_landmarks
    @cities_grouped = group_cities_by_continent(@cities_with_landmarks)
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
            ST_SetSRID(ST_MakePoint(places.lon, places.lat), 4326)::geography,
            ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
          ) AS distance_meters
        FROM places
        INNER JOIN neighborhoods ON neighborhoods.id = places.neighborhood_id
        WHERE neighborhoods.city = ?
          AND places.place_type IN ('hotel', 'hostel')
          AND ST_DWithin(
            ST_SetSRID(ST_MakePoint(places.lon, places.lat), 4326)::geography,
            ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
            ?
          )
        ORDER BY distance_meters ASC, rating DESC NULLS LAST, review_count DESC NULLS LAST
      SQL
      landmark.lon,
      landmark.lat,
      @city_name.downcase,
      landmark.lon,
      landmark.lat,
      radius_meters
    ])

    Place.find_by_sql(sql)
  end

  def cities_with_popular_landmarks
    # Get cities that have landmarks, grouped with their top landmarks
    cities_with_landmark_counts = Place
      .joins(:neighborhood)
      .where(place_type: ['attraction', 'museum', 'monument', 'airport', 'university', 'beach', 'convention_center', 'theme_park', 'zoo', 'park'])
      .where.not(name: ['Unnamed', nil, ''])
      .where.not(slug: nil)
      .group('neighborhoods.city')
      .having('COUNT(places.id) >= 3')
      .pluck('neighborhoods.city')

    return [] if cities_with_landmark_counts.empty?

    cities_with_landmark_counts.map do |city|
      landmarks = Place
        .joins(:neighborhood)
        .where(neighborhoods: { city: city })
        .where(place_type: ['attraction', 'museum', 'monument', 'theme_park']) # 'airport', 'university', 'beach', 'convention_center', 'zoo', 'park'
        .where.not(name: ['Unnamed', nil, ''])
        .where.not(slug: nil)
        .where("places.name ~ '^[A-Z]'")
        .where("LENGTH(places.name) > 3")
        .where("places.name !~ '[\\\\]'")
        .distinct

      city_config = CityDataImporter.city_configs.find { |key, config|
        (config['city'] || config['name'])&.downcase == city.downcase
      }

      next unless city_config

      city_slug = city_config[0]
      display_name = CityDataImporter::DISPLAY_NAMES[city]
      country = city_config[1]['country'] || 'United States'

      {
        city: city,
        display_name: display_name,
        slug: city_slug,
        landmark_count: landmarks.count,
        country: country
      }
    end.compact.sort_by { |c| c[:display_name] }
  rescue => e
    Rails.logger.error "Error fetching cities with landmarks: #{e.message}"
    []
  end

  def group_cities_by_continent(cities)
    continent_mapping = {
      'United States' => 'North America',
      'Canada' => 'North America',
      'Mexico' => 'North America',
      'United Kingdom' => 'Europe',
      'France' => 'Europe',
      'Germany' => 'Europe',
      'Spain' => 'Europe',
      'Italy' => 'Europe',
      'Netherlands' => 'Europe',
      'Belgium' => 'Europe',
      'Switzerland' => 'Europe',
      'Austria' => 'Europe',
      'Portugal' => 'Europe',
      'Ireland' => 'Europe',
      'Japan' => 'Asia',
      'Singapore' => 'Asia',
      'Australia' => 'Oceania',
      'New Zealand' => 'Oceania',
      'Argentina' => 'South America',
      'Brazil' => 'South America'
    }

    grouped = cities.group_by { |city| continent_mapping[city[:country]] || 'Other' }
    grouped.transform_values { |continent_cities| continent_cities.group_by { |city| city[:country] } }
  end
end
