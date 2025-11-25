class AddGooglePlacesFieldsToPlaces < ActiveRecord::Migration[7.1]
  def change
    add_column :places, :rating, :decimal, precision: 2, scale: 1
    add_column :places, :review_count, :integer
    add_column :places, :price_level, :integer
    add_column :places, :google_place_id, :string
    add_column :places, :photo_reference, :string

    add_index :places, :google_place_id, unique: true
    add_index :places, :place_type unless index_exists?(:places, :place_type)
  end
end
