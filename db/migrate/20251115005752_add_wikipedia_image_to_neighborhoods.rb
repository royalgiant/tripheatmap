class AddWikipediaImageToNeighborhoods < ActiveRecord::Migration[7.1]
  def change
    add_column :neighborhoods, :wikipedia_image_url, :string
    add_column :neighborhoods, :wikipedia_image_checked_at, :datetime
  end
end
