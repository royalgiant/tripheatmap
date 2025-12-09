class AirportImporter
  OVERPASS_API_URL = "https://overpass-api.de/api/interpreter"

  def initialize
    @city_configs = YAML.load_file(Rails.root.join('config', 'neighborhood_boundaries.yml'))
    
    # Pre-compute city URL map for O(1) lookup
    @city_url_map = {}
    @city_configs.each do |_key, config|
      next unless config['tripcomurl'].present?
      @city_url_map[config['city'].to_s.downcase] = config['tripcomurl'] if config['city']
      @city_url_map[config['name'].to_s.downcase] = config['tripcomurl'] if config['name']
    end
  end

  def import(city_name)
    puts "Importing city-wide landmarks (airports) for #{city_name}..."

    # Get bounding box for entire city from all neighborhoods
    normalized_city = city_name.to_s.downcase
    
    # Use sanitized SQL to get city bounds
    sql = ActiveRecord::Base.sanitize_sql_array([
      "SELECT
        ST_YMin(ST_Extent(geom::geometry)) as min_lat,
        ST_XMin(ST_Extent(geom::geometry)) as min_lon,
        ST_YMax(ST_Extent(geom::geometry)) as max_lat,
        ST_XMax(ST_Extent(geom::geometry)) as max_lon
      FROM neighborhoods
      WHERE city = ?",
      normalized_city
    ])

    result = ActiveRecord::Base.connection.select_one(sql)

    unless result && result['min_lat'] && result['min_lon'] && result['max_lat'] && result['max_lon']
      puts "⚠️  No neighborhoods found for #{city_name}, skipping airport import"
      return
    end

    bounds = {
      min_lat: result['min_lat'].to_f,
      min_lon: result['min_lon'].to_f,
      max_lat: result['max_lat'].to_f,
      max_lon: result['max_lon'].to_f
    }

    # Query only airports
    query = build_airport_query(bounds)
    response = Faraday.post(OVERPASS_API_URL, query, { 'Content-Type' => 'text/plain' })

    unless response.success?
      puts "⚠️  Failed to fetch airports from Overpass API"
      return
    end

    data = JSON.parse(response.body)
    save_airports(city_name, data['elements'] || [])
  rescue => e
    puts "⚠️  Error importing airports: #{e.message}"
    Rails.logger.error "Error importing airports: #{e.message}\n#{e.backtrace.join("\n")}"
  end

  private

  def build_airport_query(bounds)
    bbox = "#{bounds[:min_lat]},#{bounds[:min_lon]},#{bounds[:max_lat]},#{bounds[:max_lon]}"

    <<~QUERY
      [out:json][timeout:25];
      (
        node["aeroway"="aerodrome"](#{bbox});
        way["aeroway"="aerodrome"](#{bbox});
        relation["aeroway"="aerodrome"](#{bbox});
      );
      out center tags;
    QUERY
  end

  def save_airports(city_name, elements)
    return if elements.empty?

    # Get location data from any neighborhood in city (all have same city/state/country/continent)
    sample_neighborhood = Neighborhood.where(city: city_name.downcase).first
    return unless sample_neighborhood

    # Delete existing airports for this city
    Place.where(place_type: 'airport', city: city_name.downcase).delete_all

    current_time = Time.current
    places_to_create = []

    elements.each do |element|
      lat = element['lat'] || element.dig('center', 'lat')
      lon = element['lon'] || element.dig('center', 'lon')
      next unless lat && lon

      tags = element['tags'] || {}
      name = tags['name'] || 'Airport'
      next if name == 'Unnamed' || name.blank?

      slug = "#{name.parameterize}-#{city_name.downcase}-airport"

      places_to_create << {
        neighborhood_id: nil,  # No neighborhood association for city-wide landmarks
        name: name,
        place_type: 'airport',
        lat: lat,
        lon: lon,
        address: build_address(tags),
        tags: tags,
        trip_affiliate_url: get_trip_affiliate_url(city_name),
        slug: slug,
        city: sample_neighborhood.city,
        state: sample_neighborhood.state,
        country: sample_neighborhood.country,
        continent: sample_neighborhood.continent,
        created_at: current_time,
        updated_at: current_time
      }
    end

    Place.insert_all(places_to_create) if places_to_create.any?
    puts "✅ Imported #{places_to_create.size} airport(s) for #{city_name}"
  end

  def get_trip_affiliate_url(city_name)
    return nil unless city_name.present?
    @city_url_map[city_name.downcase]
  end

  def build_address(tags)
    parts = []
    parts << tags['addr:housenumber'] if tags['addr:housenumber']
    parts << tags['addr:street'] if tags['addr:street']
    parts << tags['addr:city'] if tags['addr:city']
    parts.join(', ').presence
  end
end
