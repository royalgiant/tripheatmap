class AddAgodaAffiliateUrlToPlaces < ActiveRecord::Migration[7.1]
  def change
    add_column :places, :agoda_affiliate_url, :string
  end
end
