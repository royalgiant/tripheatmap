# Unified service for importing all data for a city
# Orchestrates neighborhood boundaries and places data import
#
# Usage:
#   CityDataImporter.new('dallas').import_all
#   CityDataImporter.new('dallas', skip_boundaries: true).import_all
#
class CityDataImporter
  attr_reader :city_key, :city_name, :errors, :results

  # Map city keys to lowercase city names (stored in DB)
  # City names are always stored lowercase in the database for consistency
  CITY_NAMES = {
    'dallas' => 'dallas',
    'chicago' => 'chicago',
    'miami' => 'miami',
    'austin' => 'austin',
    'sacramento' => 'sacramento',
    'buenos aires' => 'buenos aires',
    'buenosaires' => 'buenos aires'  # Alias
  }.freeze

  # Display names for UI (capitalized)
  DISPLAY_NAMES = {
    'dallas' => 'Dallas',
    'chicago' => 'Chicago',
    'miami' => 'Miami',
    'austin' => 'Austin',
    'sacramento' => 'Sacramento',
    'buenos aires' => 'Buenos Aires'
  }.freeze

  def initialize(city_key, skip_boundaries: false, skip_places: false)
    @city_key = city_key.to_s.downcase
    @city_name = CITY_NAMES[@city_key]
    @skip_boundaries = skip_boundaries
    @skip_places = skip_places
    @errors = []
    @results = {
      city: @city_name,
      boundaries_imported: 0,
      places_imported: 0,
      duration: 0,
      errors: []
    }

    unless @city_name
      raise ArgumentError, "City '#{city_key}' not supported. Available: #{CITY_NAMES.keys.join(', ')}"
    end
  end

  # Import all data for the city
  def import_all
    start_time = Time.current

    log_header("Starting full import for #{display_name}")

    # Step 1: Import neighborhood boundaries
    unless @skip_boundaries
      import_boundaries
    else
      Rails.logger.info "Skipping boundaries import (skip_boundaries=true)"
    end

    # Step 2: Import places/amenity data
    unless @skip_places
      import_places
    else
      Rails.logger.info "Skipping places import (skip_places=true)"
    end

    @results[:duration] = (Time.current - start_time).round(2)
    @results[:errors] = @errors

    log_summary

    @results
  end

  # Import only boundaries
  def import_boundaries
    log_section("Importing Neighborhood Boundaries")

    begin
      boundary_results = NeighborhoodBoundaryImporter.import_for_city(city_key)

      @results[:boundaries_imported] = boundary_results[:total]
      @results[:boundary_method] = boundary_results[:method]
      @results[:city_neighborhoods] = boundary_results[:city_neighborhoods]
      @results[:census_tracts] = boundary_results[:census_tracts]

      @errors.concat(boundary_results[:errors]) if boundary_results[:errors].any?

      Rails.logger.info "✅ Imported #{boundary_results[:total]} neighborhoods"
    rescue => e
      error_msg = "Boundary import failed: #{e.message}"
      Rails.logger.error error_msg
      @errors << error_msg
      @results[:boundaries_imported] = 0
    end
  end

  # Import only places data
  def import_places
    log_section("Importing Places/Amenity Data")

    begin
      # Check if we have neighborhoods (use lowercase city_name for query)
      neighborhood_count = Neighborhood.for_city(city_name).count

      if neighborhood_count.zero?
        error_msg = "No neighborhoods found for #{display_name}. Run boundaries import first."
        Rails.logger.error error_msg
        @errors << error_msg
        @results[:places_imported] = 0
        return
      end

      Rails.logger.info "Found #{neighborhood_count} neighborhoods to process"

      importer = OverpassImporter.new
      success_count = importer.import_for_city(city_name)

      @results[:places_imported] = success_count
      @errors.concat(importer.instance_variable_get(:@errors))

      Rails.logger.info "✅ Imported places data for #{success_count} neighborhoods"
    rescue => e
      error_msg = "Places import failed: #{e.message}"
      Rails.logger.error error_msg
      @errors << error_msg
      @results[:places_imported] = 0
    end
  end

  # Class method to import all supported cities
  def self.import_all_cities(skip_boundaries: false, skip_places: false)
    results = {}

    CITY_NAMES.each do |city_key, city_name|
      Rails.logger.info "\n\n"
      importer = new(city_key, skip_boundaries: skip_boundaries, skip_places: skip_places)
      results[city_key] = importer.import_all
    end

    print_all_cities_summary(results)
    results
  end

  private

  def display_name
    DISPLAY_NAMES[@city_key] || @city_name
  end

  def log_header(message)
    Rails.logger.info ""
    Rails.logger.info "=" * 80
    Rails.logger.info message
    Rails.logger.info "=" * 80
  end

  def log_section(message)
    Rails.logger.info ""
    Rails.logger.info "-" * 80
    Rails.logger.info message
    Rails.logger.info "-" * 80
  end

  def log_summary
    log_header("Import Complete for #{display_name}")

    Rails.logger.info "Boundaries imported: #{@results[:boundaries_imported]}"
    if @results[:boundary_method]
      Rails.logger.info "  Method: #{@results[:boundary_method]}"
      Rails.logger.info "  City neighborhoods: #{@results[:city_neighborhoods]}"
      Rails.logger.info "  Census tracts: #{@results[:census_tracts]}"
    end

    Rails.logger.info "Places imported: #{@results[:places_imported]}"
    Rails.logger.info "Duration: #{@results[:duration]}s"
    Rails.logger.info "Errors: #{@errors.size}"

    if @errors.any?
      Rails.logger.info ""
      Rails.logger.info "Error details:"
      @errors.first(10).each { |err| Rails.logger.info "  - #{err}" }
      Rails.logger.info "  ... and #{@errors.size - 10} more" if @errors.size > 10
    end

    Rails.logger.info "=" * 80
  end

  def self.print_all_cities_summary(results)
    Rails.logger.info "\n\n"
    Rails.logger.info "=" * 80
    Rails.logger.info "ALL CITIES IMPORT SUMMARY"
    Rails.logger.info "=" * 80

    total_boundaries = 0
    total_places = 0
    total_errors = 0
    total_duration = 0

    results.each do |city_key, stats|
      Rails.logger.info ""
      Rails.logger.info "#{stats[:city]}:"
      Rails.logger.info "  Boundaries: #{stats[:boundaries_imported]}"
      Rails.logger.info "  Places: #{stats[:places_imported]}"
      Rails.logger.info "  Duration: #{stats[:duration]}s"
      Rails.logger.info "  Errors: #{stats[:errors].size}"

      total_boundaries += stats[:boundaries_imported]
      total_places += stats[:places_imported]
      total_errors += stats[:errors].size
      total_duration += stats[:duration]
    end

    Rails.logger.info ""
    Rails.logger.info "-" * 80
    Rails.logger.info "TOTALS:"
    Rails.logger.info "  Boundaries: #{total_boundaries}"
    Rails.logger.info "  Places: #{total_places}"
    Rails.logger.info "  Total Duration: #{total_duration.round(2)}s"
    Rails.logger.info "  Total Errors: #{total_errors}"
    Rails.logger.info "=" * 80
  end
end
