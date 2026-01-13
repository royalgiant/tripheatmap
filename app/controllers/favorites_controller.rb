class FavoritesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_place, only: [:create]

  # GET /favorites
  def index
    @favorited_places = current_user.favorited_places.includes(:neighborhood).order('favorites.created_at DESC')
    @favorites_by_place_id = current_user.favorites.pluck(:place_id, :id).to_h
  end

  # POST /favorites
  def create
    @favorite = current_user.favorites.build(place: @place)

    if @favorite.save
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, notice: 'Place added to favorites.' }
        format.json { render json: { favorited: true, message: 'Place added to favorites' }, status: :created }
        format.turbo_stream do
          @favorites_by_place_id = { @place.id => @favorite.id }
          render turbo_stream: turbo_stream.replace("favorite_#{@place.id}", partial: "favorites/button", locals: { place: @place, favorited: true })
        end
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: @favorite.errors.full_messages.join(', ') }
        format.json { render json: { errors: @favorite.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /favorites/:id
  def destroy
    @favorite = current_user.favorites.find(params[:id])
    @place = @favorite.place
    @favorite.destroy

    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, notice: 'Place removed from favorites.' }
      format.json { render json: { favorited: false, message: 'Place removed from favorites' }, status: :ok }
      format.turbo_stream do
        @favorites_by_place_id = {}
        render turbo_stream: turbo_stream.replace("favorite_#{@place.id}", partial: "favorites/button", locals: { place: @place, favorited: false })
      end
    end
  end

  private

  def set_place
    @place = Place.find(params[:place_id])
  end
end
