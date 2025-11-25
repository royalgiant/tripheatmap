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
      .where(rating: nil)
      .or(Place.joins(:neighborhood).where(neighborhoods: { city: city_name.downcase }, place_type: ['hotel', 'hostel'], price_range: nil))

    if places_without_content.empty?
      puts "✅ All places already have AI-generated rating and price range!"
      exit 0
    end

    puts "Found #{places_without_content.size} places without AI content"
    puts ""

    generated_count = 0
    failed_count = 0

    places_without_content.each_with_index do |place, index|
      begin
        print "  [#{index + 1}/#{places_without_content.size}] Generating content for #{place.name}..."

        content = AiContentGenerator.generate_place_content(
          place: place,
          neighborhood: place.neighborhood
        )

        if content && content[:rating].present? && content[:price_range].present?
          place.update_columns(
            rating: content[:rating],
            price_range: content[:price_range]
          )
          generated_count += 1
          puts " ✅"
        else
          failed_count += 1
          puts " ❌ (no response or incomplete content)"
        end
      rescue => e
        failed_count += 1
        puts " ❌ (#{e.message})"
      end

      # Rate limiting: sleep briefly between API calls
      sleep(0.5)
    end

    puts ""
    puts "=" * 80
    puts "✅ Generated AI content for #{generated_count} places"
    puts "❌ Failed: #{failed_count}" if failed_count > 0
    puts "=" * 80
  end
end
