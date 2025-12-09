# Sidekiq worker for importing airports for a specific city
# Can be scheduled via sidekiq-cron or called manually
#
# Usage:
#   ImportAirportsJob.perform_async('dallas')
#
class ImportAirportsJob
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  def perform(city_name)
    Rails.logger.info "ImportAirportsJob started for city: #{city_name}"

    importer = AirportImporter.new
    importer.import(city_name)

    Rails.logger.info "ImportAirportsJob completed successfully for #{city_name}"
  rescue => e
    Rails.logger.error "ImportAirportsJob failed for #{city_name}: #{e.message}"
    raise
  end
end
