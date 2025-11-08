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
    counts = query_amenities(bounds)

    return false unless counts

    # Calculate total and vibrancy index
    total = counts.values.sum
    vibrancy_index = calculate_vibrancy_index(counts, neighborhood)

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
end
