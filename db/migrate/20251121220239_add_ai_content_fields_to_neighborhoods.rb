class AddAiContentFieldsToNeighborhoods < ActiveRecord::Migration[7.1]
  def change
    add_column :neighborhoods, :description, :text
    add_column :neighborhoods, :about, :text
    add_column :neighborhoods, :time_to_visit, :text
    add_column :neighborhoods, :getting_around, :text
  end
end
