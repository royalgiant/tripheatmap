namespace :import do
  desc "Import airports for a specific city or all cities"
  task :airports, [:city_name] => :environment do |t, args|
    importer = AirportImporter.new
    if args[:city_name]
      importer.import(args[:city_name])
    else
      # Import for all cities in config
      cities = Neighborhood.distinct.pluck(:city).compact
      cities.each do |city|
        importer.import(city)
      end
    end
  end

  desc "Queue airport import as async Sidekiq job (non-blocking)"
  task :airports_async, [:city_name] => :environment do |t, args|
    city_name = args[:city_name]

    unless city_name
      puts "Error: City name parameter required"
      puts "Usage: rake import:airports_async[dallas]"
      exit 1
    end

    ImportAirportsJob.perform_async(city_name)
    puts "✅ Queued airport import job for #{city_name}"
    puts "Monitor progress in Sidekiq dashboard or logs"
  end
end
