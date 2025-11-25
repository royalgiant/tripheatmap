class UpdatePlacesPriceInfo < ActiveRecord::Migration[7.1]
  def up
    remove_column :places, :price_level
    add_column :places, :price_range, :string
    add_index :places, :price_range
  end

  def down
    remove_index :places, :price_range
    remove_column :places, :price_range
    add_column :places, :price_level, :integer
  end
end