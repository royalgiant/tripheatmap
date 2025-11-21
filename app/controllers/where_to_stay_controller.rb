class WhereToStayController < ApplicationController
  before_action :set_city_context, only: [:show]

  def index
    @cities = get_cities
    @cities_grouped = get_cities_grouped_by_location
  end

  def show
    @page = WhereToStay::PagePresenter.new(
      city_slug: @city_slug,
      city_config: @city_config,
      url_slug: @url_slug
    )

    raise ActiveRecord::RecordNotFound unless @page.available?
  end

  private

  def set_city_context
    @url_slug = params[:city].to_s.downcase
    @city_slug = @url_slug.tr('-', ' ').tr('_', ' ').squish

    @city_config = supported_city_configs[@city_slug]
    raise ActiveRecord::RecordNotFound unless @city_config
  end

  def supported_city_configs
    @supported_city_configs ||= NeighborhoodBoundaryImporter.city_configs.each_with_object({}) do |(key, config), memo|
      next unless config.is_a?(Hash)
      next if key.to_s == 'states'
      next if config[:enabled] == false

      normalized_key = normalize_slug(key)
      memo[normalized_key] = config if normalized_key.present?

      city_name = normalize_slug(config[:city])
      memo[city_name] = config if city_name.present?
    end
  end

  def normalize_slug(value)
    value.to_s.downcase.tr('-', ' ').tr('_', ' ').squish
  end
end
