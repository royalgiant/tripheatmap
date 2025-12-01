namespace :city do
  desc "Generate AI content for places (rating and price_range) in a city"
  task :generate_place_ai_content, [:city] => :environment do |t, args|
    city = args[:city]

    unless city
      puts "Error: City parameter required"
      puts "Usage: rake city:generate_place_ai_content[atlanta]"
      exit 1
    end

    city_key = city.downcase
    city_name = CityDataImporter::CITY_NAMES[city_key]
    display_name = CityDataImporter::DISPLAY_NAMES[city_name]

    unless city_name
      puts "Error: City '#{city}' not supported"
      puts "Available cities: #{CityDataImporter::CITY_NAMES.keys.join(', ')}"
      exit 1
    end

    puts "=" * 80
    puts "Generating AI Content for Places in #{display_name}"
    puts "=" * 80

    places_without_content = Place
      .joins(:neighborhood)
      .where(neighborhoods: { city: city_name.downcase })
      .where(place_type: ['hotel', 'hostel'])
      .where("rating IS NULL OR price_range IS NULL OR category IS NULL OR image_url IS NULL")

    if places_without_content.empty?
      puts "✅ All places already have AI-generated rating, price range, category, and image url!"
      exit 0
    end

    puts "Found #{places_without_content.size} places without AI content"
    puts "Enqueueing Sidekiq jobs..."
    puts ""

    enqueued_count = 0

    places_without_content.each_with_index do |place, index|
      if place.rating.present? && place.price_range.present? && place.category.present? && place.image_url.present?
        puts "  [#{index + 1}/#{places_without_content.size}] Skipping #{place.name} (already complete)"
        next
      end

      GeneratePlaceAiContentJob.perform_later(place.id)
      enqueued_count += 1
      puts "  [#{index + 1}/#{places_without_content.size}] Enqueued job for #{place.name}"
    end

    puts ""
    puts "=" * 80
    puts "✅ Enqueued #{enqueued_count} Sidekiq jobs for AI content generation"
    puts "💡 Jobs will process in the background without affecting web server performance"
    puts "📊 Monitor progress in Sidekiq dashboard: /sidekiq"
    puts "=" * 80
  end

  desc "Generate AI content for places in ALL cities"
  task :generate_all_places_ai_content => :environment do
    puts "=" * 80
    puts "Generating AI Place Content for All Cities"
    puts "=" * 80
    puts ""

    CityDataImporter::CITY_NAMES.keys.each do |city_key|
      # Re-enable the task so it can be run multiple times
      Rake::Task["city:generate_place_ai_content"].reenable
      # Invoke the task for the current city
      Rake::Task["city:generate_place_ai_content"].invoke(city_key)
      puts ""
    end

    puts "=" * 80
    puts "✅ Completed Place Content Generation for All Cities"
    puts "=" * 80
  end
end
