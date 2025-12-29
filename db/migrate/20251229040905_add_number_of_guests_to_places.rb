class AddNumberOfGuestsToPlaces < ActiveRecord::Migration[7.1]
  def change
    add_column :places, :number_of_guests, :integer
  end
end
