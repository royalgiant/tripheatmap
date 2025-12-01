class NeighborhoodsController < ApplicationController
  def show
    @neighborhood = Neighborhood.find_by(slug: params[:slug])

    if @neighborhood.nil?
      redirect_to where_to_stay_index_path, status: :moved_permanently and return
    end

    @places = @neighborhood.places.order(:place_type, :name)

    # Group places by type for display
    @restaurants = @places.restaurants
    @cafes = @places.cafes
    @bars = @places.bars
    @hotels = @places.where(place_type: 'hotel')
    @hostels = @places.where(place_type: 'hostel')
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
