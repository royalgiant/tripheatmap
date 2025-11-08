# Service to enrich census tract names with actual neighborhood names
# Uses Nominatim (OpenStreetMap) reverse geocoding to get neighborhood names
#
# Usage:
#   NeighborhoodNameEnricher.new.enrich_city('dallas')
#   NeighborhoodNameEnricher.new.enrich_neighborhood(neighborhood)
#
class NeighborhoodNameEnricher
  NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"

  # Nominatim rate limit: 1 request per second
  RATE_LIMIT_DELAY = 1.1 # seconds

  attr_reader :errors

  def initialize
    @errors = []
    @last_request_time = nil
  end

  # Enrich all census tract neighborhoods in a city with actual neighborhood names
  def enrich_city(city_name)
    normalized_city = city_name.to_s.downcase
    # Only process census tracts (those starting with "Tract" or "Census Tract")
    neighborhoods = Neighborhood.for_city(normalized_city)
      .where("name LIKE ? OR name LIKE ?", "Tract %", "%Census Tract%")

    total = neighborhoods.count
    puts "Enriching #{total} census tracts in #{city_name} with neighborhood names..."

    success_count = 0
    neighborhoods.each_with_index do |neighborhood, index|
      if enrich_neighborhood(neighborhood)
        success_count += 1
      end
      print "\rProcessed: #{index + 1}/#{total}" if (index + 1) % 10 == 0
    end

    puts "\n✅ Successfully enriched #{success_count}/#{total} neighborhoods"
    puts "❌ Errors: #{@errors.size}" if @errors.any?
    @errors.each { |err| puts "  - #{err}" }

    success_count
  end

  # Get neighborhood name for a single neighborhood using reverse geocoding
  def enrich_neighborhood(neighborhood)
    return false unless neighborhood.centroid

    # Extract lat/lon from centroid
    lat = neighborhood.centroid.y
    lon = neighborhood.centroid.x

    # Get neighborhood name from Nominatim
    hood_name = reverse_geocode(lat, lon)

    if hood_name
      neighborhood.update!(name: hood_name)
      Rails.logger.debug "Updated #{neighborhood.geoid}: #{hood_name}"
      true
    else
      @errors << "No neighborhood name found for #{neighborhood.name}"
      false
    end
  rescue => e
    @errors << "Neighborhood #{neighborhood.name}: #{e.message}"
    false
  end

  # Get neighborhood name from coordinates without updating database
  # Returns the neighborhood name or nil
  def self.get_neighborhood_name(lat, lon)
    enricher = new
    enricher.send(:reverse_geocode, lat, lon)
  end

  private

  # Reverse geocode coordinates to get neighborhood name
  # Returns the most specific neighborhood/suburb name available
  def reverse_geocode(lat, lon)
    respect_rate_limit

    params = {
      lat: lat,
      lon: lon,
      format: 'json',
      addressdetails: 1,
      zoom: 16, # neighborhood level
      'accept-language': 'en'
    }

    response = Faraday.get(NOMINATIM_URL, params) do |req|
      req.headers['User-Agent'] = 'NeighborhoodVibrancyMap/1.0'
      req.options.timeout = 10
    end

    unless response.success?
      Rails.logger.error "Nominatim error: #{response.status}"
      return nil
    end

    data = JSON.parse(response.body)
    extract_neighborhood_name(data)
  rescue Faraday::Error => e
    Rails.logger.error "Nominatim request failed: #{e.message}"
    nil
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse Nominatim response: #{e.message}"
    nil
  end

  # Extract the best neighborhood name from Nominatim response
  # Priority: neighbourhood > suburb > city_district > hamlet > quarter
  def extract_neighborhood_name(data)
    address = data['address']
    return nil unless address

    # Try different address components in order of specificity
    [
      address['neighbourhood'],
      address['suburb'],
      address['city_district'],
      address['hamlet'],
      address['quarter'],
      address['residential']
    ].compact.first
  end

  # Respect Nominatim rate limit (1 request/second)
  def respect_rate_limit
    if @last_request_time
      time_since_last = Time.now - @last_request_time
      if time_since_last < RATE_LIMIT_DELAY
        sleep(RATE_LIMIT_DELAY - time_since_last)
      end
    end
    @last_request_time = Time.now
  end
end
