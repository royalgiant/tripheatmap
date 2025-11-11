# Service for importing Italian neighborhood boundaries from national GeoJSON dataset
# Filters municipalities by ISTAT PRO_COM codes from the national dataset
#
# Usage:
#   ItalyNeighborhoodImporter.new('verona').import_neighborhoods
#
class ItalyNeighborhoodImporter
  # National Italy municipal boundaries dataset (all 7,904 municipalities)
  NATIONAL_GEOJSON_URL = "https://f005.backblazeb2.com/file/tripheatmap/italy_2019_arcgis.geojson"

  attr_reader :city_key, :config, :errors

  def initialize(city_key)
    @city_key = city_key.to_s.downcase
    @config = load_config
    @errors = []

    raise ArgumentError, "City '#{city_key}' not found in configuration" unless @config
    raise ArgumentError, "City '#{city_key}' is disabled" if @config["enabled"] == false
    raise ArgumentError, "City '#{city_key}' is not configured for Italy (missing istat_code)" unless @config["istat_code"].present?
  end

  # Import neighborhoods for the configured Italian city
  # Returns the number of neighborhoods imported
  def import_neighborhoods
    Rails.logger.info "Importing Italian municipality for #{city_name} (ISTAT: #{istat_code})"

    features = fetch_and_filter_features
    return 0 if features.empty?

    imported_count = 0
    failed_count = 0

    features.each do |feature|
      if import_neighborhood(feature)
        imported_count += 1
      else
        failed_count += 1
      end
    end

    Rails.logger.info "Imported #{imported_count} neighborhoods for #{city_name} (#{failed_count} failed)"
    imported_count
  end

  # Check if a city is configured for Italian import
  def self.available_for_city?(city_key)
    config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    city_config = config[city_key.to_s.downcase]
    city_config &&
      city_config["country"] == "Italy" &&
      city_config["istat_code"].present? &&
      city_config["enabled"] != false
  rescue
    false
  end

  # Get list of all Italian cities
  def self.available_cities
    config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    config.select { |_, v| v["country"] == "Italy" && v["enabled"] != false }.keys
  rescue
    []
  end

  private

  # Get city name from config
  def city_name
    @city_name ||= config['city'] || config['name']
  end

  # Get ISTAT PRO_COM code for filtering
  def istat_code
    @istat_code ||= config['istat_code']
  end

  # Load configuration for the specified city
  def load_config
    all_config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    all_config[city_key]
  end

  # Fetch national GeoJSON and filter for this specific municipality
  def fetch_and_filter_features
    url = NATIONAL_GEOJSON_URL

    begin
      Rails.logger.info "Fetching national Italy GeoJSON from #{url}"
      response = Faraday.get(url) do |req|
        req.options.timeout = 120  # Longer timeout for large national dataset
        req.options.open_timeout = 20
      end

      unless response.success?
        Rails.logger.error "Italy GeoJSON API error: #{response.status} - #{response.body[0..200]}"
        return []
      end

      data = JSON.parse(response.body)
      all_features = data["features"] || []

      Rails.logger.info "Fetched #{all_features.size} total Italian municipalities"

      # Filter features by PRO_COM code matching our ISTAT code
      filtered_features = all_features.select do |feature|
        pro_com = feature.dig("properties", "PRO_COM")
        # Match on last 6 digits (municipal code) since PRO_COM format is PPPCCC
        # where PPP is province code and CCC is municipality code
        pro_com == istat_code
      end

      Rails.logger.info "Filtered to #{filtered_features.size} features matching ISTAT code #{istat_code}"

      if filtered_features.empty?
        Rails.logger.warn "No features found for ISTAT code #{istat_code}. Available PRO_COM codes sample: #{all_features.first(5).map { |f| f.dig('properties', 'PRO_COM') }.inspect}"
      end

      filtered_features
    rescue => e
      Rails.logger.error "Error fetching Italian neighborhoods: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      @errors << e.message
      []
    end
  end

  # Import a single neighborhood feature
  def import_neighborhood(feature)
    props = feature["properties"]
    name_field = config.dig("field_mappings", "name") || "COMUNE"
    geoid_field = config.dig("field_mappings", "geoid") || "PRO_COM"

    name = props[name_field]
    geoid = "IT_#{props[geoid_field]}"  # Prefix with IT_ to distinguish from US GEOIDs

    unless name
      Rails.logger.warn "Municipality missing name field '#{name_field}', skipping"
      return false
    end

    # Skip if already exists
    existing = Neighborhood.find_by(geoid: geoid)
    if existing
      Rails.logger.debug "Municipality #{name} already exists, skipping"
      return false
    end

    # Parse geometry using RGeo
    geojson = feature["geometry"]
    geometry = parse_geometry(geojson)

    unless geometry
      Rails.logger.warn "Failed to parse geometry for municipality #{name}"
      return false
    end

    # Calculate centroid
    centroid = begin
      geometry.centroid_point
    rescue
      geometry.point_on_surface rescue nil
    end

    # Create neighborhood record
    Neighborhood.create!(
      geoid: geoid,
      name: name,
      city: city_name,
      county: config["county"],
      state: config["state"],
      population: nil, # Italian population data would need separate source (ISTAT API)
      geom: geometry,
      centroid: centroid
    )

    Rails.logger.debug "Imported municipality: #{name} (#{geoid})"
    true
  rescue => e
    Rails.logger.error "Error importing municipality #{name}: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    @errors << "Municipality #{name}: #{e.message}"
    false
  end

  # Parse GeoJSON geometry using RGeo
  def parse_geometry(geojson)
    factory = RGeo::Geographic.spherical_factory(srid: 4326)
    geometry = RGeo::GeoJSON.decode(geojson.to_json, geo_factory: factory)

    # Ensure it's a MultiPolygon (convert Polygon to MultiPolygon if needed)
    if geometry.is_a?(RGeo::Geographic::ProjectedPolygonImpl)
      factory.multi_polygon([geometry])
    elsif geometry.is_a?(RGeo::Feature::Polygon)
      factory.multi_polygon([geometry])
    else
      geometry
    end
  rescue => e
    Rails.logger.error "Geometry parse error: #{e.message}"
    nil
  end
end
