class BnbNearMeController < ApplicationController
  include NearMeSearch

  private

  def place_scope
    Place.bed_and_breakfasts
  end

  def places_variable_name
    "bed_and_breakfasts"
  end

  def index_path
    bnb_near_me_index_path
  end
end
