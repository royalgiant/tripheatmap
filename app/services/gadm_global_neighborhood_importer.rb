# Generic importer for European cities that rely on hosted GADM GeoJSON
# datasets (Germany, Netherlands, Switzerland, Sweden, Denmark, Belgium,
# France, Austria, Norway). Each city entry in config/neighborhood_boundaries.yml
# provides the endpoint plus optional bounding-box filters.

class GadmGlobalNeighborhoodImporter
  SUPPORTED_COUNTRIES = {
    "Germany" => "DE",
    "Netherlands" => "NL",
    "Switzerland" => "CH",
    "Sweden" => "SE",
    "Denmark" => "DK",
    "Belgium" => "BE",
    "France" => "FR",
    "Austria" => "AT",
    "Norway" => "NO",
    "Japan" => "JP",
    "Spain" => "ES",
    "Italy" => "IT",
    "Portugal" => "PT",
    "Greece" => "GR",
    "Thailand" => "TH",
    "Vietnam" => "VN",
    "Mexico" => "MX",
    "Brazil" => "BR"
  }.freeze

  attr_reader :city_key, :config, :errors

  def initialize(city_key)
    @city_key = city_key.to_s.downcase
    @config = load_config
    @errors = []

    raise ArgumentError, "City '#{city_key}' not found in configuration" unless @config
    raise ArgumentError, "City '#{city_key}' is disabled" if @config["enabled"] == false
    raise ArgumentError, "Country '#{config['country']}' is not supported" unless supported_country?
    raise ArgumentError, "City '#{city_key}' missing endpoint" unless config["endpoint"].present?

    unless bounding_box.present? || parent_name_field.present?
      raise ArgumentError, "City '#{city_key}' needs either a bounding box or parent_name mapping"
    end
  end

  def self.available_for_city?(city_key)
    config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    city_config = config[city_key.to_s.downcase]
    return false unless city_config && city_config["enabled"] != false

    SUPPORTED_COUNTRIES.key?(city_config["country"]) &&
      (city_config.dig("filters", "bbox").present? || city_config.dig("field_mappings", "parent_name").present?)
  rescue
    false
  end

  def import_neighborhoods
    Rails.logger.info "Importing European GADM neighborhoods for #{city_name}"

    features = fetch_and_filter_features
    return 0 if features.empty?

    imported = 0
    failed = 0

    features.each do |feature|
      if import_neighborhood(feature)
        imported += 1
      else
        failed += 1
      end
    end

    Rails.logger.info "Imported #{imported} neighborhoods for #{city_name} (#{failed} failed)"
    imported
  end

  private

  def supported_country?
    SUPPORTED_COUNTRIES.key?(config["country"])
  end

  def city_name
    @city_name ||= config['city'] || config['name']
  end

  def load_config
    all_config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))
    all_config[city_key]
  end

  def endpoint
    config["endpoint"]
  end

  def parent_name_field
    @parent_name_field ||= config.dig("field_mappings", "parent_name")
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
      }.transform_values { |v| v.nil? ? nil : v.to_f }
    end
  end

  def fetch_and_filter_features
    Rails.logger.info "Fetching European GeoJSON from #{endpoint}"

    response = Faraday.get(endpoint) do |req|
      req.options.timeout = 120
      req.options.open_timeout = 20
    end

    unless response.success?
      Rails.logger.error "GeoJSON error: #{response.status} - #{response.body[0..200]}"
      return []
    end

    data = JSON.parse(response.body)
    features = data["features"] || []
    Rails.logger.info "Fetched #{features.size} features for #{city_name}"

    filtered =
      if bounding_box.present?
        filter_by_bbox(features)
      else
        filter_by_parent_name(features)
      end

    filtered
  rescue => e
    Rails.logger.error "Error fetching neighborhoods: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    @errors << e.message
    []
  end

  def filter_by_parent_name(features)
    Rails.logger.warn "Parent name filtering requested but no field provided" unless parent_name_field.present?

    expected = Array(config['state']) + Array(config['city']) + Array(config['county'])
    expected = expected.compact.map(&:downcase).uniq

    filtered = features.select do |feature|
      parent = feature.dig("properties", parent_name_field)
      expected.any? { |value| parent&.downcase&.include?(value) }
    end

    if filtered.empty?
      sample = features.first(10).map { |f| f.dig("properties", parent_name_field) }.uniq
      Rails.logger.warn "No features matched parent filter #{expected.inspect}. Samples: #{sample.inspect}"
    end

    filtered
  end

  def filter_by_bbox(features)
    box = bounding_box
    return [] unless box

    filtered = features.select do |feature|
      geometry_overlaps_bbox?(feature["geometry"], box)
    end

    if filtered.empty?
      sample_names = features.first(10).map { |f| f.dig("properties", name_field) || f.dig("properties", "shapeName") }
      Rails.logger.warn "No features intersect bounding box #{box.inspect}. Sample names: #{sample_names.inspect}"
    end

    filtered
  end

  def geometry_overlaps_bbox?(geometry, box)
    coords = []
    append_coords(geometry["coordinates"], coords)
    coords.any? do |lon, lat|
      next false unless lon && lat

      lon >= box[:min_lon] && lon <= box[:max_lon] &&
        lat >= box[:min_lat] && lat <= box[:max_lat]
    end
  end

  def append_coords(value, coords)
    return unless value.is_a?(Array)

    if value.first.is_a?(Numeric)
      coords << value
    else
      value.each { |child| append_coords(child, coords) }
    end
  end

  def import_neighborhood(feature)
    props = feature["properties"] || {}
    name = props[name_field] || props["shapeName"]
    raw_geoid = props[geoid_field] || props["shapeID"]

    unless name && raw_geoid
      Rails.logger.warn "Feature missing name or id fields, skipping"
      return false
    end

    geoid = "#{country_prefix}_#{raw_geoid}"
    return false if Neighborhood.find_by(geoid: geoid)

    geometry = parse_geometry(feature["geometry"])
    return false unless geometry

    centroid = begin
      geometry.centroid
    rescue
      geometry.point_on_surface rescue nil
    end

    Neighborhood.create!(
      geoid: geoid,
      name: name,
      city: city_name,
      county: config["county"],
      state: config["state"],
      country: config["country"],
      population: nil,
      geom: geometry,
      centroid: centroid
    )

    true
  rescue => e
    Rails.logger.error "Error importing #{name}: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    @errors << "#{name}: #{e.message}"
    false
  end

  def parse_geometry(geojson)
    factory = RGeo::Geographic.spherical_factory(srid: 4326)
    geometry = RGeo::GeoJSON.decode(geojson.to_json, geo_factory: factory)

    if geometry.is_a?(RGeo::Feature::Polygon)
      factory.multi_polygon([geometry])
    else
      geometry
    end
  rescue => e
    Rails.logger.error "Geometry parse error: #{e.message}"
    nil
  end

  def country_prefix
    SUPPORTED_COUNTRIES[config["country"]] || "EU"
  end

  def name_field
    config.dig("field_mappings", "name") || "NAME"
  end

  def geoid_field
    config.dig("field_mappings", "geoid") || "GID"
  end
end
