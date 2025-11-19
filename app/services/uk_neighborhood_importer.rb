# Service for importing UK neighborhood boundaries (wards) from GADM Level 4 dataset
# Filters wards by NAME_3 (parent city/district name) from the national dataset
#
# Usage:
#   UkNeighborhoodImporter.new('london').import_neighborhoods
#
class UkNeighborhoodImporter
  NATIONAL_GEOJSON_URL = "https://tripheatmap.s3.us-east-005.backblazeb2.com/UK_GBR_4.json"

  attr_reader :city_key, :config, :errors

  def initialize(city_key)
    @city_key = city_key.to_s.downcase
    @config = load_config
    @errors = []

    raise ArgumentError, "City '#{city_key}' not found in configuration" unless @config
    raise ArgumentError, "City '#{city_key}' is disabled" if @config["enabled"] == false
    raise ArgumentError, "City '#{city_key}' is not configured for UK (missing parent_name field mapping)" unless parent_name_field.present?
  end

  # Import neighborhoods for the configured UK city
  # Returns the number of neighborhoods imported
  def import_neighborhoods
    Rails.logger.info "Importing UK wards for #{city_name}"

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

    Rails.logger.info "Imported #{imported_count} wards for #{city_name} (#{failed_count} failed)"
    imported_count
  end

  # Check if a city is configured for UK import
  def self.available_for_city?(city_key)
    config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    city_config = config[city_key.to_s.downcase]
    city_config &&
      city_config["country"] == "United Kingdom" &&
      city_config.dig("field_mappings", "parent_name").present? &&
      city_config["enabled"] != false
  rescue
    false
  end

  # Get list of all UK cities
  def self.available_cities
    config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    config.select { |_, v| v["country"] == "United Kingdom" && v["enabled"] != false }.keys
  rescue
    []
  end

  private

  # Get city name from config
  def city_name
    @city_name ||= config['city'] || config['name']
  end

  # Get the parent name field for filtering (NAME_3 in GADM)
  def parent_name_field
    @parent_name_field ||= config.dig("field_mappings", "parent_name")
  end

  # Get expected parent city name(s) for filtering
  # Returns an array to handle city name variations
  def expected_parent_names
    @expected_parent_names ||= begin
      configured = Array(config["parent_names"]).map(&:to_s).reject(&:blank?)
      return configured if configured.present?

      # Start with the configured city name
      names = [city_name]

      # Add common variations
      case city_key
      when 'bristol'
        names << 'Bristol, City of'
      when 'glasgow'
        names << 'Glasgow City'
      when 'edinburgh'
        names << 'City of Edinburgh'
      when 'london'
        # London wards might be under individual borough names
        # We'll need to check the actual data structure
        names
      end

      names
    end
  end

  # Load configuration for the specified city
  def load_config
    all_config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    all_config[city_key]
  end

  # Fetch national GeoJSON and filter for this specific city's wards
  def fetch_and_filter_features
    url = NATIONAL_GEOJSON_URL

    begin
      Rails.logger.info "Fetching UK national GeoJSON from #{url}"
      response = Faraday.get(url) do |req|
        req.options.timeout = 120  # Longer timeout for large national dataset
        req.options.open_timeout = 20
      end

      unless response.success?
        Rails.logger.error "UK GeoJSON error: #{response.status} - #{response.body[0..200]}"
        return []
      end

      data = JSON.parse(response.body)
      all_features = data["features"] || []

      Rails.logger.info "Fetched #{all_features.size} total UK wards"

      # Filter features by NAME_3 matching our city
      filtered_features = all_features.select do |feature|
        parent_name = feature.dig("properties", parent_name_field)
        expected_parent_names.any? { |expected| parent_name&.downcase&.include?(expected.downcase) }
      end

      Rails.logger.info "Filtered to #{filtered_features.size} wards for #{city_name}"

      if filtered_features.empty?
        # Sample NAME_3 values to help debug
        sample_names = all_features.first(10).map { |f| f.dig('properties', parent_name_field) }.uniq
        Rails.logger.warn "No wards found for #{city_name}. Sample NAME_3 values: #{sample_names.inspect}"
      end

      filtered_features
    rescue => e
      Rails.logger.error "Error fetching UK neighborhoods: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      @errors << e.message
      []
    end
  end

  # Import a single neighborhood (ward) feature
  def import_neighborhood(feature)
    props = feature["properties"]
    name_field = config.dig("field_mappings", "name") || "NAME_4"
    geoid_field = config.dig("field_mappings", "geoid") || "GID_4"

    name = props[name_field]
    raw_geoid = props[geoid_field]
    geoid = "UK_#{raw_geoid}"  # Prefix with UK_ to distinguish from US GEOIDs

    unless name
      Rails.logger.warn "Ward missing name field '#{name_field}', skipping"
      return false
    end

    # Skip if already exists
    existing = Neighborhood.find_by(geoid: geoid)
    if existing
      Rails.logger.debug "Ward #{name} already exists, skipping"
      return false
    end

    # Parse geometry using RGeo
    geojson = feature["geometry"]
    geometry = parse_geometry(geojson)

    unless geometry
      Rails.logger.warn "Failed to parse geometry for ward #{name}"
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
      population: nil, # UK population data would need separate source (ONS)
      geom: geometry,
      centroid: centroid
    )

    Rails.logger.debug "Imported ward: #{name} (#{geoid})"
    true
  rescue => e
    Rails.logger.error "Error importing ward #{name}: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    @errors << "Ward #{name}: #{e.message}"
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
