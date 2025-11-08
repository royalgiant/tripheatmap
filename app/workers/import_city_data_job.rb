# Sidekiq worker for importing all data (boundaries + places) for a specific city
# Can be scheduled via sidekiq-cron or called manually
#
# Usage:
#   ImportCityDataJob.perform_async('dallas')
#
class ImportCityDataJob
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  def perform(city_key)
    Rails.logger.info "ImportCityDataJob started for city: #{city_key}"

    importer = CityDataImporter.new(city_key)
    results = importer.import_all

    if results[:errors].any?
      Rails.logger.error "ImportCityDataJob completed with errors for #{city_key}: #{results[:errors].size} errors"
    else
      Rails.logger.info "ImportCityDataJob completed successfully for #{city_key}"
    end

    results
  rescue ArgumentError => e
    Rails.logger.error "ImportCityDataJob failed for #{city_key}: #{e.message}"
    raise
  end
end
