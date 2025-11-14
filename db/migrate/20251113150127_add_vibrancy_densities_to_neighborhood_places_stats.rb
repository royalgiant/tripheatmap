class AddVibrancyDensitiesToNeighborhoodPlacesStats < ActiveRecord::Migration[7.1]
  def change
    add_column :neighborhood_places_stats, :bars_vibrancy, :decimal
    add_column :neighborhood_places_stats, :restaurants_vibrancy, :decimal
    add_column :neighborhood_places_stats, :cafes_vibrancy, :decimal
  end
end
