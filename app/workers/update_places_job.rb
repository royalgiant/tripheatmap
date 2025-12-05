# Sidekiq worker for updating only places data for all cities
# Skips boundary import (assumes boundaries already exist)
#
# Usage:
#   UpdatePlacesJob.perform_async           # Normal run (respects 90-day freshness check)
#   UpdatePlacesJob.perform_async(true)     # Force update all cities (ignores freshness check)
#
class UpdatePlacesJob
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  def perform(force_update = false)
    Rails.logger.info "UpdatePlacesJob started for all cities (force: #{force_update})"
    if Rails.env.production?
      results = CityDataImporter.import_all_cities(skip_boundaries: true, force: force_update)
      total_errors = results.values.sum { |r| r[:errors].size }

      if total_errors > 0
        Rails.logger.error "UpdatePlacesJob completed with #{total_errors} total errors"
      else
        Rails.logger.info "UpdatePlacesJob completed successfully"
      end

      results
    end
  end
end
