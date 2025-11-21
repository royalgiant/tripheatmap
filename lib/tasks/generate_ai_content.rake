namespace :city do
  desc "Generate AI content for neighborhoods in a city"
  task :generate_ai_content, [:city] => :environment do |t, args|
    city = args[:city]

    unless city
      puts "Error: City parameter required"
      puts "Usage: rake city:generate_ai_content[atlanta]"
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
    puts "Generating AI Content for #{display_name}"
    puts "=" * 80

    # Get city config for state/country
    city_config = CityDataImporter.city_configs[city_key]
    state = city_config&.dig('state')
    country = city_config&.dig('country')

    # Get neighborhoods with stats that don't have content yet
    neighborhoods_without_content = Neighborhood
      .for_city(city_name)
      .includes(:neighborhood_places_stat)
      .where.not(neighborhood_places_stats: { vibrancy_index: nil })
      .where(description: nil)
      .order(Arel.sql("neighborhood_places_stats.vibrancy_index DESC"))

    if neighborhoods_without_content.empty?
      puts "✅ All neighborhoods already have AI-generated content!"
      exit 0
    end

    total_neighborhoods = Neighborhood.for_city(city_name).count
    puts "Found #{neighborhoods_without_content.size} neighborhoods without AI content"
    puts ""

    generated_count = 0
    failed_count = 0

    neighborhoods_without_content.each_with_index do |neighborhood, index|
      stats = neighborhood.neighborhood_places_stat
      next unless stats

      begin
        print "  [#{index + 1}/#{neighborhoods_without_content.size}] Generating content for #{neighborhood.name}..."

        content = AiContentGenerator.generate_neighborhood_content(
          neighborhood: neighborhood,
          stats: {
            restaurant_count: stats.restaurant_count,
            cafe_count: stats.cafe_count,
            bar_count: stats.bar_count,
            vibrancy_index: stats.vibrancy_index
          },
          city_name: display_name,
          state: state,
          country: country,
          total_neighborhoods: total_neighborhoods
        )

        if content
          neighborhood.update_columns(
            description: content[:description],
            about: content[:about],
            time_to_visit: content[:time_to_visit],
            getting_around: content[:getting_around]
          )
          generated_count += 1
          puts " ✅"
        else
          failed_count += 1
          puts " ❌ (no response)"
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
    puts "✅ Generated AI content for #{generated_count} neighborhoods"
    puts "❌ Failed: #{failed_count}" if failed_count > 0
    puts "=" * 80
  end

  desc "Generate AI content for ALL cities"
  task :generate_all_ai_content => :environment do
    puts "=" * 80
    puts "Generating AI Content for All Cities"
    puts "=" * 80
    puts ""

    total_generated = 0
    total_failed = 0

    CityDataImporter::CITY_NAMES.each do |city_key, city_name|
      display_name = CityDataImporter::DISPLAY_NAMES[city_name]

      # Get city config
      city_config = CityDataImporter.city_configs[city_key]
      state = city_config&.dig('state')
      country = city_config&.dig('country')

      # Get neighborhoods without content
      neighborhoods_without_content = Neighborhood
        .for_city(city_name)
        .includes(:neighborhood_places_stat)
        .where.not(neighborhood_places_stats: { vibrancy_index: nil })
        .where(description: nil)
        .order(Arel.sql("neighborhood_places_stats.vibrancy_index DESC"))

      next if neighborhoods_without_content.empty?

      puts "#{display_name}: #{neighborhoods_without_content.size} neighborhoods need content"

      total_neighborhoods = Neighborhood.for_city(city_name).count
      generated_count = 0
      failed_count = 0

      neighborhoods_without_content.each_with_index do |neighborhood, index|
        stats = neighborhood.neighborhood_places_stat
        next unless stats

        begin
          print "  [#{index + 1}/#{neighborhoods_without_content.size}] #{neighborhood.name}..."

          content = AiContentGenerator.generate_neighborhood_content(
            neighborhood: neighborhood,
            stats: {
              restaurant_count: stats.restaurant_count,
              cafe_count: stats.cafe_count,
              bar_count: stats.bar_count,
              vibrancy_index: stats.vibrancy_index
            },
            city_name: display_name,
            state: state,
            country: country,
            total_neighborhoods: total_neighborhoods
          )

          if content
            neighborhood.update_columns(
              description: content[:description],
              about: content[:about],
              time_to_visit: content[:time_to_visit],
              getting_around: content[:getting_around]
            )
            generated_count += 1
            puts " ✅"
          else
            failed_count += 1
            puts " ❌"
          end
        rescue => e
          failed_count += 1
          puts " ❌ (#{e.message})"
        end

        sleep(0.5)
      end

      total_generated += generated_count
      total_failed += failed_count
      puts "  Generated: #{generated_count}, Failed: #{failed_count}"
      puts ""
    end

    puts "=" * 80
    puts "✅ Total Generated: #{total_generated}"
    puts "❌ Total Failed: #{total_failed}" if total_failed > 0
    puts "=" * 80
  end
end
