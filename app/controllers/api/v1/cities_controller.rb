class Api::V1::CitiesController < ApplicationController
  skip_before_action :verify_authenticity_token

  # GET /api/v1/cities
  # Returns list of available cities with neighborhood data
  def index
    cities = Neighborhood.distinct.pluck(:city).compact.sort
    
    cities_data = cities.map do |city|
      display_name = lookup_display_name(city)
      neighborhood_count = Neighborhood.where(city: city).count
      
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

