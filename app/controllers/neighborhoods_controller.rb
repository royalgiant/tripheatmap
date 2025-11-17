class NeighborhoodsController < ApplicationController
  def show
    @neighborhood = Neighborhood.find(params[:id])
    @places = @neighborhood.places.order(:place_type, :name)

    # Group places by type for display
    @restaurants = @places.restaurants
    @cafes = @places.cafes
    @bars = @places.bars
    @airbnbs = @places.where(place_type: 'airbnb')
    @vrbos = @places.where(place_type: 'vrbo')

    # Get stats for summary
    @stats = @neighborhood.neighborhood_places_stat

    # Mapbox token for rendering map
    @mapbox_token = mapbox_token
  end

  private

  def mapbox_token
    Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)
  end
end
