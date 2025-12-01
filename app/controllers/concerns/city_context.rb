module CityContext
  extend ActiveSupport::Concern

  included do
    helper_method :city_name, :city_display_name
  end

  private

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

  def fetch_related_cities
    return [] unless @city_config

    CityDataImporter.city_configs.select do |key, config|
      next false if key == 'states'
      next false if config['enabled'] == false
      
      # Match country
      config_country = config['country'] || 'United States'
      same_country = config_country.downcase == (@city_config['country'] || 'United States').downcase
      
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
        url: related_city_path(slug) # Calls the controller-specific method
      }
    end
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
