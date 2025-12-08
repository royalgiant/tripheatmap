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
end
