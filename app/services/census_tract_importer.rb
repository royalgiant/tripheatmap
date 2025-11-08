# Service for importing Census tract boundaries from US Census Bureau TIGER/Line data
# Uses the TIGERweb REST API to fetch GeoJSON boundaries for census tracts
#
# Usage:
#   CensusTractImporter.new(state: 'TX', county: '113').import_tracts
#
class CensusTractImporter
  BASE_URL = "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_Current/MapServer"
  TRACT_LAYER = "8" # Census Tracts layer ID

  attr_reader :state_fips, :county_fips, :city_name, :county_name, :errors

  def initialize(state:, county: nil, city_name: nil, county_name: nil)
    @state_fips = normalize_fips(state)
    @county_fips = county ? normalize_fips(county) : nil
    @city_name = city_name
    @county_name = county_name
    @errors = []
  end

  def import_tracts
    Rails.logger.info "Importing census tracts for state #{state_fips}#{county_fips ? ", county #{county_fips}" : ""}"

    features = fetch_tract_features
    return 0 if features.empty?

    imported_count = 0
    failed_count = 0

    features.each do |feature|
      if import_tract(feature)
        imported_count += 1
      else
        failed_count += 1
      end
    end

    Rails.logger.info "Imported #{imported_count} census tracts (#{failed_count} failed)"

    # Fetch and update population data from Census API
    if county_fips
      Rails.logger.info "Fetching population data from Census API..."
      begin
        population_service = CensusPopulationService.new
        updated = population_service.update_neighborhood_populations(
          state_fips: state_fips,
          county_fips: county_fips
        )
        Rails.logger.info "Updated population for #{updated} tracts"
      rescue => e
        Rails.logger.error "Failed to fetch population data: #{e.message}"
        @errors << "Population fetch failed: #{e.message}"
      end
    end

    imported_count
  end

  private

  def fetch_tract_features
    where_clause = build_where_clause
    params = {
      where: where_clause,
      outFields: "GEOID,NAME,BASENAME,STATE,COUNTY,MTFCC,FUNCSTAT",
      returnGeometry: "true",
      f: "geojson",
      outSR: "4326" # WGS84
    }

    url = "#{BASE_URL}/#{TRACT_LAYER}/query"

    begin
      Rails.logger.info "TIGERweb request: #{url}"
      Rails.logger.info "Query params: #{params.inspect}"

      response = Faraday.get(url, params) do |req|
        req.options.timeout = 60
        req.options.open_timeout = 10
      end

      unless response.success?
        Rails.logger.error "Census API error: #{response.status} - #{response.body}"
        return []
      end

      data = JSON.parse(response.body)

      # Log the response structure for debugging
      if data["error"]
        Rails.logger.error "TIGERweb API error: #{data['error'].inspect}"
        @errors << "TIGERweb error: #{data['error']['message']}"
        return []
      end

      features = data["features"] || []

      Rails.logger.info "Fetched #{features.size} census tract features from Census API"
      features
    rescue => e
      Rails.logger.error "Error fetching census tracts: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      @errors << e.message
      []
    end
  end

  def import_tract(feature)
    props = feature["properties"]
    geoid = props["GEOID"]

    existing = Neighborhood.find_by(geoid: geoid)
    if existing
      Rails.logger.debug "Tract #{geoid} already exists, skipping"
      return false
    end

    geojson = feature["geometry"]
    geometry = parse_geometry(geojson)

    unless geometry
      Rails.logger.warn "Failed to parse geometry for tract #{geoid}"
      return false
    end

    centroid = geometry.centroid
    state_name = get_state_name(props["STATE"])

    Neighborhood.create!(
      geoid: geoid,
      name: "Census Tract #{props["NAME"]}",
      city: @city_name || @county_name,
      county: @county_name,
      state: state_name,
      population: nil, # Will be fetched from Census API separately
      geom: geometry,
      centroid: centroid
    )

    Rails.logger.debug "Imported tract #{geoid}: #{props["NAME"]}"
    true
  rescue => e
    Rails.logger.error "Error importing tract #{geoid}: #{e.message}"
    @errors << "Tract #{geoid}: #{e.message}"
    false
  end

  # Parse GeoJSON geometry using RGeo
  def parse_geometry(geojson)
    factory = RGeo::Geographic.spherical_factory(srid: 4326)
    RGeo::GeoJSON.decode(geojson.to_json, geo_factory: factory)
  rescue => e
    Rails.logger.error "Geometry parse error: #{e.message}"
    nil
  end

  # Build WHERE clause for Census API query
  def build_where_clause
    if county_fips
      "STATE='#{state_fips}' AND COUNTY='#{county_fips}'"
    else
      "STATE='#{state_fips}'"
    end
  end

  # Normalize FIPS codes - remove leading zeros since TIGERweb doesn't use them
  def normalize_fips(code)
    code.to_s.to_i.to_s # Convert to int and back to remove leading zeros
  end

  # Load state configurations from YAML
  def self.state_configs
    @state_configs ||= begin
      config = YAML.load_file(Rails.root.join('config', 'neighborhood_boundaries.yml'))
      config['states'] || {}
    end
  end

  # Map state FIPS codes to state abbreviations
  def get_state_name(fips)
    state = self.class.state_configs[fips]
    state ? state['abbreviation'] : fips
  end
end
