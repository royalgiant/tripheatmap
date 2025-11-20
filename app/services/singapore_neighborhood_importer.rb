# Service for importing Singapore neighborhood boundaries from GADM ADM2 dataset
# Singapore is a city-state, so we import all planning areas/subzones
#
# Usage:
#   SingaporeNeighborhoodImporter.new('singapore').import_neighborhoods
#
class SingaporeNeighborhoodImporter
  include ContinentHelper
  NATIONAL_GEOJSON_URL = "https://tripheatmap.s3.us-east-005.backblazeb2.com/Singapore_ADM2_simplified.simplified.geojson"

  attr_reader :city_key, :config, :errors

  def initialize(city_key)
    @city_key = city_key.to_s.downcase
    @config = load_config
    @errors = []

    raise ArgumentError, "City '#{city_key}' not found in configuration" unless @config
    raise ArgumentError, "City '#{city_key}' is disabled" if @config["enabled"] == false
    raise ArgumentError, "City '#{city_key}' is not configured for Singapore" unless @config["country"] == "Singapore"
  end

  # Import neighborhoods for Singapore
  # Returns the number of neighborhoods imported
  def import_neighborhoods
    Rails.logger.info "Importing Singapore planning areas/subzones"

    features = fetch_features
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

    Rails.logger.info "Imported #{imported_count} planning areas for Singapore (#{failed_count} failed)"
    imported_count
  end

  # Check if Singapore is configured
  def self.available_for_city?(city_key)
    config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    city_config = config[city_key.to_s.downcase]
    city_config &&
      city_config["country"] == "Singapore" &&
      city_config["enabled"] != false
  rescue
    false
  end

  # Get list of Singapore (only one city)
  def self.available_cities
    config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    config.select { |_, v| v["country"] == "Singapore" && v["enabled"] != false }.keys
  rescue
    []
  end

  private

  # Get city name from config
  def city_name
    @city_name ||= config['city'] || config['name']
  end

  # Load configuration for the specified city
  def load_config
    all_config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    all_config[city_key]
  end

  # Fetch GeoJSON for Singapore (no filtering needed as it's a city-state)
  def fetch_features
    url = NATIONAL_GEOJSON_URL

    begin
      Rails.logger.info "Fetching Singapore GeoJSON from #{url}"
      response = Faraday.get(url) do |req|
        req.options.timeout = 120
        req.options.open_timeout = 20
      end

      unless response.success?
        Rails.logger.error "Singapore GeoJSON error: #{response.status} - #{response.body[0..200]}"
        return []
      end

      data = JSON.parse(response.body)
      all_features = data["features"] || []

      Rails.logger.info "Fetched #{all_features.size} total Singapore planning areas/subzones"

      all_features
    rescue => e
      Rails.logger.error "Error fetching Singapore neighborhoods: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      @errors << e.message
      []
    end
  end

  # Import a single neighborhood (planning area/subzone) feature
  def import_neighborhood(feature)
    props = feature["properties"]
    name_field = config.dig("field_mappings", "name") || "NAME_2"
    geoid_field = config.dig("field_mappings", "geoid") || "GID_2"

    name = props[name_field] || props["shapeName"]
    raw_geoid = props[geoid_field] || props["shapeID"]
    geoid = "SG_#{raw_geoid}"  # Prefix with SG_ to distinguish from other countries

    unless name
      Rails.logger.warn "Planning area missing name field '#{name_field}', skipping"
      return false
    end

    # Skip if already exists
    existing = Neighborhood.find_by(geoid: geoid)
    if existing
      Rails.logger.debug "Planning area #{name} already exists, skipping"
      return false
    end

    # Parse geometry using RGeo
    geojson = feature["geometry"]
    geometry = parse_geometry(geojson)

    unless geometry
      Rails.logger.warn "Failed to parse geometry for planning area #{name}"
      return false
    end

    # Calculate centroid
    centroid = begin
      geometry.centroid
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
      population: nil, # Singapore population data would need separate source
      geom: geometry,
      centroid: centroid
    )

    Rails.logger.debug "Imported planning area: #{name} (#{geoid})"
    true
  rescue => e
    Rails.logger.error "Error importing planning area #{name}: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    @errors << "Planning area #{name}: #{e.message}"
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
