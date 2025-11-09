# Unified service for importing neighborhood boundaries
# Uses city-specific neighborhoods where available, falls back to census tracts
#
# Usage:
#   NeighborhoodBoundaryImporter.import_for_city('dallas')
#   NeighborhoodBoundaryImporter.import_all
#
class NeighborhoodBoundaryImporter
  attr_reader :city_key, :errors

  # Load city configurations from YAML file
  def self.city_configs
    @city_configs ||= YAML.load_file(Rails.root.join('config', 'neighborhood_boundaries.yml')).with_indifferent_access
  end

  # Get FIPS codes for a city (backward compatibility)
  def self.city_county_fips
    @city_county_fips ||= city_configs.transform_values do |config|
      { state: config[:state_fips], county: config[:county_fips] }
    end
  end

  def initialize(city_key)
    @city_key = city_key.to_s.downcase
    @errors = []

    unless self.class.city_configs.key?(@city_key)
      raise ArgumentError, "City '#{city_key}' not supported. Available: #{self.class.city_configs.keys.join(', ')}"
    end
  end

  # Import neighborhood boundaries for a specific city
  # Returns hash with import statistics
  def import
    Rails.logger.info "=" * 80
    Rails.logger.info "Starting neighborhood import for #{city_key}"
    Rails.logger.info "=" * 80

    results = {
      city: city_key,
      city_neighborhoods: 0,
      census_tracts: 0,
      method: nil,
      errors: []
    }

    fips = self.class.city_configs[city_key]

    # Try city-specific neighborhoods first (custom open data portals)
    if CityNeighborhoodImporter.available_for_city?(city_key)
      Rails.logger.info "City-specific neighborhoods available for #{city_key}, importing..."
      begin
        importer = CityNeighborhoodImporter.new(city_key)
        count = importer.import_neighborhoods
        results[:city_neighborhoods] = count
        results[:method] = 'city_specific'
        @errors.concat(importer.errors)
      rescue => e
        Rails.logger.error "Failed to import city neighborhoods: #{e.message}"
        @errors << "City import failed: #{e.message}"
        results[:errors] << e.message
      end
    elsif fips[:zillow] == true
      Rails.logger.info "Using Zillow neighborhoods for #{city_key}..."
      begin
        city_name = fips[:city] || fips[:name]
        state = fips[:state]
        county = fips[:county]

        importer = ZillowNeighborhoodImporter.new(city_name: city_name, state: state, county: county)
        count = importer.import_neighborhoods
        results[:city_neighborhoods] = count
        results[:method] = 'zillow'
        @errors.concat(importer.errors)
      rescue => e
        Rails.logger.error "Failed to import Zillow neighborhoods: #{e.message}"
        @errors << "Zillow import failed: #{e.message}"
        results[:errors] << e.message
      end
    else
      Rails.logger.info "No city-specific or Zillow neighborhoods for #{city_key}, will use census tracts..."
      results[:method] = 'census_fallback'
    end

    # Import census tracts (as primary for unsupported cities, or as additional data)
    # Skip for non-US cities that don't have FIPS codes
    if fips[:state_fips].present? && fips[:county_fips].present?
      begin
        importer = CensusTractImporter.new(
          state: fips[:state_fips],
          county: fips[:county_fips],
          city_name: fips[:name] || fips['name'],
          county_name: fips[:county] || fips['county']
        )
        count = importer.import_tracts
        results[:census_tracts] = count
        @errors.concat(importer.errors)
      rescue => e
        Rails.logger.error "Failed to import census tracts: #{e.message}"
        @errors << "Census import failed: #{e.message}"
        results[:errors] << e.message
      end
    else
      Rails.logger.info "Skipping US Census tracts (not applicable for #{city_key})"
    end

    results[:total] = results[:city_neighborhoods] + results[:census_tracts]
    results[:errors] = @errors

    Rails.logger.info "=" * 80
    Rails.logger.info "Import complete for #{city_key}:"
    Rails.logger.info "  City neighborhoods: #{results[:city_neighborhoods]}"
    Rails.logger.info "  Census tracts: #{results[:census_tracts]}"
    Rails.logger.info "  Total: #{results[:total]}"
    Rails.logger.info "  Errors: #{@errors.size}"
    Rails.logger.info "=" * 80

    results
  end

  # Import boundaries for all supported cities
  def self.import_all
    results = {}

    city_configs.keys.each do |city|
      Rails.logger.info "\n\nProcessing #{city}..."
      importer = new(city)
      results[city] = importer.import
    end

    # Print summary
    Rails.logger.info "\n\n"
    Rails.logger.info "=" * 80
    Rails.logger.info "IMPORT SUMMARY FOR ALL CITIES"
    Rails.logger.info "=" * 80

    total_city_neighborhoods = 0
    total_census_tracts = 0
    total_errors = 0

    results.each do |city, stats|
      Rails.logger.info "#{city.capitalize}:"
      Rails.logger.info "  City neighborhoods: #{stats[:city_neighborhoods]}"
      Rails.logger.info "  Census tracts: #{stats[:census_tracts]}"
      Rails.logger.info "  Errors: #{stats[:errors].size}"

      total_city_neighborhoods += stats[:city_neighborhoods]
      total_census_tracts += stats[:census_tracts]
      total_errors += stats[:errors].size
    end

    Rails.logger.info "-" * 80
    Rails.logger.info "TOTALS:"
    Rails.logger.info "  City neighborhoods: #{total_city_neighborhoods}"
    Rails.logger.info "  Census tracts: #{total_census_tracts}"
    Rails.logger.info "  Grand total: #{total_city_neighborhoods + total_census_tracts}"
    Rails.logger.info "  Total errors: #{total_errors}"
    Rails.logger.info "=" * 80

    results
  end

  # Import boundaries for a specific city (class method)
  def self.import_for_city(city_key)
    new(city_key).import
  end

  # Get available cities
  def self.available_cities
    city_configs.keys
  end
end
