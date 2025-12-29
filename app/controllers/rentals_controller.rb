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
    @rental = current_user.places.build(rental_params.except(:rental_type))
    @rental.place_type = params[:place][:rental_type] # 'airbnb' or 'vrbo'

    neighborhood = find_neighborhood_by_coordinates(@rental.latitude, @rental.longitude)

    if neighborhood.nil?
      flash[:error] = "Could not find a neighborhood for those coordinates. Please check the address."
      @cities = CityDataImporter::CITY_NAMES.keys.sort
      render :new
      return
    end

    @rental.neighborhood_id = neighborhood.id

    if @rental.save
      fetch_and_update_metadata(@rental)
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

    if @rental.update(rental_params.except(:rental_type))
      if @rental.latitude_previously_changed? || @rental.longitude_previously_changed?
        neighborhood = find_neighborhood_by_coordinates(@rental.latitude, @rental.longitude)
        @rental.update(neighborhood_id: neighborhood&.id) if neighborhood
      end
      fetch_and_update_metadata(@rental)
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

  def fetch_and_update_metadata(rental)
    return unless rental.booking_url.present? && rental.place_type == "airbnb"
    metadata = RentalMetadataFetcher.new(rental.booking_url).call

    if metadata.present?
      update_params = { airbnb_vrbo_metadata: metadata }
      update_params[:rating] = metadata[:rating] if metadata[:rating].present?
      update_params[:review_count] = metadata[:review_count] if metadata[:review_count].present?

      if rental.neighborhood.present?
        update_params[:city] = rental.neighborhood.city
        update_params[:state] = rental.neighborhood.state
        update_params[:country] = rental.neighborhood.country
        update_params[:continent] = rental.neighborhood.continent
      end

      rental.update(update_params)
    end
  end

  def rental_params
    params.require(:place).permit(:name, :address, :latitude, :longitude, :booking_url, :average_price, :rental_type)
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
