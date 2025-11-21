namespace :neighborhoods do
  desc "Update country and continent for all neighborhoods based on city configuration"
  task update_country_continent: :environment do
    puts "=" * 80
    puts "Updating country and continent for all neighborhoods"
    puts "=" * 80
    puts ""

    # Load config
    config = YAML.load_file(Rails.root.join("config", "neighborhood_boundaries.yml"))

    # Build city -> country/continent mapping
    city_mappings = {}
    config.each do |city_key, city_config|
      next if city_config.nil? || city_key == 'states'

      city_name = (city_config['city'] || city_config['name']).to_s.downcase

      # Determine country and continent
      if city_config['country']
        # International city with explicit country field
        country = city_config['country']
        continent = city_config['continent'] || determine_continent(country)
      elsif city_config['state_fips'] && city_config['county_fips']
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
  end

  def self.determine_continent(country)
    case country
    when "United Kingdom", "Ireland", "Italy", "Germany", "Netherlands", "Switzerland",
         "Sweden", "Denmark", "Belgium", "France", "Austria", "Norway", "Spain",
         "Portugal", "Greece"
      "Europe"
    when "Canada", "United States", "Mexico"
      "North America"
    when "Australia", "New Zealand"
      "Oceania"
    when "Singapore", "Hong Kong SAR", "United Arab Emirates", "Japan", "Thailand", "Vietnam"
      "Asia"
    when "Argentina", "Brazil"
      "South America"
    else
      nil
    end
  end
end
