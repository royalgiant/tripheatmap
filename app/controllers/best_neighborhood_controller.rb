class BestNeighborhoodController < ApplicationController
  before_action :set_city_context, only: [:show]

  def index
    @cities = get_cities
    @cities_grouped = get_cities_grouped_by_location
  end

  def show
    @city_display_name = city_display_name
    @country = @city_config['country'] || 'United States'
    @neighborhoods = high_vibrancy_neighborhoods
    @has_neighborhoods = @neighborhoods.any?
    @related_cities = fetch_related_cities
  end

  private

  def fetch_related_cities
    return [] unless @city_config

    CityDataImporter.city_configs.select do |key, config|
      next false if key == 'states'
      next false if config['enabled'] == false
      
      # Match country
      config_country = config['country'] || 'United States'
      same_country = config_country.downcase == @country.downcase
      
      # Exclude current city
      normalized_key = normalize_slug(key)
      not_current = normalized_key != @city_slug
      
      same_country && not_current
    end.sort_by { |_, config| config['name'] || config['city'] }.sample(12).map do |key, config|
      city_name = config['name'] || config['city']
      slug = config['city'].to_s.downcase.gsub('.', '').gsub(' ', '-')
      
      {
        city: city_name,
        country: config['country'],
        url: best_neighborhood_path(slug) # Link to Best Neighborhood page instead of Where To Stay
      }
    end
  end

  def set_city_context
    @url_slug = params[:city].to_s.downcase
    @city_slug = @url_slug.tr('-', ' ').tr('_', ' ').squish

    @city_config = supported_city_configs[@city_slug]
    raise ActiveRecord::RecordNotFound unless @city_config
  end

  def city_name
    @city_config['city'] || @city_config['name']
  end

  def city_display_name
    city_name.split.map(&:capitalize).join(' ')
  end

  def high_vibrancy_neighborhoods
    Neighborhood
      .for_city(city_name.downcase)
      .includes(:neighborhood_places_stat)
      .where('neighborhood_places_stats.vibrancy_index > ?', 6.0)
      .order(Arel.sql('neighborhood_places_stats.vibrancy_index DESC'))
  end

  def supported_city_configs
    @supported_city_configs ||= CityDataImporter.city_configs.each_with_object({}) do |(key, config), memo|
      next unless config.is_a?(Hash)
      next if key.to_s == 'states'
      next if config['enabled'] == false

      normalized_key = normalize_slug(key)
      memo[normalized_key] = config if normalized_key.present?

      city_name = normalize_slug(config['city'] || config['name'])
      memo[city_name] = config if city_name.present?
    end
  end

  def normalize_slug(value)
    value.to_s.downcase.tr('.', ' ').tr('-', ' ').tr('_', ' ').squish
  end
end