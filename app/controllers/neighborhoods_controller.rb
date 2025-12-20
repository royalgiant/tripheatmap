class NeighborhoodsController < ApplicationController
  VALID_PLACE_TYPES = ['restaurant', 'cafe', 'bar', 'hotel', 'hostel', 'airbnb', 'vrbo'].freeze

  def show
    @neighborhood = Neighborhood.find_by(slug: params[:slug])

    if @neighborhood.nil?
      redirect_to where_to_stay_index_path, status: :moved_permanently and return
    end

    @places = @neighborhood.places
                          .where(place_type: VALID_PLACE_TYPES)
                          .select(:id, :name, :place_type, :latitude, :longitude, :address, :booking_url)
                          .to_a
    
    @stats = @neighborhood.neighborhood_places_stat || @neighborhood.build_neighborhood_places_stat
    @restaurants = @places.select { |p| p.place_type == 'restaurant' }
    @cafes = @places.select { |p| p.place_type == 'cafe' }
    @bars = @places.select { |p| p.place_type == 'bar' }
    @hotels = @places.select { |p| p.place_type == 'hotel' }
    @hostels = @places.select { |p| p.place_type == 'hostel' }
    @airbnb_count = @neighborhood.places.where(place_type: 'airbnb').count
    @vrbo_count = @neighborhood.places.where(place_type: 'vrbo').count

    @mapbox_token = Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)
  end

  def places_list
    @neighborhood = Neighborhood.find_by(slug: params[:slug])

    if @neighborhood.nil?
      head :not_found and return
    end

    @places = @neighborhood.places
                          .where(place_type: VALID_PLACE_TYPES)
                          .order(:place_type, :name)
                          .to_a

    if current_user
      @favorites_by_place_id = current_user.favorites.pluck(:place_id, :id).to_h
    else
      @favorites_by_place_id = {}
    end

    @restaurants = @places.select { |p| p.place_type == 'restaurant' }
    @cafes = @places.select { |p| p.place_type == 'cafe' }
    @bars = @places.select { |p| p.place_type == 'bar' }
    @hotels = @places.select { |p| p.place_type == 'hotel' }
    @hostels = @places.select { |p| p.place_type == 'hostel' }
    @airbnbs = @places.select { |p| p.place_type == 'airbnb' }
    @vrbos = @places.select { |p| p.place_type == 'vrbo' }

    render partial: 'places_list_content'
  end
end
