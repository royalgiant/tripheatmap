class CreateNeighborhoods < ActiveRecord::Migration[7.1]
  def change
    create_table :neighborhoods do |t|
      t.string  :name, null: false
      t.string  :city
      t.string  :county
      t.string  :state
      t.string  :geoid             # census tract/block group/ZIP id if used
      t.integer :population
      t.geometry :geom, geographic: true, has_z: false, has_m: false  # MultiPolygon
      t.st_point :centroid, geographic: true
      t.timestamps
    end
    add_index :neighborhoods, :geoid
    add_index :neighborhoods, :geom, using: :gist
    add_index :neighborhoods, :centroid, using: :gist
  end
end
