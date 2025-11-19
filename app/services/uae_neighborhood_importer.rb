# Service for importing UAE neighborhood boundaries from GADM Level 3 dataset
# Filters neighborhoods by emirate/city name from the national dataset
#
# Usage:
#   UaeNeighborhoodImporter.new('dubai').import_neighborhoods
#
class UaeNeighborhoodImporter
  NATIONAL_GEOJSON_URL = "https://tripheatmap.s3.us-east-005.backblazeb2.com/UAE_L3.json"

  attr_reader :city_key, :config, :errors

  def initialize(city_key)
    @city_key = city_key.to_s.downcase
    @config = load_config
    @errors = []

    raise ArgumentError, "City '#{city_key}' not found in configuration" unless @config
    raise ArgumentError, "City '#{city_key}' is disabled" if @config["enabled"] == false
    raise ArgumentError, "City '#{city_key}' is not configured for UAE (missing parent_name field mapping)" unless parent_name_field.present?
  end

  # Import neighborhoods for the configured UAE city
  # Returns the number of neighborhoods imported
  def import_neighborhoods
    Rails.logger.info "Importing UAE neighborhoods for #{city_name}"

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

  # Check if a city is configured for UAE import
  def self.available_for_city?(city_key)
    config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    city_config = config[city_key.to_s.downcase]
    city_config &&
      city_config["country"] == "United Arab Emirates" &&
      city_config.dig("field_mappings", "parent_name").present? &&
      city_config["enabled"] != false
  rescue
    false
  end

  # Get list of all UAE cities
  def self.available_cities
    config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    config.select { |_, v| v["country"] == "United Arab Emirates" && v["enabled"] != false }.keys
  rescue
    []
  end

  private

  # Get city name from config
  def city_name
    @city_name ||= config['city'] || config['name']
  end

  # Get the parent name field for filtering
  def parent_name_field
    @parent_name_field ||= config.dig("field_mappings", "parent_name")
  end

  # Get expected parent emirate/city name(s) for filtering
  # Returns an array to handle name variations
  def expected_parent_names
    @expected_parent_names ||= begin
      names = [city_name, config['state']]

      # Add common variations
      case city_key
      when 'dubai'
        names << 'Dubai' << 'Dubayy'
      when 'abu dhabi'
        names << 'Abu Dhabi' << 'Abu Zaby'
      end

      names.compact.uniq
    end
  end

  # Load configuration for the specified city
  def load_config
    all_config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    all_config[city_key]
  end

  # Fetch national GeoJSON and filter for this specific city's neighborhoods
  def fetch_and_filter_features
    url = NATIONAL_GEOJSON_URL

    begin
      Rails.logger.info "Fetching UAE national GeoJSON from #{url}"
      response = Faraday.get(url) do |req|
        req.options.timeout = 120
        req.options.open_timeout = 20
      end

      unless response.success?
        Rails.logger.error "UAE GeoJSON error: #{response.status} - #{response.body[0..200]}"
        return []
      end

      data = JSON.parse(response.body)
      all_features = data["features"] || []

      Rails.logger.info "Fetched #{all_features.size} total UAE neighborhoods"

      # Filter features by parent name matching our city/emirate
      filtered_features = all_features.select do |feature|
        parent_name = feature.dig("properties", parent_name_field)
        expected_parent_names.any? { |expected| parent_name&.downcase&.include?(expected.downcase) }
      end

      Rails.logger.info "Filtered to #{filtered_features.size} neighborhoods for #{city_name}"

      if filtered_features.empty?
        # Sample parent name values to help debug
        sample_names = all_features.first(10).map { |f| f.dig('properties', parent_name_field) }.uniq
        Rails.logger.warn "No neighborhoods found for #{city_name}. Sample parent values: #{sample_names.inspect}"
      end

      filtered_features
    rescue => e
      Rails.logger.error "Error fetching UAE neighborhoods: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      @errors << e.message
      []
    end
  end

  # Import a single neighborhood feature
  def import_neighborhood(feature)
    props = feature["properties"]
    name_field = config.dig("field_mappings", "name") || "NAME_3"
    geoid_field = config.dig("field_mappings", "geoid") || "GID_3"

    name = props[name_field] || props["shapeName"]
    raw_geoid = props[geoid_field] || props["shapeID"]
    geoid = "AE_#{raw_geoid}"  # Prefix with AE_ (ISO code for UAE) to distinguish from other countries

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
      population: nil, # UAE population data would need separate source
      geom: geometry,
      centroid: centroid
    )

    Rails.logger.debug "Imported neighborhood: #{name} (#{geoid})"
    true
  rescue => e
    Rails.logger.error "Error importing neighborhood #{name}: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
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
