class AddLatitudeLongitudeToNeighborhoods < ActiveRecord::Migration[7.1]
  def up
    add_column :neighborhoods, :latitude, :decimal, precision: 10, scale: 6
    add_column :neighborhoods, :longitude, :decimal, precision: 10, scale: 6

    execute <<-SQL
      UPDATE neighborhoods
      SET latitude = ST_Y(centroid::geometry),
          longitude = ST_X(centroid::geometry)
      WHERE centroid IS NOT NULL
    SQL

    add_index :neighborhoods, [:latitude, :longitude]
  end

  def down
    remove_index :neighborhoods, [:latitude, :longitude]
    remove_column :neighborhoods, :latitude
    remove_column :neighborhoods, :longitude
  end
end
