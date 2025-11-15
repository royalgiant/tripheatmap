class Api::V1::CitiesController < ApplicationController
  skip_before_action :verify_authenticity_token

  # GET /api/v1/cities
  # Returns list of available cities with neighborhood data
  def index
    render json: get_cities
  end
end

