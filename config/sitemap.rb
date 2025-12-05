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
    add places_map_path(slug), changefreq: "weekly", priority: 0.7
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
end
