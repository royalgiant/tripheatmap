class AddTripAffiliateUrlToPlaces < ActiveRecord::Migration[7.1]
  def change
    add_column :places, :trip_affiliate_url, :string
  end
end
