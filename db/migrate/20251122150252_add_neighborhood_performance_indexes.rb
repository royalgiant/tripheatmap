class AddNeighborhoodPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # Index for neighborhoods.city lookup (critical for for_city scope)
    add_index :neighborhoods, :city, if_not_exists: true

    # Composite index for places filtering by neighborhood_id and place_type
    add_index :places, [:neighborhood_id, :place_type], if_not_exists: true

    # Index for sorting neighborhoods by vibrancy
    add_index :neighborhood_places_stats, :vibrancy_index, if_not_exists: true

    # Composite index for country lookups (used in related_cities query)
    add_index :neighborhoods, [:country, :city], if_not_exists: true
  end
end
