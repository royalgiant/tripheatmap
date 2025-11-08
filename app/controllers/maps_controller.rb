class MapsController < ApplicationController
  def index
    @mapbox_token = Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)
  end

  def city
    @city = params[:city]
    @posts = RedditPost.analyzed
      .where(city: @city)
      .where.not(lat: nil, lon: nil)
      .order(created_at: :desc)
    @mapbox_token = Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)
  end

  def places
    @city = params[:city] || 'Dallas'
    @mapbox_token = Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)

    @neighborhoods = Neighborhood.where(city: @city)
    @total_amenities = NeighborhoodPlacesStat.joins(:neighborhood)
      .where(neighborhoods: { city: @city })
      .sum(:total_amenities)
  end
end
