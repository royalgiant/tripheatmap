namespace :places do
  desc "Populate agoda_affiliate_url for all places based on city configuration"
  task populate_agoda_urls: :environment do
    puts "Loading city configurations..."
    city_configs = BoundariesConfig.all_cities
    
    # Build city -> Agoda URL map
    city_agoda_map = {}
    city_configs.each do |_key, config|
      next unless config['agodacomurl'].present?
      
      city_key = config['city'].to_s.downcase
      name_key = config['name'].to_s.downcase
      
      city_agoda_map[city_key] = config['agodacomurl'] if config['city']
      city_agoda_map[name_key] = config['agodacomurl'] if config['name']
    end
    
    puts "Found Agoda URLs for #{city_agoda_map.keys.uniq.size} cities"
    
    # Get all unique cities from places
    cities_with_places = Place.distinct.pluck(:city).compact
    puts "Found #{cities_with_places.size} cities with places"
    
    total_updated = 0
    cities_with_places.each do |city|
      agoda_url = city_agoda_map[city.downcase]
      
      if agoda_url
        count = Place.where(city: city, agoda_affiliate_url: nil).update_all(agoda_affiliate_url: agoda_url)
        total_updated += count
        puts "  ✅ #{city}: Updated #{count} places" if count > 0
      else
        place_count = Place.where(city: city).count
        puts "  ⚠️  #{city}: No Agoda URL configured (#{place_count} places skipped)"
      end
    end
    
    puts "\n" + "="*60
    puts "Summary:"
    puts "  Total places updated: #{total_updated}"
    puts "  Cities with Agoda URLs: #{city_agoda_map.keys.uniq.size}"
    puts "="*60
  end
end
