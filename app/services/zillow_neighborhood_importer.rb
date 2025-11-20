# Service for importing neighborhood boundaries from EPA/Zillow MapServer
# Covers 17,000+ neighborhoods in 650+ US cities
#
# Usage:
#   ZillowNeighborhoodImporter.new(city_name: 'San Francisco', state: 'CA').import_neighborhoods
#
class ZillowNeighborhoodImporter
  attr_reader :city_name, :state_abbr, :county_name, :errors

  # EPA/Zillow Neighborhoods MapServer endpoint
  BASE_URL = "https://gispub.epa.gov/arcgis/rest/services/OEI/Zillow_Neighborhoods/MapServer/1/query"

  def initialize(city_name:, state:, county: nil)
    @city_name = city_name
    @state_abbr = state
    @county_name = county
    @errors = []
  end

  # Import all neighborhoods for the city
  # Returns the number of neighborhoods imported
  def import_neighborhoods
    Rails.logger.info "Importing Zillow neighborhoods for #{city_name}, #{state_abbr}"

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

    Rails.logger.info "Imported #{imported_count} Zillow neighborhoods for #{city_name} (#{failed_count} failed)"
    imported_count
  end

  # Check if a city has Zillow neighborhood data available
  def self.available_for_city?(city_name:, state:)
    url = "#{BASE_URL}?where=City='#{URI.encode_www_form_component(city_name)}'+AND+State='#{state}'&returnCountOnly=true&f=json"

    begin
      response = Faraday.get(url) do |req|
        req.options.timeout = 30
        req.options.open_timeout = 15
      end
      return false unless response.success?

      data = JSON.parse(response.body)
      count = data['count'] || 0
      count > 0
    rescue => e
      Rails.logger.warn "Zillow availability check failed for #{city_name}, #{state}: #{e.message}"
      false
    end
  end

  private

  # Fetch neighborhood features from EPA/Zillow MapServer
  def fetch_neighborhood_features
    # Build query: WHERE City='San Francisco' AND State='CA'
    where_clause = "City='#{escape_sql(city_name)}' AND State='#{escape_sql(state_abbr)}'"

    url = "#{BASE_URL}?where=#{URI.encode_www_form_component(where_clause)}&outFields=*&f=geojson&outSR=4326"

    begin
      response = Faraday.get(url) do |req|
        req.options.timeout = 120
        req.options.open_timeout = 30
      end

      unless response.success?
        Rails.logger.error "EPA/Zillow API error: #{response.status} - #{response.body}"
        return []
      end

      data = JSON.parse(response.body)
      features = data["features"] || []

      Rails.logger.info "Fetched #{features.size} Zillow neighborhood features for #{city_name}"
      features
    rescue => e
      Rails.logger.error "Error fetching Zillow neighborhoods: #{e.message}"
      @errors << e.message
      []
    end
  end

  # Import a single neighborhood feature
  def import_neighborhood(feature)
    props = feature["properties"]

    name = props["Name"]
    region_id = props["RegionID"]
    geoid = "ZILLOW_#{region_id}"

    unless name && region_id
      Rails.logger.warn "Zillow neighborhood missing required fields, skipping"
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
      Rails.logger.warn "Failed to parse geometry for Zillow neighborhood #{name}"
      return false
    end

    # Calculate centroid
    centroid = begin
      geometry.centroid_point
    rescue
      geometry.point_on_surface rescue nil
    end

    # Get county from props or use configured value
    county = props["County"] || @county_name

    # Create neighborhood record
    Neighborhood.create!(
      geoid: geoid,
      name: name,
      city: city_name,
      county: county,
      state: state_abbr,
      country: "United States",
      continent: "North America",
      population: nil, # Zillow data doesn't include population
      geom: geometry,
      centroid: centroid
    )

    Rails.logger.debug "Imported Zillow neighborhood: #{name}"
    true
  rescue => e
    Rails.logger.error "Error importing Zillow neighborhood #{name}: #{e.message}"
    @errors << "Neighborhood #{name}: #{e.message}"
    false
  end

  # Parse GeoJSON geometry using RGeo
  def parse_geometry(geojson)
    factory = RGeo::Geographic.spherical_factory(srid: 4326)
    geometry = RGeo::GeoJSON.decode(geojson.to_json, geo_factory: factory)

    # Ensure it's a MultiPolygon (convert Polygon to MultiPolygon if needed)
    if geometry.is_a?(RGeo::Feature::Polygon)
      factory.multi_polygon([geometry])
    else
      geometry
    end
  rescue => e
    Rails.logger.error "Geometry parse error: #{e.message}"
    nil
  end

  # Simple SQL escaping for ESRI queries
  def escape_sql(value)
    value.to_s.gsub("'", "''")
  end
end
