class MapsController < ApplicationController
  def index
    @mapbox_token = Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)
  end
end
