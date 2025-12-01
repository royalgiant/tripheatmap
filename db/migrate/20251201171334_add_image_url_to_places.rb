class AddImageUrlToPlaces < ActiveRecord::Migration[7.1]
  def change
    add_column :places, :image_url, :string
  end
end
