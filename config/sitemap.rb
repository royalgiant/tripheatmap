SitemapGenerator::Sitemap.default_host = "https://tripheatmap.com"
# Generate a plain XML file instead of the default gzipped version
SitemapGenerator::Sitemap.compress = false

SitemapGenerator::Sitemap.create do
  add root_path, changefreq: "daily", priority: 1.0
  add best_neighborhood_index_path, changefreq: "daily", priority: 0.9
  add best_boutique_hotels_index_path, changefreq: "daily", priority: 0.9
  add best_luxury_hotels_index_path, changefreq: "daily", priority: 0.9
  add best_cheap_hotels_index_path, changefreq: "daily", priority: 0.9
  add best_affordable_hotels_index_path, changefreq: "daily", priority: 0.9
  add best_budget_hotels_index_path, changefreq: "daily", priority: 0.9
  add hotels_near_landmark_index_path, changefreq: "daily", priority: 0.9
  add hotels_near_airport_index_path, changefreq: "daily", priority: 0.9

  city_data_for_sitemap = Neighborhood
    .where.not(city: nil)
    .group(:city)
    .count
    .map do |city, count|
      display_name = CityDataImporter::DISPLAY_NAMES[city] || city.titleize

      {
        key: city,
        name: display_name,
        slug: city.to_s.downcase.gsub('.', '').gsub(' ', '-'),
        neighborhood_count: count
      }
    end
    .sort_by { |city_data| city_data[:name] }

  city_data_for_sitemap.each do |city_data|
    slug = city_data[:slug]
    add where_to_stay_path(slug), changefreq: "weekly", priority: 0.8
    add best_neighborhood_path(slug), changefreq: "weekly", priority: 0.8
    add best_boutique_hotels_path(slug), changefreq: "weekly", priority: 0.8
    add best_luxury_hotels_path(slug), changefreq: "weekly", priority: 0.8
    add best_cheap_hotels_path(slug), changefreq: "weekly", priority: 0.8
    add best_affordable_hotels_path(slug), changefreq: "weekly", priority: 0.8
    add best_budget_hotels_path(slug), changefreq: "weekly", priority: 0.8
    add hotels_near_landmark_city_path(slug), changefreq: "weekly", priority: 0.8
    add hotels_near_airport_city_path(slug), changefreq: "weekly", priority: 0.8
    add places_map_path(slug), changefreq: "weekly", priority: 0.7

    # ============================================================================
    # SEO MULTIPLIER: Filter combinations for ALL hotel types
    # ============================================================================

    # --- BOUTIQUE HOTELS ---
    # Price filters
    add best_boutique_hotels_path(slug, price: '$'), changefreq: "weekly", priority: 0.75
    add best_boutique_hotels_path(slug, price: '$$'), changefreq: "weekly", priority: 0.75
    add best_boutique_hotels_path(slug, price: '$$$'), changefreq: "weekly", priority: 0.75
    add best_boutique_hotels_path(slug, price: '$$$$'), changefreq: "weekly", priority: 0.75
    # Rating filters
    add best_boutique_hotels_path(slug, rating: '4.5'), changefreq: "weekly", priority: 0.75
    add best_boutique_hotels_path(slug, rating: '4.0'), changefreq: "weekly", priority: 0.75

    # Get ALL neighborhoods with boutique hotels (minimum 2 hotels to avoid thin content)
    boutique_neighborhoods = Neighborhood
      .where(city: city_data[:key])
      .joins(:places)
      .where(places: { place_type: 'hotel', category: 'boutique' })
      .group('neighborhoods.id')
      .select('neighborhoods.id, neighborhoods.name, neighborhoods.slug, COUNT(places.id) as hotel_count')
      .having('COUNT(places.id) >= 2')
      .order('hotel_count DESC')

    boutique_neighborhoods.each do |neighborhood|
      next unless neighborhood.slug.present?
      add best_boutique_hotels_path(slug, neighborhood: neighborhood.slug), changefreq: "weekly", priority: 0.7
      ['$', '$$', '$$$', '$$$$'].each do |price|
        add best_boutique_hotels_path(slug, neighborhood: neighborhood.slug, price: price), changefreq: "weekly", priority: 0.65
      end
      add best_boutique_hotels_path(slug, neighborhood: neighborhood.slug, rating: '4.5'), changefreq: "weekly", priority: 0.65
    end

    # --- LUXURY HOTELS ---
    add best_luxury_hotels_path(slug, price: '$$$'), changefreq: "weekly", priority: 0.75
    add best_luxury_hotels_path(slug, price: '$$$$'), changefreq: "weekly", priority: 0.75
    add best_luxury_hotels_path(slug, rating: '4.5'), changefreq: "weekly", priority: 0.75
    add best_luxury_hotels_path(slug, rating: '4.0'), changefreq: "weekly", priority: 0.75

    luxury_neighborhoods = Neighborhood
      .where(city: city_data[:key])
      .joins(:places)
      .where(places: { place_type: 'hotel', category: 'luxury' })
      .group('neighborhoods.id')
      .select('neighborhoods.id, neighborhoods.name, neighborhoods.slug, COUNT(places.id) as hotel_count')
      .having('COUNT(places.id) >= 2')
      .order('hotel_count DESC')
      .limit(10)  # Top 10 neighborhoods for luxury

    luxury_neighborhoods.each do |neighborhood|
      next unless neighborhood.slug.present?
      add best_luxury_hotels_path(slug, neighborhood: neighborhood.slug), changefreq: "weekly", priority: 0.7
      add best_luxury_hotels_path(slug, neighborhood: neighborhood.slug, rating: '4.5'), changefreq: "weekly", priority: 0.65
    end

    # --- CHEAP HOTELS ---
    add best_cheap_hotels_path(slug, price: '$'), changefreq: "weekly", priority: 0.75
    add best_cheap_hotels_path(slug, price: '$$'), changefreq: "weekly", priority: 0.75
    add best_cheap_hotels_path(slug, rating: '4.0'), changefreq: "weekly", priority: 0.75
    add best_cheap_hotels_path(slug, rating: '3.5'), changefreq: "weekly", priority: 0.75

    cheap_neighborhoods = Neighborhood
      .where(city: city_data[:key])
      .joins(:places)
      .where(places: { place_type: ['hotel', 'hostel'], price_range: ['$', '$$'] })
      .group('neighborhoods.id')
      .select('neighborhoods.id, neighborhoods.name, neighborhoods.slug, COUNT(places.id) as hotel_count')
      .having('COUNT(places.id) >= 2')
      .order('hotel_count DESC')
      .limit(10)  # Top 10 neighborhoods for budget

    cheap_neighborhoods.each do |neighborhood|
      next unless neighborhood.slug.present?
      add best_cheap_hotels_path(slug, neighborhood: neighborhood.slug), changefreq: "weekly", priority: 0.7
      add best_cheap_hotels_path(slug, neighborhood: neighborhood.slug, price: '$'), changefreq: "weekly", priority: 0.65
    end

    # --- AFFORDABLE HOTELS ---
    add best_affordable_hotels_path(slug, price: '$$'), changefreq: "weekly", priority: 0.75
    add best_affordable_hotels_path(slug, price: '$$$'), changefreq: "weekly", priority: 0.75
    add best_affordable_hotels_path(slug, rating: '4.0'), changefreq: "weekly", priority: 0.75

    # --- BUDGET HOTELS ---
    add best_budget_hotels_path(slug, price: '$'), changefreq: "weekly", priority: 0.75
    add best_budget_hotels_path(slug, rating: '4.0'), changefreq: "weekly", priority: 0.75
  end

  Neighborhood.find_each do |neighborhood|
    add neighborhood_path(neighborhood), changefreq: "weekly", priority: 0.6
    city_slug = city_data_for_sitemap.find { |city_data|
      city_data[:key].downcase == neighborhood.city.downcase
    }&.dig(:slug)

    if city_slug
      add hotels_near_path(city_slug, neighborhood.slug), changefreq: "weekly", priority: 0.7
    end
  end

  # ============================================================================
  # HOTELS NEAR LANDMARKS with filter combinations
  # ============================================================================
  Place.landmarks
       .joins(:neighborhood)
       .where.not(name: ['Unnamed', nil, ''])
       .where.not(slug: nil)
       .find_each do |landmark|
    city_slug = city_data_for_sitemap.find { |city_data|
      city_data[:key].downcase == landmark.neighborhood.city.downcase
    }&.dig(:slug)

    if city_slug && landmark.slug.present?
      # Base URL
      add hotels_near_landmark_path(city_slug, landmark.slug), changefreq: "weekly", priority: 0.8

      # Price filters
      add hotels_near_landmark_path(city_slug, landmark.slug, price: '$'), changefreq: "weekly", priority: 0.75
      add hotels_near_landmark_path(city_slug, landmark.slug, price: '$$'), changefreq: "weekly", priority: 0.75
      add hotels_near_landmark_path(city_slug, landmark.slug, price: '$$$'), changefreq: "weekly", priority: 0.75

      # Rating filters
      add hotels_near_landmark_path(city_slug, landmark.slug, rating: '4.5'), changefreq: "weekly", priority: 0.75
      add hotels_near_landmark_path(city_slug, landmark.slug, rating: '4.0'), changefreq: "weekly", priority: 0.75
    end
  end

  # ============================================================================
  # HOTELS NEAR AIRPORTS with filter combinations
  # ============================================================================
  Place.where(place_type: 'airport')
       .joins(:neighborhood)
       .where.not(name: ['Unnamed', nil, ''])
       .where.not(slug: nil)
       .find_each do |airport|
    city_slug = city_data_for_sitemap.find { |city_data|
      city_data[:key].downcase == airport.neighborhood.city.downcase
    }&.dig(:slug)

    if city_slug && airport.slug.present?
      # Base URL
      add hotels_near_airport_path(city_slug, airport.slug), changefreq: "weekly", priority: 0.8

      # Price filters
      add hotels_near_airport_path(city_slug, airport.slug, price: '$'), changefreq: "weekly", priority: 0.75
      add hotels_near_airport_path(city_slug, airport.slug, price: '$$'), changefreq: "weekly", priority: 0.75
      add hotels_near_airport_path(city_slug, airport.slug, price: '$$$'), changefreq: "weekly", priority: 0.75

      # Rating filters
      add hotels_near_airport_path(city_slug, airport.slug, rating: '4.5'), changefreq: "weekly", priority: 0.75
      add hotels_near_airport_path(city_slug, airport.slug, rating: '4.0'), changefreq: "weekly", priority: 0.75
    end
  end

  # ============================================================================
  # HOTELS NEAR UNIVERSITIES with filter combinations
  # ============================================================================
  Place.where(place_type: 'university')
       .where.not(name: ['Unnamed', nil, ''])
       .where.not(slug: nil)
       .where.not(city: nil)
       .find_each do |university|
    city_slug = city_data_for_sitemap.find { |city_data|
      city_data[:key].downcase == university.city.downcase
    }&.dig(:slug)

    if city_slug && university.slug.present?
      # Base URL
      add hotels_near_university_path(city_slug, university.slug), changefreq: "weekly", priority: 0.8

      # Price filters
      add hotels_near_university_path(city_slug, university.slug, price: '$'), changefreq: "weekly", priority: 0.75
      add hotels_near_university_path(city_slug, university.slug, price: '$$'), changefreq: "weekly", priority: 0.75
      add hotels_near_university_path(city_slug, university.slug, price: '$$$'), changefreq: "weekly", priority: 0.75

      # Rating filters
      add hotels_near_university_path(city_slug, university.slug, rating: '4.0'), changefreq: "weekly", priority: 0.75
    end
  end

  # ============================================================================
  # HOTELS NEAR CONVENTION CENTERS with filter combinations
  # ============================================================================
  Place.where(place_type: 'convention_center')
       .where.not(name: ['Unnamed', nil, ''])
       .where.not(slug: nil)
       .where.not(city: nil)
       .find_each do |convention_center|
    city_slug = city_data_for_sitemap.find { |city_data|
      city_data[:key].downcase == convention_center.city.downcase
    }&.dig(:slug)

    if city_slug && convention_center.slug.present?
      # Base URL
      add hotels_near_convention_center_path(city_slug, convention_center.slug), changefreq: "weekly", priority: 0.8

      # Price filters
      add hotels_near_convention_center_path(city_slug, convention_center.slug, price: '$$'), changefreq: "weekly", priority: 0.75
      add hotels_near_convention_center_path(city_slug, convention_center.slug, price: '$$$'), changefreq: "weekly", priority: 0.75
      add hotels_near_convention_center_path(city_slug, convention_center.slug, price: '$$$$'), changefreq: "weekly", priority: 0.75

      # Rating filters
      add hotels_near_convention_center_path(city_slug, convention_center.slug, rating: '4.5'), changefreq: "weekly", priority: 0.75
      add hotels_near_convention_center_path(city_slug, convention_center.slug, rating: '4.0'), changefreq: "weekly", priority: 0.75
    end
  end
end
