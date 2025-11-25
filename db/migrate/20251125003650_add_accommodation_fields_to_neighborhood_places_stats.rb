class AddAccommodationFieldsToNeighborhoodPlacesStats < ActiveRecord::Migration[7.1]
  def change
    add_column :neighborhood_places_stats, :hotel_count, :integer, default: 0
    add_column :neighborhood_places_stats, :hostel_count, :integer, default: 0
    add_column :neighborhood_places_stats, :total_accommodations, :integer, default: 0
    add_column :neighborhood_places_stats, :avg_hotel_rating, :decimal, precision: 2, scale: 1
    add_column :neighborhood_places_stats, :avg_hostel_rating, :decimal, precision: 2, scale: 1
  end
end
