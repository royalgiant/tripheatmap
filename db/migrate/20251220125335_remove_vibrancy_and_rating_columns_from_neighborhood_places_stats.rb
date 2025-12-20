class RemoveVibrancyAndRatingColumnsFromNeighborhoodPlacesStats < ActiveRecord::Migration[7.1]
  def change
    remove_column :neighborhood_places_stats, :vibrancy_index, :decimal
    remove_column :neighborhood_places_stats, :bars_vibrancy, :decimal
    remove_column :neighborhood_places_stats, :restaurants_vibrancy, :decimal
    remove_column :neighborhood_places_stats, :cafes_vibrancy, :decimal
    remove_column :neighborhood_places_stats, :avg_hotel_rating, :decimal, precision: 2, scale: 1
    remove_column :neighborhood_places_stats, :avg_hostel_rating, :decimal, precision: 2, scale: 1

    # Also remove the index on vibrancy_index since we're dropping that column
    remove_index :neighborhood_places_stats, name: "index_neighborhood_places_stats_on_vibrancy_index" if index_exists?(:neighborhood_places_stats, :vibrancy_index, name: "index_neighborhood_places_stats_on_vibrancy_index")
  end
end
