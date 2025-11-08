# Sidekiq worker for full import of all cities (boundaries + places)
# Use this for monthly full refresh
#
# Usage:
#   ImportAllCitiesJob.perform_async
#
class ImportAllCitiesJob
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 2

  def perform
    Rails.logger.info "ImportAllCitiesJob started for all cities"

    results = CityDataImporter.import_all_cities

    total_errors = results.values.sum { |r| r[:errors].size }

    if total_errors > 0
      Rails.logger.error "ImportAllCitiesJob completed with #{total_errors} total errors"
    else
      Rails.logger.info "ImportAllCitiesJob completed successfully"
    end

    results
  end
end
