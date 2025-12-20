class RemoveCountColumnsFromNeighborhoodPlacesStats < ActiveRecord::Migration[7.1]
  def change
    remove_column :neighborhood_places_stats, :cafe_count, :integer
    remove_column :neighborhood_places_stats, :bar_count, :integer
    remove_column :neighborhood_places_stats, :restaurant_count, :integer
    remove_column :neighborhood_places_stats, :total_amenities, :integer
    remove_column :neighborhood_places_stats, :total_accommodations, :integer
    remove_column :neighborhood_places_stats, :hotel_count, :integer
    remove_column :neighborhood_places_stats, :hostel_count, :integer
  end
end
