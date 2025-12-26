class AddAcceptOffersToSavedSearches < ActiveRecord::Migration[7.1]
  def change
    add_column :saved_searches, :accept_offers, :boolean, default: false, null: false
  end
end
