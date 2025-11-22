class AddAreaSqKmToNeighborhoods < ActiveRecord::Migration[7.1]
  def up
    add_column :neighborhoods, :area_sq_km, :decimal, precision: 10, scale: 2

    execute <<-SQL
      UPDATE neighborhoods
      SET area_sq_km = ST_Area(geom::geography) / 1000000.0
      WHERE geom IS NOT NULL
    SQL
  end

  def down
    remove_column :neighborhoods, :area_sq_km
  end
end
