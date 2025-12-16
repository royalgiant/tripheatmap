class PlacesController < ApplicationController
  def show
    @place = Place.find_by!(slug: params[:slug])
    @seo_title = "#{@place.name} - Reviews, Photos & Rates"
    @seo_description = @place.agoda_metadata&.dig('overview')&.truncate(160) || "Stay at #{@place.name}. View photos, reviews, and amenities."
  end

  def close
  end
end