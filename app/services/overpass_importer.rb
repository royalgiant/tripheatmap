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
    neighborhoods = Neighborhood.where(city: city_name).with_geom
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
    counts = query_amenities(bounds)

    return false unless counts

    # Calculate total and vibrancy index
    total = counts.values.sum
    vibrancy_index = calculate_vibrancy_index(counts, neighborhood.population)

    # Create or update stats
    stat = neighborhood.neighborhood_places_stat || neighborhood.build_neighborhood_places_stat
    stat.update!(
      restaurant_count: counts[:restaurant],
      cafe_count: counts[:cafe],
      bar_count: counts[:bar],
      total_amenities: total,
      vibrancy_index: vibrancy_index,
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

  # Query Overpass API for amenity counts
  def query_amenities(bounds)
    query = build_overpass_query(bounds)

    response = Faraday.post(OVERPASS_API_URL, query, { 'Content-Type' => 'text/plain' })

    unless response.success?
      Rails.logger.error "Overpass API error: #{response.status}"
      return nil
    end

    data = JSON.parse(response.body)
    parse_counts(data)
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
      out tags;
    QUERY
  end

  # Parse counts from Overpass response
  def parse_counts(data)
    counts = { restaurant: 0, cafe: 0, bar: 0 }

    return counts unless data['elements']

    data['elements'].each do |element|
      amenity = element.dig('tags', 'amenity')
      next unless amenity

      case amenity
      when 'restaurant'
        counts[:restaurant] += 1
      when 'cafe'
        counts[:cafe] += 1
      when 'bar', 'pub'  # OSM uses 'bar' and 'pub'
        counts[:bar] += 1
      end
    end

    counts
  end

  # Calculate vibrancy index (0-10 scale)
  # Based on amenities per 1,000 residents
  def calculate_vibrancy_index(counts, population)
    return 0 if population.nil? || population <= 0

    total_amenities = counts.values.sum
    amenities_per_1k = (total_amenities.to_f / population) * 1000

    # Scale to 0-10 range
    # Assuming 20 amenities per 1k residents = very vibrant (10)
    # Anything above 20 is capped at 10
    index = (amenities_per_1k / 20.0) * 10
    [[index, 0].max, 10].min
  end
end
