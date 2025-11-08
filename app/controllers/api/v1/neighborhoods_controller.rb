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
    neighborhoods = Neighborhood.with_geom
    neighborhoods = neighborhoods.where(city: params[:city]) if params[:city].present?
    neighborhoods = neighborhoods.where(state: params[:state]) if params[:state].present?

    include_geometry = params[:include_geometry] == 'true'

    features = neighborhoods.map do |neighborhood|
      places_stat = neighborhood.neighborhood_places_stat

      {
        type: "Feature",
        geometry: neighborhood_geometry(neighborhood, include_geometry),
        properties: {
          id: neighborhood.id,
          geoid: neighborhood.geoid,
          name: neighborhood.name,
          city: neighborhood.city,
          county: neighborhood.county,
          state: neighborhood.state,
          population: neighborhood.population,
          # Vibrancy statistics
          restaurant_count: places_stat&.restaurant_count || 0,
          cafe_count: places_stat&.cafe_count || 0,
          bar_count: places_stat&.bar_count || 0,
          total_amenities: places_stat&.total_amenities || 0,
          vibrancy_index: places_stat&.vibrancy_index || 0.0
        }
      }
    end

    render json: {
      type: "FeatureCollection",
      features: features,
      metadata: {
        count: features.size,
        include_geometry: include_geometry
      }
    }
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

  private

  def neighborhood_geometry(neighborhood, include_full_geometry)
    if include_full_geometry
      RGeo::GeoJSON.encode(neighborhood.geom)
    else
      RGeo::GeoJSON.encode(neighborhood.centroid)
    end
  end
end
