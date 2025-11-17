class AddBookingUrlToPlaces < ActiveRecord::Migration[7.1]
  def change
    add_column :places, :booking_url, :string
    add_column :places, :user_id, :bigint
    add_index :places, :user_id
  end
end
