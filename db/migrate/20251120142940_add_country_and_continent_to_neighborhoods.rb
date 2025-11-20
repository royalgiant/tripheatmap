class AddCountryAndContinentToNeighborhoods < ActiveRecord::Migration[7.1]
  def change
    add_column :neighborhoods, :country, :string
    add_column :neighborhoods, :continent, :string

    add_index :neighborhoods, :country
    add_index :neighborhoods, :continent
  end
end
