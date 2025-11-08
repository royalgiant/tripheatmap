# Sidekiq worker for updating only places data for all cities
# Skips boundary import (assumes boundaries already exist)
#
# Usage:
#   UpdatePlacesJob.perform_async
#
class UpdatePlacesJob
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  def perform
    Rails.logger.info "UpdatePlacesJob started for all cities"

    results = CityDataImporter.import_all_cities(skip_boundaries: true)

    total_errors = results.values.sum { |r| r[:errors].size }

    if total_errors > 0
      Rails.logger.error "UpdatePlacesJob completed with #{total_errors} total errors"
    else
      Rails.logger.info "UpdatePlacesJob completed successfully"
    end

    results
  end
end
