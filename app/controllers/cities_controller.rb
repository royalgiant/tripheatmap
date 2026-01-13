class CitiesController < ApplicationController
  include CityContext
  include HotelFiltering

  before_action :set_city_context, only: [:show]

  def index
    # Get all cities from the city configurations
    all_cities = CityDataImporter.city_configs.values.map do |config|
      {
        name: config[:name],
        slug: config[:url_slug] || config[:name].parameterize,
        country: config[:country] || config[:name].split(',').last&.strip
      }
    end.uniq { |c| c[:name] }

    @total_cities = all_cities.size

    # Group by country
    @cities_grouped = all_cities.group_by { |city| city[:country] }.sort_by { |country, _| country }

    @seo_title = "City Travel Guides - Hotels, Accommodations & Attractions"
    @seo_description = "Browse comprehensive travel guides for cities worldwide. Find hotels, boutique stays, budget accommodations, and top attractions all in one place."
  end

  def show
    @city_name = params[:city]
    @state_name = params[:state]
    @country_name = params[:country]

    # Find the city configuration
    city_key = [@city_name, @state_name, @country_name].compact.join(', ')
    @city_config = CityDataImporter.city_configs.values.find do |config|
      config[:name].downcase == city_key.downcase ||
      config[:name].downcase == [@city_name, @country_name].join(', ').downcase ||
      config[:name].downcase == @city_name.downcase
    end

    unless @city_config
      redirect_to root_path, alert: "City not found"
      return
    end

    @city_display_name = @city_config[:name]
    @city_name_db = @city_config[:name].split(',').first.strip.downcase

    # Fetch all categories of places
    fetch_all_places

    # Prepare map data
    prepare_map_data

    # SEO
    @seo_title = "Hotels, Accommodations & Travel Guide - #{@city_display_name}"
    @seo_description = "Discover the best hotels, boutique accommodations, budget stays, Airbnbs, and top attractions in #{@city_display_name}. Complete travel guide with maps and recommendations."

    @mapbox_token = Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)
  end

  private

  def fetch_all_places
    base_scope = Place
      .includes(:neighborhood)
      .joins(:neighborhood)
      .where(neighborhoods: { city: @city_name_db })

    # Hotels by category
    @luxury_hotels = base_scope
      .where(place_type: 'hotel', category: 'luxury')
      .order(rating: :desc, review_count: :desc)
      .limit(50)
      .to_a

    @boutique_hotels = base_scope
      .where(place_type: 'hotel', category: 'boutique')
      .order(rating: :desc, review_count: :desc)
      .limit(50)
      .to_a

    @cheap_hotels = base_scope
      .where(place_type: ['hotel', 'hostel'])
      .where(price_range: ['$', '$$'])
      .order(rating: :desc, review_count: :desc)
      .limit(50)
      .to_a

    @bed_and_breakfasts = base_scope
      .where(place_type: 'bed_and_breakfast')
      .order(rating: :desc, review_count: :desc)
      .limit(50)
      .to_a

    # All regular hotels (not in other categories)
    @all_hotels = base_scope
      .where(place_type: 'hotel')
      .where.not(id: (@luxury_hotels + @boutique_hotels + @cheap_hotels).map(&:id))
      .order(rating: :desc, review_count: :desc)
      .limit(50)
      .to_a

    # Hotels near special locations
    fetch_hotels_near_poi

    # Favorites
    if user_signed_in?
      @favorites_by_place_id = current_user.favorites.pluck(:place_id, :id).to_h
    else
      @favorites_by_place_id = {}
    end
  end

  def fetch_hotels_near_poi
    # Fetch airports, universities, landmarks, convention centers in this city
    @airports = Place.where(city: @city_name_db, place_type: 'airport')
                     .where.not(name: ['Unnamed', nil, ''])
                     .where.not(slug: nil)
                     .limit(10).to_a
    @universities = Place.where(city: @city_name_db, place_type: 'university')
                         .where.not(name: ['Unnamed', nil, ''])
                         .where.not(slug: nil)
                         .limit(10).to_a
    @landmarks = Place.where(city: @city_name_db, place_type: 'landmark')
                      .where.not(name: ['Unnamed', nil, ''])
                      .where.not(slug: nil)
                      .limit(10).to_a
    @convention_centers = Place.where(city: @city_name_db, place_type: 'convention_center')
                               .where.not(name: ['Unnamed', nil, ''])
                               .where.not(slug: nil)
                               .limit(10).to_a

    # For each, fetch nearby hotels (just a few for display)
    @hotels_near_airports = {}
    @airports.each do |airport|
      @hotels_near_airports[airport.id] = fetch_hotels_near_location(airport, 5000) # 5km radius
    end

    @hotels_near_universities = {}
    @universities.each do |university|
      @hotels_near_universities[university.id] = fetch_hotels_near_location(university, 3000) # 3km radius
    end

    @hotels_near_landmarks = {}
    @landmarks.each do |landmark|
      @hotels_near_landmarks[landmark.id] = fetch_hotels_near_location(landmark, 2000) # 2km radius
    end

    @hotels_near_convention_centers = {}
    @convention_centers.each do |convention_center|
      @hotels_near_convention_centers[convention_center.id] = fetch_hotels_near_location(convention_center, 3000) # 3km radius
    end
  end

  def fetch_hotels_near_location(location, radius_meters)
    return [] unless location.latitude && location.longitude

    sql = <<~SQL
      SELECT places.*,
             ST_Distance(
               ST_SetSRID(ST_MakePoint(places.longitude, places.latitude), 4326)::geography,
               ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
             ) AS distance_meters
      FROM places
      INNER JOIN neighborhoods ON neighborhoods.id = places.neighborhood_id
      WHERE neighborhoods.city = ?
        AND places.place_type IN ('hotel', 'hostel')
        AND ST_DWithin(
          ST_SetSRID(ST_MakePoint(places.longitude, places.latitude), 4326)::geography,
          ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
          ?
        )
      ORDER BY distance_meters ASC, places.rating DESC NULLS LAST
      LIMIT 10
    SQL

    Place.find_by_sql([
      sql,
      location.longitude, location.latitude,
      @city_name_db,
      location.longitude, location.latitude,
      radius_meters
    ])
  end

  def prepare_map_data
    # Combine all places for the map
    all_places = [
      @luxury_hotels,
      @boutique_hotels,
      @cheap_hotels,
      @bed_and_breakfasts,
      @all_hotels,
      @hotels_near_airports.values.flatten,
      @hotels_near_universities.values.flatten,
      @hotels_near_landmarks.values.flatten,
      @hotels_near_convention_centers.values.flatten
    ].flatten.uniq(&:id)

    @all_map_places = all_places.map do |place|
      {
        id: place.id,
        name: place.name,
        latitude: place.latitude,
        longitude: place.longitude,
        price_range: place.price_range,
        rating: place.rating,
        review_count: place.review_count,
        category: determine_place_category(place)
      }
    end

    # Add POI markers
    @poi_markers = []
    @airports.each do |airport|
      @poi_markers << {
        id: "airport-#{airport.id}",
        name: airport.name,
        latitude: airport.latitude,
        longitude: airport.longitude,
        type: 'airport'
      }
    end
    @universities.each do |university|
      @poi_markers << {
        id: "university-#{university.id}",
        name: university.name,
        latitude: university.latitude,
        longitude: university.longitude,
        type: 'university'
      }
    end
    @landmarks.each do |landmark|
      @poi_markers << {
        id: "landmark-#{landmark.id}",
        name: landmark.name,
        latitude: landmark.latitude,
        longitude: landmark.longitude,
        type: 'landmark'
      }
    end
    @convention_centers.each do |cc|
      @poi_markers << {
        id: "convention-#{cc.id}",
        name: cc.name,
        latitude: cc.latitude,
        longitude: cc.longitude,
        type: 'convention_center'
      }
    end
  end

  def determine_place_category(place)
    return 'luxury' if @luxury_hotels.include?(place)
    return 'boutique' if @boutique_hotels.include?(place)
    return 'cheap' if @cheap_hotels.include?(place)
    return 'bnb' if @bed_and_breakfasts.include?(place)
    'hotel'
  end
end
