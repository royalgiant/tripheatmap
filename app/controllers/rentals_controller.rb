class RentalsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_subscription_or_admin!, except: [:index]

  def index
    @rentals = current_user.places.where(place_type: ['airbnb', 'vrbo'])
  end

  def new
    @rental = Place.new
    @cities = CityDataImporter::CITY_NAMES.keys.sort
  end

  def create
    @rental = current_user.places.build(rental_params)
    @rental.place_type = params[:place][:rental_type] # 'airbnb' or 'vrbo'

    neighborhood = find_neighborhood_by_coordinates(@rental.lat, @rental.lon)

    if neighborhood.nil?
      flash[:error] = "Could not find a neighborhood for those coordinates. Please check the address."
      @cities = CityDataImporter::CITY_NAMES.keys.sort
      render :new
      return
    end

    @rental.neighborhood_id = neighborhood.id

    if @rental.save
      redirect_to rentals_path, flash: { success: "Your rental has been added successfully!" }
    else
      @cities = CityDataImporter::CITY_NAMES.keys.sort
      render :new
    end
  end

  def edit
    @rental = current_user.places.find(params[:id])
    @cities = CityDataImporter::CITY_NAMES.keys.sort
  end

  def update
    @rental = current_user.places.find(params[:id])

    if params[:place] && params[:place][:rental_type]
      @rental.place_type = params[:place][:rental_type]
    end

    if @rental.update(rental_params)
      if @rental.lat_previously_changed? || @rental.lon_previously_changed?
        neighborhood = find_neighborhood_by_coordinates(@rental.lat, @rental.lon)
        @rental.update(neighborhood_id: neighborhood&.id) if neighborhood
      end

      redirect_to rentals_path, flash: { success: "Your rental has been updated successfully!" }
    else
      @cities = CityDataImporter::CITY_NAMES.keys.sort
      render :edit
    end
  end

  def destroy
    @rental = current_user.places.find(params[:id])
    @rental.destroy
    redirect_to rentals_path, flash: { success: "Your rental has been removed." }
  end

  private

  def rental_params
    params.require(:place).permit(:name, :address, :lat, :lon, :booking_url)
  end

  def require_subscription_or_admin!
    unless current_user.subscribed? || current_user.role == 'admin'
      redirect_to pricing_path, alert: "You need an active subscription to add rentals."
    end
  end

  def find_neighborhood_by_coordinates(lat, lon)
    return nil if lat.nil? || lon.nil?

    # Find neighborhood that contains this point using ST_Intersects
    # ST_Intersects works with geography types
    Neighborhood.where(
      "ST_Intersects(geom::geometry, ST_SetSRID(ST_MakePoint(?, ?), 4326))",
      lon, lat
    ).first
  end
end
