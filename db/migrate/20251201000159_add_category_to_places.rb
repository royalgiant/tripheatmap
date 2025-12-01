class AddCategoryToPlaces < ActiveRecord::Migration[7.1]
  def change
    add_column :places, :category, :string
  end
end
