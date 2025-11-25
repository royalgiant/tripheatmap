class Api::V1::NeighborhoodsController < ApplicationController
  skip_before_action :verify_authenticity_token

  # GET /api/v1/neighborhoods
  # Returns GeoJSON FeatureCollection of neighborhoods
  #
  # Query parameters:
  #   city: Filter by city name (e.g., 'Dallas', 'Chicago')
  #   state: Filter by state code (e.g., 'TX', 'IL')
  #   include_geometry: Include full polygon geometry (default: false, only centroids)
  #
  def index
    geojson = NeighborhoodGeoJsonService.call(
      city: params[:city],
      state: params[:state],
      include_geometry: params[:include_geometry] == 'true'
    )

    render json: geojson
  end

  # GET /api/v1/neighborhoods/:id
  # Returns detailed information for a specific neighborhood
  def show
    neighborhood = Neighborhood.find(params[:id])

    render json: {
      neighborhood: {
        id: neighborhood.id,
        geoid: neighborhood.geoid,
        name: neighborhood.name,
        city: neighborhood.city,
        county: neighborhood.county,
        state: neighborhood.state,
        population: neighborhood.population,
        geometry: RGeo::GeoJSON.encode(neighborhood.geom)
      }
    }
  end
end
