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
    bar: 'bar'
  }.freeze

  def initialize
    @errors = []
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

    # Calculate total and vibrancy index
    total = counts.values.sum
    vibrancy_index = calculate_vibrancy_index(counts, neighborhood)

    # Calculate vibrancy densities (amenities per km²)
    area_sq_km = get_area_sq_km(neighborhood)
    densities = calculate_densities(counts, area_sq_km)

    # Create or update stats
    stat = neighborhood.neighborhood_places_stat || neighborhood.build_neighborhood_places_stat
    stat.update!(
      restaurant_count: counts[:restaurant],
      cafe_count: counts[:cafe],
      bar_count: counts[:bar],
      total_amenities: total,
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

    query_parts = AMENITIES.values.flat_map do |amenity|
      [
        "node[\"amenity\"=\"#{amenity}\"](#{bbox});",
        "way[\"amenity\"=\"#{amenity}\"](#{bbox});"
      ]
    end

    <<~QUERY
      [out:json][timeout:25];
      (
        #{query_parts.join("\n  ")}
      );
      out center tags;
    QUERY
  end

  # Parse amenities from Overpass response
  # Returns both counts and full elements with coordinates
  def parse_amenities(data)
    counts = { restaurant: 0, cafe: 0, bar: 0 }
    elements = []

    return { counts: counts, elements: elements } unless data['elements']

    data['elements'].each do |element|
      amenity = element.dig('tags', 'amenity')
      next unless amenity

      # Normalize place type (bar/pub -> bar)
      place_type = case amenity
                   when 'restaurant' then 'restaurant'
                   when 'cafe' then 'cafe'
                   when 'bar', 'pub' then 'bar'
                   else next
                   end

      # Update counts
      counts[place_type.to_sym] += 1

      # Add to elements array with normalized type
      elements << element.merge('place_type' => place_type)
    end

    { counts: counts, elements: elements }
  end

  # Save individual places to database
  # Uses 2 queries total: 1 DELETE + 1 bulk INSERT
  def save_places(neighborhood, elements)
    # Hard delete existing places for this neighborhood (1 query)
    Place.where(neighborhood_id: neighborhood.id).delete_all

    return if elements.empty?

    places_to_create = []
    current_time = Time.current

    elements.each do |element|
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

      places_to_create << {
        neighborhood_id: neighborhood.id,
        name: name,
        place_type: element['place_type'],
        lat: lat,
        lon: lon,
        address: address,
        tags: tags,
        created_at: current_time,
        updated_at: current_time
      }
    end

    # Bulk insert for performance (1 query)
    Place.insert_all(places_to_create) if places_to_create.any?
  end

  # Build address string from OSM tags
  def build_address(tags)
    parts = []
    parts << tags['addr:housenumber'] if tags['addr:housenumber']
    parts << tags['addr:street'] if tags['addr:street']
    parts << tags['addr:city'] if tags['addr:city']
    parts.join(', ').presence
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
  # Returns hash with :restaurants, :cafes, :bars vibrancy (per km²)
  def calculate_densities(counts, area_sq_km)
    if area_sq_km.nil? || area_sq_km <= 0
      return {
        restaurants: 0.0,
        cafes: 0.0,
        bars: 0.0
      }
    end

    {
      restaurants: (counts[:restaurant].to_f / area_sq_km).round(3),
      cafes: (counts[:cafe].to_f / area_sq_km).round(3),
      bars: (counts[:bar].to_f / area_sq_km).round(3)
    }
  end
end
