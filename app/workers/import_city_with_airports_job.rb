# Sidekiq worker for importing both city data and airports for a specific city
# Runs city import first, then airports import
#
# Usage:
#   ImportCityWithAirportsJob.perform_async('dallas')
#
class ImportCityWithAirportsJob
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  def perform(city_key)
    Rails.logger.info "ImportCityWithAirportsJob started for city: #{city_key}"

    # Step 1: Import city data (boundaries + places)
    Rails.logger.info "Step 1/2: Importing city data for #{city_key}..."
    importer = CityDataImporter.new(city_key)
    city_results = importer.import_all

    if city_results[:errors].any?
      Rails.logger.error "City import completed with errors for #{city_key}: #{city_results[:errors].size} errors"
    else
      Rails.logger.info "City import completed successfully for #{city_key}"
    end

    # Step 2: Import airports
    Rails.logger.info "Step 2/2: Importing airports for #{city_key}..."
    airport_importer = AirportImporter.new
    airport_importer.import(city_key)
    Rails.logger.info "Airport import completed for #{city_key}"

    Rails.logger.info "ImportCityWithAirportsJob completed successfully for #{city_key}"

    city_results
  rescue ArgumentError => e
    Rails.logger.error "ImportCityWithAirportsJob failed for #{city_key}: #{e.message}"
    raise
  end
end
