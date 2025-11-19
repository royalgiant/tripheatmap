# Service for importing Canadian neighborhood boundaries from GADM ADM3 dataset
# Filters neighborhoods/subdivisions by NAME_2 (city/municipality) from the national dataset
#
# Usage:
#   CanadaNeighborhoodImporter.new('toronto').import_neighborhoods
#
class CanadaNeighborhoodImporter
  NATIONAL_GEOJSON_URL = "https://tripheatmap.s3.us-east-005.backblazeb2.com/Canada_ADM3_simplified.simplified.geojson"

  attr_reader :city_key, :config, :errors

  def initialize(city_key)
    @city_key = city_key.to_s.downcase
    @config = load_config
    @errors = []

    raise ArgumentError, "City '#{city_key}' not found in configuration" unless @config
    raise ArgumentError, "City '#{city_key}' is disabled" if @config["enabled"] == false
    unless parent_name_field.present? || bounding_box.present?
      raise ArgumentError,
            "City '#{city_key}' is not configured for Canada (missing parent_name field mapping or bounding box filter)"
    end
  end

  # Import neighborhoods for the configured Canadian city
  # Returns the number of neighborhoods imported
  def import_neighborhoods
    Rails.logger.info "Importing Canadian subdivisions for #{city_name}"

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

    Rails.logger.info "Imported #{imported_count} subdivisions for #{city_name} (#{failed_count} failed)"
    imported_count
  end

  # Check if a city is configured for Canada import
  def self.available_for_city?(city_key)
    config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    city_config = config[city_key.to_s.downcase]
    return false unless city_config &&
                        city_config["country"] == "Canada" &&
                        city_config["enabled"] != false

    city_config.dig("field_mappings", "parent_name").present? ||
      city_config.dig("filters", "bbox").present?
  rescue
    false
  end

  # Get list of all Canadian cities
  def self.available_cities
    config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    config.select { |_, v| v["country"] == "Canada" && v["enabled"] != false }.keys
  rescue
    []
  end

  private

  # Get city name from config
  def city_name
    @city_name ||= config['city'] || config['name']
  end

  # Get the parent name field for filtering (NAME_2 for municipality in GADM)
  def parent_name_field
    @parent_name_field ||= config.dig("field_mappings", "parent_name")
  end

  # Get expected parent city/municipality name(s) for filtering
  # Returns an array to handle name variations
  def expected_parent_names
    @expected_parent_names ||= begin
      names = [city_name]

      # Add common variations
      case city_key
      when 'toronto'
        names << 'Toronto'
      when 'vancouver'
        names << 'Vancouver'
      when 'montreal'
        names << 'Montréal' << 'Montreal'
      when 'calgary'
        names << 'Calgary'
      when 'ottawa'
        names << 'Ottawa'
      when 'edmonton'
        names << 'Edmonton'
      end

      names.compact.uniq
    end
  end

  def bounding_box
    return @bounding_box if defined?(@bounding_box)

    raw = config.dig("filters", "bbox")
    @bounding_box = if raw
      {
        min_lat: raw["min_lat"] || raw[:min_lat],
        max_lat: raw["max_lat"] || raw[:max_lat],
        min_lon: raw["min_lon"] || raw[:min_lon],
        max_lon: raw["max_lon"] || raw[:max_lon]
      }.transform_values { |val| val.nil? ? nil : val.to_f }
    end
  end

  # Load configuration for the specified city
  def load_config
    all_config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    all_config[city_key]
  end

  # Fetch national GeoJSON and filter for this specific city's subdivisions
  def fetch_and_filter_features
    url = NATIONAL_GEOJSON_URL

    begin
      Rails.logger.info "Fetching Canadian national GeoJSON from #{url}"
      response = Faraday.get(url) do |req|
        req.options.timeout = 120
        req.options.open_timeout = 20
      end

      unless response.success?
        Rails.logger.error "Canada GeoJSON error: #{response.status} - #{response.body[0..200]}"
        return []
      end

      data = JSON.parse(response.body)
      all_features = data["features"] || []

      Rails.logger.info "Fetched #{all_features.size} total Canadian subdivisions"

      if bounding_box.present?
        filter_features_by_bbox(all_features)
      else
        filter_features_by_parent(all_features)
      end
    rescue => e
      Rails.logger.error "Error fetching Canadian neighborhoods: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      @errors << e.message
      []
    end
  end

  def filter_features_by_parent(all_features)
    filtered_features = all_features.select do |feature|
      parent_name = feature.dig("properties", parent_name_field)
      expected_parent_names.any? { |expected| parent_name&.downcase&.include?(expected.downcase) }
    end

    Rails.logger.info "Filtered to #{filtered_features.size} subdivisions for #{city_name}"

    if filtered_features.empty?
      sample_names = all_features.first(10).map { |f| f.dig('properties', parent_name_field) }.uniq
      Rails.logger.warn "No subdivisions found for #{city_name}. Sample #{parent_name_field} values: #{sample_names.inspect}"
    end

    filtered_features
  end

  def filter_features_by_bbox(all_features)
    box = bounding_box
    return [] unless box

    filtered = all_features.select do |feature|
      geometry_overlaps_bbox?(feature["geometry"], box)
    end

    Rails.logger.info "Filtered to #{filtered.size} subdivisions for #{city_name} using bounding box #{box.inspect}"

    if filtered.empty?
      sample_names = all_features.first(10).map { |f| f.dig("properties", config.dig("field_mappings", "name")) || f.dig("properties", "shapeName") }
      Rails.logger.warn "No subdivisions found for #{city_name}. Check bounding box #{box.inspect}. Sample names: #{sample_names.inspect}"
    end

    filtered
  end

  def geometry_overlaps_bbox?(geometry, box)
    coords = extract_coordinates(geometry)
    return false if coords.empty?

    coords.any? do |lon, lat|
      next false unless lon && lat

      lon >= box[:min_lon] && lon <= box[:max_lon] &&
        lat >= box[:min_lat] && lat <= box[:max_lat]
    end
  end

  def extract_coordinates(geometry)
    coords = []
    append_coords(geometry["coordinates"], coords)
    coords
  end

  def append_coords(value, coords)
    return unless value.is_a?(Array)

    if value.first.is_a?(Numeric)
      coords << value
    else
      value.each { |child| append_coords(child, coords) }
    end
  end

  # Import a single neighborhood feature
  def import_neighborhood(feature)
    props = feature["properties"]
    name_field = config.dig("field_mappings", "name") || "NAME_3"
    geoid_field = config.dig("field_mappings", "geoid") || "GID_3"

    name = props[name_field] || props["shapeName"]
    raw_geoid = props[geoid_field] || props["shapeID"]
    geoid = "CA_#{raw_geoid}"  # Prefix with CA_ to distinguish from other countries

    unless name
      Rails.logger.warn "Subdivision missing name field '#{name_field}', skipping"
      return false
    end

    # Skip if already exists
    existing = Neighborhood.find_by(geoid: geoid)
    if existing
      Rails.logger.debug "Subdivision #{name} already exists, skipping"
      return false
    end

    # Parse geometry using RGeo
    geojson = feature["geometry"]
    geometry = parse_geometry(geojson)

    unless geometry
      Rails.logger.warn "Failed to parse geometry for subdivision #{name}"
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
      population: nil, # Canadian population data would need separate source (StatCan)
      geom: geometry,
      centroid: centroid
    )

    Rails.logger.debug "Imported subdivision: #{name} (#{geoid})"
    true
  rescue => e
    Rails.logger.error "Error importing subdivision #{name}: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    @errors << "Subdivision #{name}: #{e.message}"
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
