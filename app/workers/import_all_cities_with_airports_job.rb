# Sidekiq worker for importing all cities (with boundaries, places, and airports)
# Queues individual jobs for each city to run in parallel
#
# Usage:
#   ImportAllCitiesWithAirportsJob.perform_async
#
class ImportAllCitiesWithAirportsJob
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 2

  def perform
    Rails.logger.info "ImportAllCitiesWithAirportsJob started - queuing individual city jobs"

    cities = NeighborhoodBoundaryImporter.available_cities
    queued_count = 0

    cities.each do |city_key|
      ImportCityWithAirportsJob.perform_async(city_key)
      queued_count += 1
      Rails.logger.info "Queued import job for #{city_key}"
    end

    Rails.logger.info "ImportAllCitiesWithAirportsJob completed - queued #{queued_count} city jobs"

    { queued_cities: cities, total_count: queued_count }
  end
end
