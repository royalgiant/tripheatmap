class Api::V1::CitiesController < ApplicationController
  skip_before_action :verify_authenticity_token

  # GET /api/v1/cities
  # Returns list of available cities with neighborhood data
  def index
    city_counts = Neighborhood
      .where.not(city: nil)
      .group(:city)
      .count
      .sort_by { |city, _count| city }

    cities_data = city_counts.map do |city, neighborhood_count|
      display_name = lookup_display_name(city)

      {
        key: city,
        name: display_name,
        slug: city.gsub('.', '').gsub(' ', '-'),
        neighborhood_count: neighborhood_count
      }
    end

    render json: cities_data
  end

  private

  def lookup_display_name(city_name)
    CityDataImporter::DISPLAY_NAMES[city_name] || city_name.titleize
  end
end

