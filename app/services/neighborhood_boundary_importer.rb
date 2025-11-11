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
      neighborhoods: 0,
      method: nil,
      errors: []
    }

    fips = self.class.city_configs[city_key]

    # Try Italian neighborhoods (national dataset filtered by ISTAT code)
    if ItalyNeighborhoodImporter.available_for_city?(city_key)
      Rails.logger.info "Italian municipality data available for #{city_key}, importing..."
      begin
        importer = ItalyNeighborhoodImporter.new(city_key)
        count = importer.import_neighborhoods
        results[:neighborhoods] = count
        results[:method] = 'italy_istat'
        @errors.concat(importer.errors)
      rescue => e
        Rails.logger.error "Failed to import Italian neighborhoods: #{e.message}"
        @errors << "Italy import failed: #{e.message}"
        results[:errors] << e.message
      end
    # Try city-specific neighborhoods (custom open data portals like Buenos Aires)
    elsif CityNeighborhoodImporter.available_for_city?(city_key)
      Rails.logger.info "City-specific neighborhoods available for #{city_key}, importing..."
      begin
        importer = CityNeighborhoodImporter.new(city_key)
        count = importer.import_neighborhoods
        results[:neighborhoods] = count
        results[:method] = 'city_specific'
        @errors.concat(importer.errors)
      rescue => e
        Rails.logger.error "Failed to import city neighborhoods: #{e.message}"
        @errors << "City import failed: #{e.message}"
        results[:errors] << e.message
      end
    # Try Zillow neighborhoods (US cities with EPA/Zillow data)
    elsif fips[:zillow] == true
      Rails.logger.info "Using Zillow neighborhoods for #{city_key}..."
      begin
        city_name = fips[:city] || fips[:name]
        state = fips[:state]
        county = fips[:county]

        importer = ZillowNeighborhoodImporter.new(city_name: city_name, state: state, county: county)
        count = importer.import_neighborhoods
        results[:neighborhoods] = count
        results[:method] = 'zillow'
        @errors.concat(importer.errors)
      rescue => e
        Rails.logger.error "Failed to import Zillow neighborhoods: #{e.message}"
        @errors << "Zillow import failed: #{e.message}"
        results[:errors] << e.message
      end
    else
      Rails.logger.warn "No neighborhood data source configured for #{city_key}"
      results[:method] = 'none'
    end

    results[:errors] = @errors

    Rails.logger.info "=" * 80
    Rails.logger.info "Import complete for #{city_key}:"
    Rails.logger.info "  Neighborhoods: #{results[:neighborhoods]}"
    Rails.logger.info "  Method: #{results[:method]}"
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

    total_neighborhoods = 0
    total_errors = 0

    results.each do |city, stats|
      Rails.logger.info "#{city.capitalize}:"
      Rails.logger.info "  Neighborhoods: #{stats[:neighborhoods]}"
      Rails.logger.info "  Method: #{stats[:method]}"
      Rails.logger.info "  Errors: #{stats[:errors].size}"

      total_neighborhoods += stats[:neighborhoods]
      total_errors += stats[:errors].size
    end

    Rails.logger.info "-" * 80
    Rails.logger.info "TOTALS:"
    Rails.logger.info "  Total neighborhoods: #{total_neighborhoods}"
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
