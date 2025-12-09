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
    @city_configs = YAML.load_file(Rails.root.join('config', 'neighborhood_boundaries.yml'))
    
    # Pre-compute city URL map for O(1) lookup
    @city_url_map = {}
    @city_configs.each do |_key, config|
      next unless config['tripcomurl'].present?
      @city_url_map[config['city'].to_s.downcase] = config['tripcomurl'] if config['city']
      @city_url_map[config['name'].to_s.downcase] = config['tripcomurl'] if config['name']
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

    vibrancy_index = calculate_vibrancy_index(counts, neighborhood)

    # Calculate vibrancy densities (amenities per km²)
    area_sq_km = get_area_sq_km(neighborhood)
    densities = calculate_densities(counts, area_sq_km)
    
    # Calculate total accommodations
    total_accommodations = counts[:hotel] + counts[:hostel]

    # Create or update stats
    stat = neighborhood.neighborhood_places_stat || neighborhood.build_neighborhood_places_stat
    stat.update!(
      restaurant_count: counts[:restaurant],
      cafe_count: counts[:cafe],
      bar_count: counts[:bar],
      hotel_count: counts[:hotel],
      hostel_count: counts[:hostel],
      total_accommodations: total_accommodations,
      total_amenities: counts[:restaurant] + counts[:cafe] + counts[:bar],
      vibrancy_index: vibrancy_index,
      restaurants_vibrancy: densities[:restaurants],
      cafes_vibrancy: densities[:cafes],
      bars_vibrancy: densities[:bars],
      last_updated: Time.current
    )

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
    @city_url_map[city_name.downcase]
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

  # Calculate vibrancy index (0-10 scale)
  # Combines density, diversity, and volume for a holistic vibrancy score
  #
  # Formula:
  #   vibrancy = (0.5 * density_factor) + (0.3 * diversity_factor) + (0.2 * volume_factor)
  #
  # Where:
  #   - density_factor: Amenities per km², capped at 100/km² = full vibrancy
  #   - diversity_factor: Mix of restaurant/cafe/bar types (Shannon entropy)
  #   - volume_factor: Absolute count with diminishing returns
  #
  def calculate_vibrancy_index(counts, neighborhood)
    total_amenities = counts.values.sum
    return 0 if total_amenities == 0

    # Get area in square kilometers
    area_sq_km = get_area_sq_km(neighborhood)

    # Step 1: Density Factor (0-1)
    # Adaptive saturation point based on neighborhood size
    # Smaller areas (compact urban) need higher saturation
    # Larger areas (suburban census tracts) need lower saturation
    density_factor = if area_sq_km && area_sq_km > 0
      density = total_amenities.to_f / area_sq_km

      # Adaptive saturation: smaller areas = higher threshold
      # < 0.5 km² (micro neighborhood): 150/km² saturation
      # 0.5-2 km² (compact urban): 80/km² saturation
      # 2-5 km² (standard tract): 40/km² saturation
      # 5+ km² (large suburban): 20/km² saturation
      saturation = case area_sq_km
                   when 0...0.5 then 150.0
                   when 0.5...2.0 then 80.0
                   when 2.0...5.0 then 40.0
                   else 20.0
                   end

      [density / saturation, 1.0].min  # Cap at 1.0
    else
      # For missing/invalid areas, use a moderate default
      0.5
    end

    # Step 2: Diversity Factor (0-1)
    # Rewards balanced mix of restaurant, cafe, bar
    # Uses Shannon entropy normalized to 0-1 range
    diversity_factor = calculate_diversity_factor(counts)

    # Step 3: Volume Factor (0-1)
    # Rewards total count with diminishing returns
    # Prevents tiny neighborhoods from maxing out with just a few venues
    volume_factor = 1 - Math.exp(-total_amenities / 20.0)

    # Step 4: Weighted Combination (0-10 scale)
    # Weights adjusted for census tracts (larger areas):
    # 40% density, 30% volume, 30% diversity
    vibrancy_index = (
      (0.4 * density_factor) +
      (0.3 * volume_factor) +
      (0.3 * diversity_factor)
    ) * 10.0

    vibrancy_index.round(2)
  end

  # Calculate diversity factor using Shannon entropy
  # Returns 0 for single type, up to 1.0 for evenly mixed
  def calculate_diversity_factor(counts)
    total = counts.values.sum.to_f
    return 0 if total == 0

    # Calculate Shannon entropy
    entropy = counts.values.reduce(0) do |sum, count|
      next sum if count == 0
      share = count / total
      sum - (share * Math.log(share))
    end

    # Normalize to 0-1 range
    # Max entropy for 3 categories = ln(3) ≈ 1.099
    max_entropy = Math.log(3)
    (entropy / max_entropy).round(3)
  end

  # Get neighborhood area in square kilometers
  def get_area_sq_km(neighborhood)
    result = ActiveRecord::Base.connection.execute("
      SELECT ST_Area(geom::geography) / 1000000.0 as area_sq_km
      FROM neighborhoods
      WHERE id = #{neighborhood.id}
    ").first

    result['area_sq_km'].to_f
  rescue => e
    Rails.logger.error "Failed to calculate area for neighborhood #{neighborhood.id}: #{e.message}"
    nil
  end

  # Calculate amenity densities per km²
  # Returns hash with :restaurants, :cafes, :bars, :hotels, :hostels vibrancy (per km²)
  def calculate_densities(counts, area_sq_km)
    if area_sq_km.nil? || area_sq_km <= 0
      return {
        restaurants: 0.0,
        cafes: 0.0,
        bars: 0.0,
        hotels: 0.0,
        hostels: 0.0
      }
    end

    {
      restaurants: (counts[:restaurant].to_f / area_sq_km).round(3),
      cafes: (counts[:cafe].to_f / area_sq_km).round(3),
      bars: (counts[:bar].to_f / area_sq_km).round(3),
      hotels: (counts[:hotel].to_f / area_sq_km).round(3),
      hostels: (counts[:hostel].to_f / area_sq_km).round(3)
    }
  end
end
