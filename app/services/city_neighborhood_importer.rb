# Service for importing city-specific neighborhood boundaries from open data portals
# Uses GeoJSON endpoints configured in config/neighborhood_boundaries.yml
#
# Usage:
#   CityNeighborhoodImporter.new('dallas').import_neighborhoods
#
class CityNeighborhoodImporter
  include ContinentHelper

  attr_reader :city_key, :config, :errors

  def initialize(city_key)
    @city_key = city_key.to_s.downcase
    @config = load_config
    @errors = []

    raise ArgumentError, "City '#{city_key}' not found in configuration" unless @config
    raise ArgumentError, "City '#{city_key}' is disabled" if @config["enabled"] == false
  end

  # Import neighborhoods for the configured city
  # Returns the number of neighborhoods imported
  def import_neighborhoods
    Rails.logger.info "Importing neighborhoods for #{city_name}, #{config['state']}"

    features = fetch_neighborhood_features
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

  # Check if a city has neighborhood boundaries available from a custom endpoint
  # Only returns true if city has an endpoint configured AND is not disabled
  def self.available_for_city?(city_key)
    config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    city_config = config[city_key.to_s.downcase]
    city_config && city_config["endpoint"].present? && city_config["enabled"] != false
  rescue
    false
  end

  # Get list of all cities with neighborhood boundaries
  def self.available_cities
    config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    config.select { |_, v| v["enabled"] != false }.keys
  rescue
    []
  end

  private

  # Get city name from config (supports both 'city' and 'name' fields)
  def city_name
    @city_name ||= config['city'] || config['name']
  end

  # Load configuration for the specified city
  def load_config
    all_config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    all_config[city_key]
  end

  # Fetch neighborhood features from city open data portal
  def fetch_neighborhood_features
    url = config["endpoint"]

    begin
      response = Faraday.get(url) do |req|
        req.options.timeout = 60
        req.options.open_timeout = 10
      end

      unless response.success?
        Rails.logger.error "City open data API error: #{response.status} - #{response.body}"
        return []
      end

      data = JSON.parse(response.body)
      features = data["features"] || []

      Rails.logger.info "Fetched #{features.size} neighborhood features from #{city_name}"
      features
    rescue => e
      Rails.logger.error "Error fetching city neighborhoods: #{e.message}"
      @errors << e.message
      []
    end
  end

  # Import a single neighborhood feature
  def import_neighborhood(feature)
    props = feature["properties"]
    name_field = config.dig("field_mappings", "name")
    geoid_field = config.dig("field_mappings", "geoid")

    name = props[name_field]
    geoid = "#{city_key.upcase}_#{props[geoid_field]}"

    unless name
      Rails.logger.warn "Neighborhood missing name field '#{name_field}', skipping"
      return false
    end

    # Skip if already exists
    existing = Neighborhood.find_by(geoid: geoid)
    if existing
      Rails.logger.debug "Neighborhood #{name} already exists, skipping"
      return false
    end

    # Parse geometry using RGeo
    geojson = feature["geometry"]
    geometry = parse_geometry(geojson)

    unless geometry
      Rails.logger.warn "Failed to parse geometry for neighborhood #{name}"
      return false
    end

    # Calculate centroid (use point_on_surface as fallback for complex geometries)
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
      country: config["country"],
      continent: determine_continent(config["country"]),
      population: nil, # Will need to be populated from census data later
      geom: geometry,
      centroid: centroid
    )

    Rails.logger.debug "Imported neighborhood: #{name}"
    true
  rescue => e
    Rails.logger.error "Error importing neighborhood #{name}: #{e.message}"
    @errors << "Neighborhood #{name}: #{e.message}"
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
