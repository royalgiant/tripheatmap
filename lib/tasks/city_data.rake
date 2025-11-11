namespace :city do
  desc "Import all data (boundaries + places) for a specific city"
  task :import, [:city, :force] => :environment do |t, args|
    city = args[:city]
    force = args[:force] == 'true' || ENV['FORCE'] == 'true'

    unless city
      puts "Error: City parameter required"
      puts "Usage: rake city:import[dallas] or rake city:import[dallas,true] to force reimport"
      puts "Available cities: dallas, chicago, miami, austin, sacramento"
      exit 1
    end

    begin
      importer = CityDataImporter.new(city, force: force)
      importer.import_all
    rescue ArgumentError => e
      puts "Error: #{e.message}"
      exit 1
    end
  end

  desc "Import boundaries only for a specific city"
  task :import_boundaries, [:city, :force] => :environment do |t, args|
    city = args[:city]
    force = args[:force] == 'true' || ENV['FORCE'] == 'true'

    unless city
      puts "Error: City parameter required"
      puts "Usage: rake city:import_boundaries[dallas] or rake city:import_boundaries[dallas,true] to force reimport"
      exit 1
    end

    begin
      importer = CityDataImporter.new(city, skip_places: true, force: force)
      importer.import_all
    rescue ArgumentError => e
      puts "Error: #{e.message}"
      exit 1
    end
  end

  desc "Import places data only for a specific city (requires boundaries to exist)"
  task :import_places, [:city, :force] => :environment do |t, args|
    city = args[:city]
    force = args[:force] == 'true' || ENV['FORCE'] == 'true'

    unless city
      puts "Error: City parameter required"
      puts "Usage: rake city:import_places[dallas] or rake city:import_places[dallas,true] to force reimport"
      exit 1
    end

    begin
      importer = CityDataImporter.new(city, skip_boundaries: true, force: force)
      importer.import_all
    rescue ArgumentError => e
      puts "Error: #{e.message}"
      exit 1
    end
  end

  desc "Import data for all supported cities (skips cities updated within 90 days unless FORCE=true)"
  task :import_all => :environment do
    force = ENV['FORCE'] == 'true'
    if force
      puts "⚠️  FORCE mode enabled - will reimport all cities regardless of last update date"
    else
      puts "ℹ️  Skipping cities updated within last 90 days (use FORCE=true to override)"
    end
    CityDataImporter.import_all_cities(force: force)
  end

  desc "Update places data for all cities (skip boundaries import, skips fresh data unless FORCE=true)"
  task :update_places => :environment do
    force = ENV['FORCE'] == 'true'
    if force
      puts "⚠️  FORCE mode enabled - will reimport all cities regardless of last update date"
    else
      puts "ℹ️  Skipping cities updated within last 90 days (use FORCE=true to override)"
    end
    puts "Updating places data for all cities..."
    CityDataImporter.import_all_cities(skip_boundaries: true, force: force)
  end

  desc "Show statistics for a city"
  task :stats, [:city] => :environment do |t, args|
    city = args[:city]

    unless city
      puts "Error: City parameter required"
      puts "Usage: rake city:stats[dallas]"
      exit 1
    end

    city_key = city.downcase
    city_name = CityDataImporter::CITY_NAMES[city_key]
    display_name = CityDataImporter::DISPLAY_NAMES[city_key]

    unless city_name
      puts "Error: City '#{city}' not supported"
      puts "Available cities: #{CityDataImporter::CITY_NAMES.keys.join(', ')}"
      exit 1
    end

    puts "=" * 80
    puts "#{display_name} Statistics"
    puts "=" * 80

    neighborhoods = Neighborhood.for_city(city_name)
    neighborhoods_count = neighborhoods.count
    neighborhoods_with_geom = neighborhoods.where.not(geom: nil).count

    puts "Neighborhoods: #{neighborhoods_count}"
    puts "  With geometry: #{neighborhoods_with_geom}"

    if neighborhoods_count > 0
      with_population = neighborhoods.where.not(population: nil).count
      puts "  With population data: #{with_population}"

      places_stats = NeighborhoodPlacesStat.joins(:neighborhood)
        .where(neighborhoods: { city: city_name })

      places_count = places_stats.count
      puts ""
      puts "Places Statistics: #{places_count} neighborhoods with data"

      if places_count > 0
        total_restaurants = places_stats.sum(:restaurant_count)
        total_cafes = places_stats.sum(:cafe_count)
        total_bars = places_stats.sum(:bar_count)
        total_amenities = places_stats.sum(:total_amenities)
        avg_vibrancy = places_stats.average(:vibrancy_index).to_f.round(2)

        puts "  Total restaurants: #{total_restaurants}"
        puts "  Total cafes: #{total_cafes}"
        puts "  Total bars: #{total_bars}"
        puts "  Total amenities: #{total_amenities}"
        puts "  Average vibrancy index: #{avg_vibrancy}"

        # Show top 5 most vibrant neighborhoods
        top_neighborhoods = NeighborhoodPlacesStat.joins(:neighborhood)
          .where(neighborhoods: { city: city_name })
          .order(vibrancy_index: :desc)
          .limit(5)

        if top_neighborhoods.any?
          puts ""
          puts "Top 5 Most Vibrant Neighborhoods:"
          top_neighborhoods.each_with_index do |stat, i|
            puts "  #{i + 1}. #{stat.neighborhood.name}"
            puts "     Vibrancy: #{stat.vibrancy_index.round(2)} | " \
                 "Restaurants: #{stat.restaurant_count} | " \
                 "Cafes: #{stat.cafe_count} | " \
                 "Bars: #{stat.bar_count}"
          end
        end
      else
        puts ""
        puts "No places data found. Run: rake city:import_places[#{city}]"
      end
    else
      puts ""
      puts "No neighborhoods found. Run: rake city:import[#{city}]"
    end

    puts "=" * 80
  end

  desc "Enrich existing census tract names with actual neighborhood names (for already-imported data)"
  task :enrich_names, [:city] => :environment do |t, args|
    city = args[:city]

    unless city
      puts "Error: City parameter required"
      puts "Usage: rake city:enrich_names[dallas]"
      puts ""
      puts "Note: New imports automatically enrich names. This task is only needed"
      puts "for neighborhoods that were imported before automatic enrichment was enabled."
      exit 1
    end

    begin
      enricher = NeighborhoodNameEnricher.new
      enricher.enrich_city(city)
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    end
  end

  desc "List all supported cities and their current data status"
  task :list => :environment do
    puts "=" * 80
    puts "Supported Cities"
    puts "=" * 80

    CityDataImporter::CITY_NAMES.each do |city_key, city_name|
      display_name = CityDataImporter::DISPLAY_NAMES[city_key]
      neighborhoods_count = Neighborhood.for_city(city_name).count
      places_count = NeighborhoodPlacesStat.joins(:neighborhood)
        .where(neighborhoods: { city: city_name }).count

      status = if neighborhoods_count > 0 && places_count > 0
        "✅ Complete"
      elsif neighborhoods_count > 0
        "⚠️  Missing places data"
      else
        "❌ No data"
      end

      puts "#{display_name.ljust(15)} #{status.ljust(25)} " \
           "Neighborhoods: #{neighborhoods_count}, Places: #{places_count}"
    end

    puts "=" * 80
    puts ""
    puts "Commands:"
    puts "  rake city:import[CITY]           - Import all data for a city (skips if updated within 90 days)"
    puts "  rake city:import[CITY,true]      - Force import (ignores 90-day freshness check)"
    puts "  rake city:import_places[CITY]    - Import only places data (skips if updated within 90 days)"
    puts "  rake city:enrich_names[CITY]     - Enrich census tract names with actual neighborhood names"
    puts "  rake city:stats[CITY]            - Show statistics for a city"
    puts "  rake city:import_all             - Import all cities (skips fresh data)"
    puts "  FORCE=true rake city:import_all  - Force import all cities (ignores freshness)"
    puts ""
    puts "Freshness: Cities updated within 90 days are automatically skipped unless force=true"
    puts ""
  end
end
