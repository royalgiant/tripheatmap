class CreateNeighborhoodPlacesStats < ActiveRecord::Migration[7.1]
  def change
    create_table :neighborhood_places_stats do |t|
      t.references :neighborhood, null: false, foreign_key: true
      t.integer :restaurant_count
      t.integer :cafe_count
      t.integer :bar_count
      t.integer :total_amenities
      t.decimal :vibrancy_index
      t.datetime :last_updated

      t.timestamps
    end
  end
end
