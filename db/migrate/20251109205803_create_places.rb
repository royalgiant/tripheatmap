class CreatePlaces < ActiveRecord::Migration[7.1]
  def change
    create_table :places do |t|
      t.references :neighborhood, null: false, foreign_key: true, index: true
      t.string :name
      t.string :place_type
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lon, precision: 10, scale: 6
      t.string :address
      t.jsonb :tags, default: {}

      t.timestamps
    end

    add_index :places, :place_type
    add_index :places, [:lat, :lon]
  end
end
