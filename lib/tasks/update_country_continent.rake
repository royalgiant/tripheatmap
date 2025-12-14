namespace :neighborhoods do
  desc "Update country and continent for all neighborhoods based on city configuration"
  task update_country_continent: :environment do
    puts "=" * 80
    puts "Updating country and continent for all neighborhoods"
    puts "=" * 80
    puts ""

    require_relative '../../app/services/concerns/continent_helper'

    class ContinentUpdater
      include ContinentHelper

      def continent_for_country(country)
        determine_continent(country)
      end
    end

    helper = ContinentUpdater.new

    # Load config from new boundaries structure
    config = BoundariesConfig.all_cities

    # Build city -> country/continent mapping
    city_mappings = {}
    config.each do |city_key, city_config|
      next if city_config.nil? || city_key.to_s == 'states'
      next unless city_config.is_a?(Hash)

      city_name = (city_config[:city] || city_config['city'] || city_config[:name] || city_config['name']).to_s.downcase

      # Determine country and continent
      if city_config[:country] || city_config['country']
        # International city with explicit country field
        country = city_config[:country] || city_config['country']
        continent = city_config[:continent] || city_config['continent'] || helper.continent_for_country(country)
      elsif (city_config[:state_fips] || city_config['state_fips']) && (city_config[:county_fips] || city_config['county_fips'])
        # US city identified by FIPS codes
        country = "United States"
        continent = "North America"
      else
        # Unknown - skip this city
        next
      end

      city_mappings[city_name] = {
        country: country,
        continent: continent
      }
    end

    puts "Found #{city_mappings.size} cities in configuration"
    puts ""

    # Update neighborhoods
    updated_count = 0
    skipped_count = 0
    missing_city_count = 0

    Neighborhood.find_each do |neighborhood|
      city_name = neighborhood.city.to_s.downcase

      if city_mappings[city_name]
        mapping = city_mappings[city_name]
        neighborhood.update_columns(
          country: mapping[:country],
          continent: mapping[:continent]
        )
        updated_count += 1

        if updated_count % 100 == 0
          puts "Updated #{updated_count} neighborhoods..."
        end
      else
        missing_city_count += 1
        if missing_city_count <= 5
          puts "⚠️  No mapping found for city: #{neighborhood.city}"
        end
      end
    end

    puts ""
    puts "=" * 80
    puts "Update Complete"
    puts "=" * 80
    puts "Updated: #{updated_count} neighborhoods"
    puts "Missing city mapping: #{missing_city_count} neighborhoods"
    puts "=" * 80

    # Show summary by continent
    puts ""
    puts "Summary by continent:"
    continents = Neighborhood.where.not(continent: [nil, '']).group(:continent).count
    continents.sort_by { |_, count| -count }.each do |continent, count|
      puts "  #{continent}: #{count} neighborhoods"
    end
  end
end
