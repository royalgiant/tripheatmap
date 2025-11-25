# Sidekiq worker for updating only hotels/hostels data for all cities
# Removes hotels that went out of business and adds new ones
# Skips boundary import and OSM places (restaurants/bars/cafes)
#
# Usage:
#   UpdateHotelsJob.perform_async
#
class UpdateHotelsJob
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  def perform
    Rails.logger.info "UpdateHotelsJob started"
    
    max_cities_to_update = 10
    updated_count = 0
    results = {}

    if Rails.env.production?
      # Shuffle cities to ensure we rotate through them over time
      cities = CityDataImporter.city_names.keys.shuffle
      
      cities.each do |city_key|
        break if updated_count >= max_cities_to_update
        
        # We reuse CityDataImporter but now it only hits OSM
        importer = CityDataImporter.new(city_key,
          skip_boundaries: true,
          skip_osm_places: false, # This is now the main source for hotels too
          force: false           # Still respect 90-day freshness to avoid unnecessary processing
        )
        
        result = importer.import_all
        results[city_key] = result
        
        if !result[:skipped]
          updated_count += 1
          Rails.logger.info "✅ UpdateHotelsJob: Updated #{city_key} (#{updated_count}/#{max_cities_to_update} for this run)"
        end
      end
      
      Rails.logger.info "UpdateHotelsJob finished. Updated #{updated_count} cities."
      
      if updated_count == 0
         Rails.logger.info "No cities needed updating (all cached within 90 days)."
      end

      results
    end
  end
end
