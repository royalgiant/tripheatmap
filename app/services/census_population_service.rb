# Service for fetching population data from US Census Bureau API
# Uses the American Community Survey (ACS) 5-Year Estimates for census tract populations
#
# Usage:
#   service = CensusPopulationService.new
#   populations = service.fetch_tract_populations(state_fips: '48', county_fips: '113')
#   # Returns: { "48113001100" => 4523, "48113001200" => 3876, ... }
#
class CensusPopulationService
  BASE_URL = "https://api.census.gov/data"
  YEAR = "2022" # Use most recent ACS 5-year data
  DATASET = "acs/acs5" # American Community Survey 5-Year Estimates

  attr_reader :api_key, :errors

  def initialize
    # Try environment-specific key first, then fall back to root level
    @api_key = Rails.application.credentials.dig(Rails.env.to_sym, :census_bureau_api_key) ||
               Rails.application.credentials.dig(:census_bureau_api_key)
    @errors = []

    unless @api_key
      raise ArgumentError, "Census Bureau API key not found in credentials. Add it under #{Rails.env}: census_bureau_api_key or at root level."
    end
  end

  # Fetch population data for all census tracts in a county
  # Returns a hash mapping GEOID to population: { "48113001100" => 4523, ... }
  def fetch_tract_populations(state_fips:, county_fips:)
    state = normalize_fips(state_fips, 2)
    county = normalize_fips(county_fips, 3)

    Rails.logger.info "Fetching population data for state #{state}, county #{county}"

    params = {
      get: "NAME,B01003_001E", # NAME and Total Population
      for: "tract:*", # All tracts
      in: "state:#{state} county:#{county}",
      key: api_key
    }

    url = "#{BASE_URL}/#{YEAR}/#{DATASET}"

    begin
      Rails.logger.info "Census API request: #{url}"
      Rails.logger.debug "Census API params: #{params.inspect}"

      response = Faraday.get(url, params) do |req|
        req.options.timeout = 30
        req.options.open_timeout = 10
      end

      unless response.success?
        Rails.logger.error "Census API error: #{response.status} - #{response.body}"
        @errors << "HTTP #{response.status}: #{response.body}"
        return {}
      end

      data = JSON.parse(response.body)

      # Census API returns array format: [["NAME", "B01003_001E", "state", "county", "tract"], [...data rows...]]
      populations = parse_population_response(data, state, county)

      Rails.logger.info "Fetched population data for #{populations.size} census tracts"
      populations
    rescue => e
      Rails.logger.error "Error fetching census populations: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      @errors << e.message
      {}
    end
  end

  # Update population for existing neighborhoods based on their GEOID
  def update_neighborhood_populations(state_fips:, county_fips:)
    populations = fetch_tract_populations(state_fips: state_fips, county_fips: county_fips)
    return 0 if populations.empty?

    updated_count = 0

    populations.each do |geoid, population|
      neighborhood = Neighborhood.find_by(geoid: geoid)

      if neighborhood
        neighborhood.update_column(:population, population)
        updated_count += 1
        Rails.logger.debug "Updated population for #{geoid}: #{population}"
      end
    end

    Rails.logger.info "Updated population for #{updated_count} neighborhoods"
    updated_count
  end

  private

  # Parse Census API response and build GEOID => population hash
  def parse_population_response(data, state_fips, county_fips)
    return {} if data.empty?

    # First row is headers: ["NAME", "B01003_001E", "state", "county", "tract"]
    headers = data[0]
    name_idx = headers.index("NAME")
    pop_idx = headers.index("B01003_001E")
    state_idx = headers.index("state")
    county_idx = headers.index("county")
    tract_idx = headers.index("tract")

    populations = {}

    # Skip header row, process data rows
    data[1..].each do |row|
      next if row.nil? || row.size < 5

      tract_code = row[tract_idx]
      population_str = row[pop_idx]

      # Build GEOID: state + county + tract (e.g., "48113001100")
      geoid = "#{state_fips}#{county_fips}#{tract_code}"

      # Parse population (may be null for some tracts)
      population = population_str.to_i
      populations[geoid] = population if population > 0

      Rails.logger.debug "Tract #{geoid}: #{row[name_idx]} = #{population} people"
    end

    populations
  end

  # Normalize FIPS codes to specified length with leading zeros
  def normalize_fips(code, length)
    code.to_s.rjust(length, '0')
  end
end
