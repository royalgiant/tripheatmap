class UniversityImporter
  OVERPASS_API_URL = "https://overpass-api.de/api/interpreter"

  def initialize
    @city_configs = BoundariesConfig.all_cities

    # Pre-compute city URL map for O(1) lookup
    @city_url_map = {}
    @city_configs.each do |_key, config|
      next unless config['tripcomurl'].present?
      @city_url_map[config['city'].to_s.downcase] = config['tripcomurl'] if config['city']
      @city_url_map[config['name'].to_s.downcase] = config['tripcomurl'] if config['name']
    end
  end

  def import(city_name)
    puts "Importing universities for #{city_name}..."

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
      puts "⚠️  No neighborhoods found for #{city_name}, skipping university import"
      return
    end

    bounds = {
      min_lat: result['min_lat'].to_f,
      min_lon: result['min_lon'].to_f,
      max_lat: result['max_lat'].to_f,
      max_lon: result['max_lon'].to_f
    }

    # Query universities and colleges
    query = build_university_query(bounds)
    response = Faraday.post(OVERPASS_API_URL, query, { 'Content-Type' => 'text/plain' })

    unless response.success?
      puts "⚠️  Failed to fetch universities from Overpass API"
      return
    end

    data = JSON.parse(response.body)
    save_universities(city_name, data['elements'] || [])
  rescue => e
    puts "⚠️  Error importing universities: #{e.message}"
    Rails.logger.error "Error importing universities: #{e.message}\n#{e.backtrace.join("\n")}"
  end

  private

  def build_university_query(bounds)
    bbox = "#{bounds[:min_lat]},#{bounds[:min_lon]},#{bounds[:max_lat]},#{bounds[:max_lon]}"

    <<~QUERY
      [out:json][timeout:25];
      (
        node["amenity"="university"](#{bbox});
        way["amenity"="university"](#{bbox});
        relation["amenity"="university"](#{bbox});
        node["amenity"="college"](#{bbox});
        way["amenity"="college"](#{bbox});
        relation["amenity"="college"](#{bbox});
      );
      out center tags;
    QUERY
  end

  def save_universities(city_name, elements)
    return if elements.empty?

    # Get location data from any neighborhood in city (all have same city/state/country/continent)
    sample_neighborhood = Neighborhood.where(city: city_name.downcase).first
    return unless sample_neighborhood

    # Load all neighborhoods for this city to find which neighborhood each university belongs to
    neighborhoods = Neighborhood.where(city: city_name.downcase).to_a

    # Delete existing universities for this city
    Place.where(place_type: 'university', city: city_name.downcase).delete_all

    current_time = Time.current
    places_to_create = []

    elements.each do |element|
      lat = element['lat'] || element.dig('center', 'lat')
      lon = element['lon'] || element.dig('center', 'lon')
      next unless lat && lon

      tags = element['tags'] || {}
      name = tags['name'] || tags['official_name'] || 'University'
      next if name == 'Unnamed' || name.blank?

      # Find which neighborhood contains this university using PostGIS
      neighborhood = find_neighborhood_for_point(lat, lon, neighborhoods)

      slug = "#{name.parameterize}-#{city_name.downcase}-university"

      places_to_create << {
        neighborhood_id: neighborhood&.id,  # Associate with neighborhood
        name: name,
        place_type: 'university',
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
    puts "✅ Imported #{places_to_create.size} university/universities for #{city_name}"
  end

  def find_neighborhood_for_point(lat, lon, neighborhoods)
    # Use PostGIS to find which neighborhood contains this point
    point = "POINT(#{lon} #{lat})"

    neighborhoods.find do |neighborhood|
      next unless neighborhood.geom

      sql = ActiveRecord::Base.sanitize_sql_array([
        "SELECT ST_Contains(geom::geometry, ST_GeomFromText(?, 4326)) as contains FROM neighborhoods WHERE id = ?",
        point,
        neighborhood.id
      ])

      result = ActiveRecord::Base.connection.select_one(sql)
      result && result['contains'] == true
    end
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
