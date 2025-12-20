# Service for importing amenity counts from OpenStreetMap via Overpass API
#
# Usage:
#   OverpassImporter.new.import_for_city('Dallas')
#   OverpassImporter.new.import_for_neighborhood(neighborhood)
#
class OverpassImporter
  OVERPASS_API_URL = "https://overpass-api.de/api/interpreter"

  # Amenity types we're interested in
  AMENITIES = {
    restaurant: 'restaurant',
    cafe: 'cafe',
    bar: 'bar',
    hotel: 'hotel',
    hostel: 'hostel',
    attraction: 'attraction',
    museum: 'museum',
    monument: 'monument',
    viewpoint: 'viewpoint',
    airport: 'airport',
    university: 'university',
    beach: 'beach',
    convention_center: 'convention_center',
    theme_park: 'theme_park',
    zoo: 'zoo',
    park: 'park'
  }.freeze

  def initialize
    @errors = []
    @city_configs = BoundariesConfig.all_cities

    # Pre-compute city URL maps for O(1) lookup
    @city_trip_url_map = {}
    @city_agoda_url_map = {}
    @city_configs.each do |_key, config|
      city_key = config['city'].to_s.downcase
      name_key = config['name'].to_s.downcase

      if config['tripcomurl'].present?
        @city_trip_url_map[city_key] = config['tripcomurl'] if config['city']
        @city_trip_url_map[name_key] = config['tripcomurl'] if config['name']
      end

      if config['agodacomurl'].present?
        @city_agoda_url_map[city_key] = config['agodacomurl'] if config['city']
        @city_agoda_url_map[name_key] = config['agodacomurl'] if config['name']
      end
    end
  end

  # Import amenity counts for all neighborhoods in a city
  def import_for_city(city_name)
    # Normalize city name to lowercase for consistent querying
    normalized_city = city_name.to_s.downcase
    neighborhoods = Neighborhood.for_city(normalized_city).with_geom
    total = neighborhoods.count

    puts "Importing places data for #{total} neighborhoods in #{city_name}..."

    success_count = 0
    neighborhoods.each_with_index do |neighborhood, index|
      if import_for_neighborhood(neighborhood)
        success_count += 1
      end
      print "\rProcessed: #{index + 1}/#{total}" if (index + 1) % 5 == 0
    end

    puts "\n✅ Successfully imported for #{success_count}/#{total} neighborhoods"
    puts "❌ Errors: #{@errors.size}" if @errors.any?
    @errors.each { |err| puts "  - #{err}" }

    success_count
  end

  # Import amenity counts for a single neighborhood
  def import_for_neighborhood(neighborhood)
    bounds = get_bounding_box(neighborhood)
    result = query_amenities(bounds)

    return false unless result

    counts = result[:counts]
    elements = result[:elements]

    # Save individual places
    save_places(neighborhood, elements)

    true
  rescue => e
    @errors << "Neighborhood #{neighborhood.name}: #{e.message}"
    false
  end

  private

  # Get bounding box for a neighborhood
  def get_bounding_box(neighborhood)
    result = ActiveRecord::Base.connection.execute("
      SELECT
        ST_YMin(geom::geometry) as min_lat,
        ST_XMin(geom::geometry) as min_lon,
        ST_YMax(geom::geometry) as max_lat,
        ST_XMax(geom::geometry) as max_lon
      FROM neighborhoods
      WHERE id = #{neighborhood.id}
    ").first

    {
      min_lat: result['min_lat'].to_f,
      min_lon: result['min_lon'].to_f,
      max_lat: result['max_lat'].to_f,
      max_lon: result['max_lon'].to_f
    }
  end

  # Query Overpass API for amenity counts and elements
  def query_amenities(bounds)
    query = build_overpass_query(bounds)

    response = Faraday.post(OVERPASS_API_URL, query, { 'Content-Type' => 'text/plain' })

    unless response.success?
      Rails.logger.error "Overpass API error: #{response.status}"
      return nil
    end

    data = JSON.parse(response.body)
    parse_amenities(data)
  rescue Faraday::Error => e
    Rails.logger.error "Overpass API request failed: #{e.message}"
    nil
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse Overpass response: #{e.message}"
    nil
  end

  # Build Overpass QL query
  def build_overpass_query(bounds)
    bbox = "#{bounds[:min_lat]},#{bounds[:min_lon]},#{bounds[:max_lat]},#{bounds[:max_lon]}"

    <<~QUERY
      [out:json][timeout:25];
      (
        node["amenity"~"restaurant|cafe|bar|pub|university|college|conference_centre"](#{bbox});
        way["amenity"~"restaurant|cafe|bar|pub|university|college|conference_centre"](#{bbox});
        node["tourism"~"hotel|hostel|attraction|museum|viewpoint|theme_park|zoo"](#{bbox});
        way["tourism"~"hotel|hostel|attraction|museum|viewpoint|theme_park|zoo"](#{bbox});
        relation["tourism"~"hotel|hostel|attraction|museum|viewpoint|theme_park|zoo"](#{bbox});
        node["historic"~"monument|memorial"](#{bbox});
        way["historic"~"monument|memorial"](#{bbox});
        node["aeroway"="aerodrome"](#{bbox});
        way["aeroway"="aerodrome"](#{bbox});
        relation["aeroway"="aerodrome"](#{bbox});
        node["natural"="beach"](#{bbox});
        way["natural"="beach"](#{bbox});
        node["leisure"="park"](#{bbox});
        way["leisure"="park"](#{bbox});
        relation["leisure"="park"](#{bbox});
      );
      out center tags;
    QUERY
  end

  # Parse amenities from Overpass response
  # Returns both counts and full elements with coordinates
  def parse_amenities(data)
    counts = {
      restaurant: 0, cafe: 0, bar: 0, hotel: 0, hostel: 0,
      attraction: 0, museum: 0, monument: 0, viewpoint: 0,
      airport: 0, university: 0, beach: 0, convention_center: 0,
      theme_park: 0, zoo: 0, park: 0
    }
    elements = []

    return { counts: counts, elements: elements } unless data['elements']

    data['elements'].each do |element|
      tags = element['tags'] || {}
      amenity = tags['amenity']
      tourism = tags['tourism']
      historic = tags['historic']
      aeroway = tags['aeroway']
      natural_tag = tags['natural']
      leisure = tags['leisure']

      place_type = nil

      if amenity
        place_type = case amenity
                     when 'restaurant' then 'restaurant'
                     when 'cafe' then 'cafe'
                     when 'bar', 'pub' then 'bar'
                     when 'university', 'college' then 'university'
                     when 'conference_centre' then 'convention_center'
                     end
      end

      if tourism && place_type.nil?
        place_type = case tourism
                     when 'hotel' then 'hotel'
                     when 'hostel' then 'hostel'
                     when 'attraction' then 'attraction'
                     when 'museum' then 'museum'
                     when 'viewpoint' then 'viewpoint'
                     when 'theme_park' then 'theme_park'
                     when 'zoo' then 'zoo'
                     end
      end

      if historic && place_type.nil?
        place_type = case historic
                     when 'monument', 'memorial' then 'monument'
                     end
      end

      if aeroway && place_type.nil?
        place_type = 'airport' if aeroway == 'aerodrome'
      end

      if natural_tag && place_type.nil?
        place_type = 'beach' if natural_tag == 'beach'
      end

      if leisure && place_type.nil?
        place_type = 'park' if leisure == 'park'
      end

      next unless place_type

      counts[place_type.to_sym] += 1

      elements << element.merge('place_type' => place_type)
    end

    { counts: counts, elements: elements }
  end

  # Save individual places to database
  # Uses 2 queries total: 1 DELETE + 1 bulk INSERT
  def save_places(neighborhood, elements)
    # Filter elements to ensure they are strictly inside the neighborhood polygon
    # This prevents duplicates when bounding boxes overlap
    filtered_elements = filter_elements_by_polygon(neighborhood, elements)

    # Hard delete existing places for this neighborhood (1 query)
    Place.where(neighborhood_id: neighborhood.id).delete_all

    return if filtered_elements.empty?

    places_to_create = []
    current_time = Time.current

    filtered_elements.each do |element|
      # Extract coordinates
      # For nodes: lat/lon are directly on the element
      # For ways: lat/lon are in the 'center' object
      lat = element['lat'] || element.dig('center', 'lat')
      lon = element['lon'] || element.dig('center', 'lon')

      next unless lat && lon

      # Extract name and other tags
      tags = element['tags'] || {}
      name = tags['name'] || 'Unnamed'
      address = build_address(tags)

      slug = generate_place_slug(name, neighborhood)

      places_to_create << {
        neighborhood_id: neighborhood.id,
        name: name,
        place_type: element['place_type'],
        lat: lat,
        lon: lon,
        address: address,
        tags: tags,
        booking_url: tags['website'],
        trip_affiliate_url: get_trip_affiliate_url(neighborhood.city),
        agoda_affiliate_url: get_agoda_affiliate_url(neighborhood.city),
        slug: slug,
        city: neighborhood&.city,
        state: neighborhood&.state,
        country: neighborhood&.country,
        continent: neighborhood&.continent,
        created_at: current_time,
        updated_at: current_time
      }
    end

    # Bulk insert for performance (1 query)
    Place.insert_all(places_to_create) if places_to_create.any?
  end

  def filter_elements_by_polygon(neighborhood, elements)
    return [] if elements.empty?

    # Prepare data for query: [lat, lon, index]
    points_with_index = elements.map.with_index do |element, index|
      lat = element['lat'] || element.dig('center', 'lat')
      lon = element['lon'] || element.dig('center', 'lon')
      [lat, lon, index] if lat && lon
    end.compact

    return [] if points_with_index.empty?

    # Construct VALUES clause
    # values_list = "(lat, lon, idx), (lat, lon, idx)..."
    values_list = points_with_index.map { |lat, lon, idx| "(#{lat}, #{lon}, #{idx})" }.join(',')

    sql = <<~SQL
      WITH points (lat, lon, idx) AS (
        VALUES #{values_list}
      )
      SELECT idx
      FROM points
      WHERE ST_Contains(
        (SELECT geom::geometry FROM neighborhoods WHERE id = #{neighborhood.id}),
        ST_SetSRID(ST_Point(lon, lat), 4326)
      )
    SQL

    valid_indices = ActiveRecord::Base.connection.select_values(sql).map(&:to_i)

    elements.values_at(*valid_indices)
  end

  def get_trip_affiliate_url(city_name)
    return nil unless city_name.present?
    @city_trip_url_map[city_name.downcase]
  end

  def get_agoda_affiliate_url(city_name)
    return nil unless city_name.present?
    @city_agoda_url_map[city_name.downcase]
  end

  # Build address string from OSM tags
  def build_address(tags)
    parts = []
    parts << tags['addr:housenumber'] if tags['addr:housenumber']
    parts << tags['addr:street'] if tags['addr:street']
    parts << tags['addr:city'] if tags['addr:city']
    parts.join(', ').presence
  end

  def generate_place_slug(name, neighborhood)
    base_slug = name.to_s.parameterize
    return nil if base_slug.blank?

    # Always append city and neighborhood for better SEO and uniqueness
    city_part = neighborhood&.city&.parameterize || 'unknown'
    neighborhood_part = neighborhood&.name&.parameterize&.first(20) || 'unknown'

    unique_slug = "#{base_slug}-#{city_part}-#{neighborhood_part}"

    counter = 1
    final_slug = unique_slug
    while Place.exists?(slug: final_slug)
      final_slug = "#{unique_slug}-#{counter}"
      counter += 1
    end

    final_slug
  end

end
