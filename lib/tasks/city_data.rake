namespace :city do
  desc "Import all data (boundaries + places + airports + universities) for a specific city"
  task :import_with_airports, [:city, :force] => :environment do |t, args|
    city = args[:city]
    force = args[:force] == 'true' || ENV['FORCE'] == 'true'

    unless city
      puts "Error: City parameter required"
      puts "Usage: rake city:import_with_airports[dallas]"
      exit 1
    end

    begin
      # Step 1: Import city data (boundaries + places)
      puts "Step 1/3: Importing city data for #{city}..."
      importer = CityDataImporter.new(city, force: force)
      importer.import_all

      # Step 2: Import airports
      puts "Step 2/3: Importing airports for #{city}..."
      airport_importer = AirportImporter.new
      airport_importer.import(city)

      # Step 3: Import universities
      puts "Step 3/3: Importing universities for #{city}..."
      university_importer = UniversityImporter.new
      university_importer.import(city)

      puts "✅ Import complete for #{city}"
    rescue ArgumentError => e
      puts "Error: #{e.message}"
      exit 1
    end
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

  desc "Queue city + airport import as async Sidekiq job (non-blocking)"
  task :import_with_airports_async, [:city] => :environment do |t, args|
    city = args[:city]

    unless city
      puts "Error: City parameter required"
      puts "Usage: rake city:import_with_airports_async[dallas]"
      exit 1
    end

    ImportCityWithAirportsJob.perform_async(city)
    puts "✅ Queued city + airport import job for #{city}"
    puts "Monitor progress in Sidekiq dashboard or logs"
  end

  desc "Queue all cities + airports import as async Sidekiq jobs (non-blocking)"
  task :import_all_async => :environment do
    ImportAllCitiesWithAirportsJob.perform_async
    puts "✅ Queued import jobs for all cities (with airports)"
    puts "Individual jobs will be queued for each city to run in parallel"
    puts "Monitor progress in Sidekiq dashboard or logs"
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
    puts "Primary Commands:"
    puts "  Async (recommended, non-blocking):"
    puts "    rake city:import_with_airports_async[CITY] - Import city + airports"
    puts "    rake city:import_all_async                 - Import all cities + airports"
    puts ""
    puts "  Sync (for testing, blocks until complete):"
    puts "    rake city:import_with_airports[CITY]       - Import city + airports"
    puts ""
    puts "Utility Commands:"
    puts "  rake city:list           - List all supported cities and their data status"
    puts "  rake city:update_places  - Update places data for all cities"
    puts ""
  end
end
