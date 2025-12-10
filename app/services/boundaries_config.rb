# Central configuration loader for neighborhood boundaries
# Loads and merges all continent-specific boundary configuration files
#
# Usage:
#   BoundariesConfig.all_cities
#   BoundariesConfig.city_config('dallas')
#   BoundariesConfig.available_cities
#
class BoundariesConfig
  class << self
    # Load and merge all continent configuration files
    def all_cities
      @all_cities ||= load_all_boundaries
    end

    # Get configuration for a specific city
    def city_config(city_key)
      all_cities[city_key.to_s.downcase]
    end

    # Get list of all available city keys
    def available_cities
      all_cities.keys
    end

    # Reload configuration from disk (useful for testing)
    def reload!
      @all_cities = nil
      all_cities
    end

    private

    def load_all_boundaries
      boundaries_dir = Rails.root.join('config', 'boundaries')
      merged_config = {}

      # Load each continent file
      continent_files = Dir.glob(boundaries_dir.join('*.yml')).sort

      if continent_files.empty?
        Rails.logger.warn "No boundary configuration files found in #{boundaries_dir}"
        return {}
      end

      continent_files.each do |file_path|
        continent_name = File.basename(file_path, '.yml').humanize

        begin
          config = YAML.load_file(file_path)

          if config.is_a?(Hash)
            merged_config.merge!(config)
            Rails.logger.debug "Loaded #{config.size} cities from #{continent_name}"
          else
            Rails.logger.warn "Invalid format in #{file_path}: expected Hash, got #{config.class}"
          end
        rescue => e
          Rails.logger.error "Error loading #{file_path}: #{e.message}"
        end
      end

      Rails.logger.info "Loaded #{merged_config.size} total cities from #{continent_files.size} continent files"
      merged_config.with_indifferent_access
    end
  end
end
