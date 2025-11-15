# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://tripheatmap.com"
# Generate a plain XML file instead of the default gzipped version
SitemapGenerator::Sitemap.compress = false

def normalized_city_slug(city_key)
  city_key.to_s.downcase.gsub('.', '').gsub(' ', '-')
end

CITY_DATA_FOR_SITEMAP = Neighborhood
  .where.not(city: nil)
  .group(:city)
  .count
  .map do |city, count|
    display_name = CityDataImporter::DISPLAY_NAMES[city] || city.titleize

    {
      key: city,
      name: display_name,
      slug: normalized_city_slug(city),
      neighborhood_count: count
    }
  end
  .sort_by { |city_data| city_data[:name] }

SitemapGenerator::Sitemap.create do
  add root_path, changefreq: "daily", priority: 1.0

  CITY_DATA_FOR_SITEMAP.each do |city_data|
    slug = city_data[:slug]
    add where_to_stay_path(slug), changefreq: "weekly", priority: 0.8
    add places_map_path(slug), changefreq: "weekly", priority: 0.7
  end
end
