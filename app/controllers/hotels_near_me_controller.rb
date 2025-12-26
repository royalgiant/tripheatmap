class HotelsNearMeController < ApplicationController
  include NearMeSearch

  private

  def place_scope
    Place.hotels
  end

  def places_variable_name
    "hotels"
  end

  def index_path
    hotels_near_me_index_path
  end
end
