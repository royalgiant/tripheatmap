class RenameLatLonToLatitudeLongitudeInPlaces < ActiveRecord::Migration[7.1]
  def change
    rename_column :places, :lat, :latitude
    rename_column :places, :lon, :longitude
  end
end
